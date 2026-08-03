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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final coins = (snapshot.data?.get('coins') ?? 0);
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
                child: Row(
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
              );
            },
          ),
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
}