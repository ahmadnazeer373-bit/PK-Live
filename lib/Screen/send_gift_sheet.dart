import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Opens a bottom sheet listing gifts from the catalog. Tapping one sends
/// it to [receiverUid], deducting coins from the sender and crediting
/// totalGifts to the receiver (used for home-screen top-gifted ranking).
Future<void> showSendGiftSheet(BuildContext context, String? receiverUid, [String? receiverName]) async {
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
    builder: (context) => _SendGiftSheet(receiverUid: receiverUid, receiverName: receiverName),
  );
}

class _SendGiftSheet extends StatefulWidget {
  final String receiverUid;
  final String? receiverName;
  const _SendGiftSheet({required this.receiverUid, this.receiverName});

  @override
  State<_SendGiftSheet> createState() => _SendGiftSheetState();
}

class _SendGiftSheetState extends State<_SendGiftSheet> {
  bool _sending = false;

  Future<void> _sendGift(DocumentSnapshot giftDoc) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _sending) return;

    if (uid == widget.receiverUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aap khud ko gift nahi bhej sakte")),
      );
      return;
    }

    setState(() => _sending = true);

    final giftPrice = (giftDoc.get('coinPrice') as num).toInt();
    final giftName = giftDoc.get('name') as String;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final receiverRef = FirebaseFirestore.instance.collection('users').doc(widget.receiverUid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final senderSnap = await tx.get(userRef);
        final senderCoins = ((senderSnap.data()?['coins'] ?? 0) as num).toInt();
        final senderTotalSent = ((senderSnap.data()?['totalSent'] ?? 0) as num).toInt();

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

      if (!mounted) return;
      Navigator.pop(context);
      // Prevent the room's comment/chat box from popping open on its own
      // once this sheet closes and focus would otherwise return to it.
      FocusManager.instance.primaryFocus?.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$giftName bhej diya! 🎉")),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains("INSUFFICIENT_COINS")
          ? "Aapke paas kaafi coins nahi hain"
          : "Gift nahi bheja ja saka: $e";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
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
                        onTap: _sending ? null : () => _sendGift(doc),
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
            if (_sending) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(color: Colors.amberAccent, minHeight: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}