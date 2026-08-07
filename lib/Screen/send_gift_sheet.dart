import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gift_popup_overlay.dart';

/// Opens a bottom sheet with tabbed gift categories (Event/Hot/VIP/Customized).
/// User taps a gift to select it, picks a quantity, then taps Send to gift
/// it to the selected recipient — deducting coins from the sender and
/// crediting totalGifts to the receiver (used for home-screen top-gifted
/// ranking).
///
/// [receiverUid]/[receiverName] is the default/initial recipient. If
/// [recipients] has more than one entry (multiple people seated in the
/// room), a horizontal recipient row is shown along the top of the sheet
/// so the sender can switch who the gift goes to before sending — instead
/// of a separate "who should receive the gift?" step beforehand. Each
/// entry is expected to have 'uid', 'name', and optionally 'avatar' keys.
/// [hostUid], if provided, is used to badge the host in that row.
///
/// If [roomId] is provided, a "X sent Y a 🎁 Gift" line is also posted into
/// that party room's chat (party_rooms/{roomId}/messages) after the gift
/// goes through.
Future<void> showSendGiftSheet(
  BuildContext context,
  String? receiverUid, [
  String? receiverName,
  String? roomId,
  List<Map<String, dynamic>>? recipients,
  String? hostUid,
]) async {
  if (receiverUid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Is room ka host abhi set nahi hai")),
    );
    return;
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => _SendGiftSheet(
      receiverUid: receiverUid,
      receiverName: receiverName,
      roomId: roomId,
      recipients: recipients,
      hostUid: hostUid,
      parentContext: context,
    ),
  );
}

const List<String> _giftCategories = ["Event", "Hot", "VIP", "Customized"];
const List<int> _quantityOptions = [1, 5, 10, 20, 50, 99];

class _SendGiftSheet extends StatefulWidget {
  final String receiverUid;
  final String? receiverName;
  final String? roomId;
  final List<Map<String, dynamic>>? recipients;
  final String? hostUid;
  final BuildContext parentContext;
  const _SendGiftSheet({
    required this.receiverUid,
    this.receiverName,
    this.roomId,
    this.recipients,
    this.hostUid,
    required this.parentContext,
  });

  @override
  State<_SendGiftSheet> createState() => _SendGiftSheetState();
}

class _SendGiftSheetState extends State<_SendGiftSheet> {
  late String _currentReceiverUid = widget.receiverUid;
  late String? _currentReceiverName = widget.receiverName;
  String _selectedCategory = "Hot";
  DocumentSnapshot? _selectedGift;
  int _quantity = 1;
  bool _isSending = false;

  /// Fire-and-forget: posts the "X sent Y a gift" line into the room chat.
  /// A plain try/catch (not .catchError on the Future) so a failed write
  /// here — e.g. a Firestore rules rejection — never crashes the app and
  /// never affects the gift transaction, which has already completed.
  Future<void> _postGiftChatMessage({
    required String roomId,
    required String senderUid,
    required String senderName,
    required String receiverUid,
    required String receiverName,
    required String giftName,
    required String giftEmoji,
    required int quantity,
  }) async {
    try {
      final qtySuffix = quantity > 1 ? " x$quantity" : "";
      await FirebaseFirestore.instance.collection('party_rooms').doc(roomId).collection('messages').add({
        'type': 'gift',
        'senderUid': senderUid,
        'senderName': senderName,
        'receiverUid': receiverUid,
        'receiverName': receiverName,
        'giftName': giftName,
        'giftEmoji': giftEmoji,
        'quantity': quantity,
        'text': "$senderName ne $receiverName ko $giftEmoji $giftName$qtySuffix bheja",
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to post gift chat message: $e");
    }
  }

  void _selectGift(DocumentSnapshot giftDoc) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == _currentReceiverUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aap khud ko gift nahi bhej sakte")),
      );
      return;
    }
    setState(() => _selectedGift = giftDoc);
  }

  /// Tapping Send closes the sheet immediately — the actual send
  /// (coin deduction + Firestore transaction) then runs in the background
  /// using [widget.parentContext] (the underlying room screen) for any
  /// success/failure feedback, since the sheet's own context is gone.
  void _confirmSend() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedGift == null || _isSending) return;

    final giftDoc = _selectedGift!;
    final quantity = _quantity;
    final receiverUid = _currentReceiverUid;
    final receiverName = _currentReceiverName;

    final senderUid = uid;
    
    FirebaseFirestore.instance.collection('users').doc(senderUid).get().then((senderSnap) {
      final senderData = senderSnap.data() ?? {};
      
      FirebaseFirestore.instance.collection('users').doc(receiverUid).get().then((receiverSnap) {
        final receiverData = receiverSnap.data() ?? {};
        
        GiftPopupBus.emit({
          'senderUid': uid,
          'senderName': 'You',
          'senderPhoto': senderData['photoUrl'] ?? senderData['avatarUrl'],
          'senderAvatar': senderData['avatar'] ?? '🧑',
          'receiverUid': receiverUid,
          'receiverName': receiverName ?? 'User',
          'receiverPhoto': receiverData['photoUrl'] ?? receiverData['avatarUrl'],
          'receiverAvatar': receiverData['avatar'] ?? '🧑',
          'giftEmoji': (giftDoc.get('emoji') as String?) ?? '🎁',
          'giftName': (giftDoc.get('name') as String?) ?? 'Gift',
          'videoUrl': (giftDoc.get('videoUrl') as String?) ?? '',
          'quantity': quantity,
        });
      });
    });

    Navigator.pop(context);
    _sendGiftInBackground(uid, giftDoc, quantity, receiverUid, receiverName);
  }

  Future<void> _sendGiftInBackground(
    String uid,
    DocumentSnapshot giftDoc,
    int quantity,
    String receiverUid,
    String? receiverNameArg,
  ) async {
    final parentContext = widget.parentContext;
    final unitPrice = (giftDoc.get('coinPrice') as num).toInt();
    final totalPrice = unitPrice * quantity;
    final giftName = giftDoc.get('name') as String;
    final giftEmoji = (giftDoc.get('emoji') as String?) ?? "🎁";
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final receiverRef = FirebaseFirestore.instance.collection('users').doc(receiverUid);
    String senderName = "User";

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final results = await Future.wait([tx.get(userRef), tx.get(receiverRef)]);
        final senderSnap = results[0];
        final receiverSnap = results[1];

        final senderCoins = ((senderSnap.data()?['coins'] ?? 0) as num).toInt();
        final senderTotalSent = ((senderSnap.data()?['totalSent'] ?? 0) as num).toInt();
        senderName = (senderSnap.data()?['name'] as String?) ?? "User";

        if (senderCoins < totalPrice) {
          throw Exception("INSUFFICIENT_COINS");
        }

        final receiverGifts = ((receiverSnap.data()?['totalGifts'] ?? 0) as num).toInt();

        tx.update(userRef, {'coins': senderCoins - totalPrice, 'totalSent': senderTotalSent + totalPrice});
        tx.update(receiverRef, {'totalGifts': receiverGifts + totalPrice});

        final txnRef = FirebaseFirestore.instance.collection('gift_transactions').doc();
        tx.set(txnRef, {
          'senderUid': uid,
          'receiverUid': receiverUid,
          'giftId': giftDoc.id,
          'giftName': giftName,
          'coinPrice': unitPrice,
          'quantity': quantity,
          'totalPrice': totalPrice,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Best-effort: also drop a line into the room chat so everyone sees
      // the gift. Kept outside/after the transaction and wrapped separately
      // so a hiccup here never makes a successfully-sent gift look failed.
      if (widget.roomId != null) {
        final receiverName = receiverNameArg ?? "User";
        _postGiftChatMessage(
          roomId: widget.roomId!,
          senderUid: uid,
          senderName: senderName,
          receiverUid: receiverUid,
          receiverName: receiverName,
          giftName: giftName,
          giftEmoji: giftEmoji,
          quantity: quantity,
        );
      }
    } catch (e) {
      final message = e.toString().contains("INSUFFICIENT_COINS")
          ? "Aapke paas kaafi coins nahi hain"
          : "Gift nahi bheja ja saka: $e";
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Widget _categoryTab(String label) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = label;
        _selectedGift = null;
      }),
      child: Padding(
        padding: const EdgeInsets.only(right: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              width: 18,
              color: isSelected ? Colors.amberAccent : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _giftTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isSelected = _selectedGift?.id == doc.id;
    final isGlobal = data['isGlobal'] == true;
    final hasSound = data['hasSound'] == true;

    return GestureDetector(
      onTap: () => _selectGift(doc),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.purpleAccent.withOpacity(0.16) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.purpleAccent : Colors.white.withOpacity(0.06),
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔥 Video/Image/Emoji
                data['videoUrl'] != null && 
                    data['videoUrl'].toString().isNotEmpty && 
                    data['category'] == 'Customized'
                    ? SizedBox(
                        width: 34,
                        height: 34,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.play_circle_filled, color: Colors.blueAccent, size: 24),
                            ),
                          ],
                        ),
                      )
                    : data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                        ? Image.network(
                            data['imageUrl'],
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Text(data['emoji'] ?? "🎁", style: const TextStyle(fontSize: 30)),
                          )
                        : Text(data['emoji'] ?? "🎁", style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 4),
                Text(
                  data['name'] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 11),
                    const SizedBox(width: 2),
                    Text(
                      "${data['coinPrice'] ?? 0}",
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isGlobal || hasSound)
            Positioned(
              top: -4,
              left: 6,
              child: Row(
                children: [
                  if (isGlobal)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.public, color: Colors.white, size: 10),
                    ),
                  if (isGlobal && hasSound) const SizedBox(width: 3),
                  if (hasSound)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.music_note, color: Colors.white, size: 10),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.68),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241E42), Color(0xFF17142B)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Recipient row (only when more than one person is
            // seated — otherwise the recipient was already fixed when this
            // sheet was opened, so no picker is needed) ----------
            if ((widget.recipients?.length ?? 0) > 1) ...[
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "Sending to ${_currentReceiverName ?? 'User'}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.recipients!.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final person = widget.recipients![index];
                    final personUid = person['uid'] as String?;
                    final isSelected = personUid == _currentReceiverUid;
                    final isThisHost = personUid != null && personUid == widget.hostUid;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _currentReceiverUid = personUid ?? _currentReceiverUid;
                        _currentReceiverName = person['name'] as String?;
                        _selectedGift = null;
                      }),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.amberAccent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white10,
                                  child: Text(person['avatar'] ?? "🧑", style: const TextStyle(fontSize: 16)),
                                ),
                                if (isThisHost)
                                  const Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 13),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 48,
                            child: Text(
                              person['name'] ?? "User",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.white.withOpacity(0.06), height: 1),
              const SizedBox(height: 10),
            ],

            // ---------- Category tabs ----------
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _giftCategories.map(_categoryTab).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            const SizedBox(height: 12),

            // ---------- Gift grid ----------
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('gift_catalog')
                    .where('category', isEqualTo: _selectedCategory)
                    .orderBy('coinPrice')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text("Abhi is category mein koi gift nahi", style: TextStyle(color: Colors.white38)),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) => _giftTile(docs[index]),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            const SizedBox(height: 10),

            // ---------- Bottom bar: coin balance, quantity, Send ----------
            Row(
              children: [
                // Coin balance
                if (uid != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                    builder: (context, snapshot) {
                      final coins = snapshot.hasData ? ((snapshot.data!.data() as Map<String, dynamic>?)?['coins'] ?? 0) : 0;
                      return Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 4),
                          Text("$coins", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      );
                    },
                  ),
                const Spacer(),

                // Quantity dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _quantity,
                      dropdownColor: const Color(0xFF241E42),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                      items: _quantityOptions
                          .map((q) => DropdownMenuItem(value: q, child: Text("$q")))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _quantity = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send button
                GestureDetector(
                  onTap: _selectedGift == null ? null : _confirmSend,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _selectedGift == null
                            ? [Colors.white24, Colors.white24]
                            : [const Color(0xFFB24BF3), const Color(0xFF7B2FF7)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      "Send",
                      style: TextStyle(
                        color: _selectedGift == null ? Colors.white38 : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}