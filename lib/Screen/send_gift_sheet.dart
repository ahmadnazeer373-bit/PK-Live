import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Opens a bottom sheet listing gifts from the catalog. Tapping one sends
/// it to [receiverUid], deducting coins from the sender and crediting
/// totalGifts to the receiver (used for home-screen top-gifted ranking).
///
/// If [roomId] is provided, a "X sent Y a 🎁 Gift" line is also posted into
/// that party room's chat (party_rooms/{roomId}/messages) after the gift
/// goes through.
Future<void> showSendGiftSheet(BuildContext context, String? receiverUid, [String? receiverName, String? roomId]) async {
  if (receiverUid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Is room ka host abhi set nahi hai")),
    );
    return;
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => _SendGiftSheet(
      receiverUid: receiverUid,
      receiverName: receiverName,
      roomId: roomId,
      parentContext: context,
    ),
  );
}

class _SendGiftSheet extends StatefulWidget {
  final String receiverUid;
  final String? receiverName;
  final String? roomId;
  final BuildContext parentContext;
  const _SendGiftSheet({
    required this.receiverUid,
    this.receiverName,
    this.roomId,
    required this.parentContext,
  });

  @override
  State<_SendGiftSheet> createState() => _SendGiftSheetState();
}

class _SendGiftSheetState extends State<_SendGiftSheet> {
  /// Fire-and-forget: posts the "X sent Y a gift" line into the room chat.
  /// A plain try/catch (not .catchError on the Future) so a failed write
  /// here — e.g. a Firestore rules rejection — never crashes the app and
  /// never affects the gift transaction, which has already completed.
  Future<void> _postGiftChatMessage({
    required String roomId,
    required String senderUid,
    required String senderName,
    required String receiverName,
    required String giftName,
    required String giftEmoji,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('party_rooms').doc(roomId).collection('messages').add({
        'type': 'gift',
        'senderUid': senderUid,
        'senderName': senderName,
        'receiverName': receiverName,
        'giftName': giftName,
        'giftEmoji': giftEmoji,
        'text': "$senderName ne $receiverName ko $giftEmoji $giftName bheja",
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to post gift chat message: $e");
    }
  }

  /// Tapping a gift closes the sheet immediately — the actual send
  /// (coin deduction + Firestore transaction) then runs in the background
  /// using [widget.parentContext] (the underlying room screen) for any
  /// success/failure feedback, since the sheet's own context is gone.
  void _sendGift(DocumentSnapshot giftDoc) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (uid == widget.receiverUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aap khud ko gift nahi bhej sakte")),
      );
      return;
    }

    Navigator.pop(context);
    _sendGiftInBackground(uid, giftDoc);
  }

  Future<void> _sendGiftInBackground(String uid, DocumentSnapshot giftDoc) async {
    final parentContext = widget.parentContext;
    final giftPrice = (giftDoc.get('coinPrice') as num).toInt();
    final giftName = giftDoc.get('name') as String;
    final giftEmoji = (giftDoc.get('emoji') as String?) ?? "🎁";
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final receiverRef = FirebaseFirestore.instance.collection('users').doc(widget.receiverUid);
    String senderName = "User";

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final senderSnap = await tx.get(userRef);
        final senderCoins = ((senderSnap.data()?['coins'] ?? 0) as num).toInt();
        final senderTotalSent = ((senderSnap.data()?['totalSent'] ?? 0) as num).toInt();
        senderName = (senderSnap.data()?['name'] as String?) ?? "User";

        if (senderCoins < giftPrice) {
          throw Exception("INSUFFICIENT_COINS");
        }

        final receiverSnap = await tx.get(receiverRef);
        final receiverGifts = ((receiverSnap.data()?['totalGifts'] ?? 0) as num).toInt();

        tx.update(userRef, {'coins': senderCoins - giftPrice, 'totalSent': senderTotalSent + giftPrice});
        tx.update(receiverRef, {'totalGifts': receiverGifts + giftPrice});

        final txnRef = FirebaseFirestore.instance.collection('gift_transactions').doc();
        tx.set(txnRef, {
          'senderUid': uid,
          'receiverUid': widget.receiverUid,
          'giftId': giftDoc.id,
          'giftName': giftName,
          'coinPrice': giftPrice,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Best-effort: also drop a line into the room chat so everyone sees
      // the gift. Kept outside/after the transaction and wrapped separately
      // so a hiccup here never makes a successfully-sent gift look failed.
      if (widget.roomId != null) {
        final receiverName = widget.receiverName ?? "User";
        _postGiftChatMessage(
          roomId: widget.roomId!,
          senderUid: uid,
          senderName: senderName,
          receiverName: receiverName,
          giftName: giftName,
          giftEmoji: giftEmoji,
        );
      }

      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text("$giftName bhej diya! 🎉")),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241E42), Color(0xFF17142B)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.receiverName != null ? "Send a Gift to ${widget.receiverName}" : "Send a Gift",
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('gift_catalog').orderBy('coinPrice').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("Abhi koi gift available nahi", style: TextStyle(color: Colors.white38)),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return GestureDetector(
                        onTap: () => _sendGift(doc),
                        child: Column(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amberAccent.withOpacity(0.14), Colors.white.withOpacity(0.03)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              alignment: Alignment.center,
                              child: Text(doc.get('emoji') ?? "🎁", style: const TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doc.get('name') ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                            Text(
                              "${doc.get('coinPrice')}",
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}