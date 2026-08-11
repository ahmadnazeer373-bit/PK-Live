import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("Login required", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B1E),
        elevation: 0,
        title: const Text("Wallet", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ---------- Wallet Card ----------
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final coins = (data?['coins'] ?? 0);
              final earnedCoins = (data?['earnedCoins'] ?? 0);

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // 🔥 Coin Balance - 1st Row
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.white, size: 34),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Coin Balance", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              "$coins",
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withOpacity(0.2), height: 1),
                    const SizedBox(height: 16),
                    // 🔥 Earned Coins - 2nd Row
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined, color: Colors.white, size: 30),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Earned Coins", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              "$earnedCoins",
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // ---------- Action Buttons ----------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.add_circle_outline,
                    label: "Buy Coins",
                    color: Colors.greenAccent,
                    onTap: () {
                      _showRechargeDialog(context, uid);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.send_outlined,
                    label: "Send Coins",
                    color: Colors.blueAccent,
                    onTap: () {
                      _showSendCoinsDialog(context, uid);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---------- Gift History ----------
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Gift History", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('gift_transactions')
                  .where('senderUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text("You haven't sent any gifts yet", style: TextStyle(color: Colors.white38)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.card_giftcard, color: Colors.pinkAccent),
                      title: Text(data['giftName'] ?? "", style: const TextStyle(color: Colors.white)),
                      trailing: Text(
                        "-${data['coinPrice']}",
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Show Recharge Dialog
  void _showRechargeDialog(BuildContext context, String uid) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Buy Coins",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter number of coins to purchase:",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "e.g. 100",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.amberAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid amount")),
                );
                return;
              }
              Navigator.pop(context);
              _rechargeCoins(context, uid, amount);
            },
            child: const Text("Buy", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  // 🔥 Recharge Coins Function - ONLY updates coins, NOT earnedCoins
  Future<void> _rechargeCoins(BuildContext context, String uid, int amount) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'coins': FieldValue.increment(amount),
        'totalRecharge': FieldValue.increment(amount),
        // ❌ earnedCoins NOT updated - only gifts should affect earnedCoins
      });

      // Record transaction
      await FirebaseFirestore.instance.collection('coin_transactions').add({
        'senderUid': uid,
        'recipientUid': uid,
        'amount': amount,
        'type': 'self_recharge',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Successfully purchased $amount coins!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to purchase coins: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 Show Send Coins Dialog
  void _showSendCoinsDialog(BuildContext context, String senderUid) {
    final TextEditingController userIDController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Send Coins",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter recipient's User ID and amount:",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: userIDController,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "User ID (e.g. 1123456)",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Amount (e.g. 50)",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final userID = userIDController.text.trim();
              final amount = int.tryParse(amountController.text.trim());
              if (userID.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a User ID")),
                );
                return;
              }
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid amount")),
                );
                return;
              }
              Navigator.pop(context);
              _sendCoinsToUser(context, senderUid, userID, amount);
            },
            child: const Text("Send", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  // 🔥 Send Coins to User Function - ONLY updates coins, NOT earnedCoins
  Future<void> _sendCoinsToUser(
    BuildContext context,
    String senderUid,
    String recipientUserID,
    int amount,
  ) async {
    try {
      // Find recipient by userID
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('userID', isEqualTo: recipientUserID)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ User not found. Please check the User ID."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final recipientDoc = query.docs.first;
      final recipientUid = recipientDoc.id;

      if (recipientUid == senderUid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ You cannot send coins to yourself!"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check sender's balance
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderUid)
          .get();
      final senderCoins = (senderDoc.data()?['coins'] ?? 0) as int;

      if (senderCoins < amount) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ Insufficient coins!"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Perform transaction
      await FirebaseFirestore.instance.runTransaction((tx) async {
        // Deduct from sender - ONLY coins
        tx.update(
          FirebaseFirestore.instance.collection('users').doc(senderUid),
          {'coins': FieldValue.increment(-amount)},
          // ❌ earnedCoins NOT updated
        );

        // Add to recipient - ONLY coins
        tx.update(
          FirebaseFirestore.instance.collection('users').doc(recipientUid),
          {'coins': FieldValue.increment(amount)},
          // ❌ earnedCoins NOT updated
        );

        // Record transaction
        final txnRef = FirebaseFirestore.instance
            .collection('coin_transactions')
            .doc();
        tx.set(txnRef, {
          'senderUid': senderUid,
          'recipientUid': recipientUid,
          'recipientUserID': recipientUserID,
          'amount': amount,
          'type': 'manual_send',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Successfully sent $amount coins to User #$recipientUserID!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to send coins: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// 🔥 Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}