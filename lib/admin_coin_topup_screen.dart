import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String _adminUid = "1dd7eMMAm9dp6QqOzQsr5eJXPjB2";

class AdminCoinTopupScreen extends StatefulWidget {
  const AdminCoinTopupScreen({super.key});

  @override
  State<AdminCoinTopupScreen> createState() => _AdminCoinTopupScreenState();
}

class _AdminCoinTopupScreenState extends State<AdminCoinTopupScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool get _isAdmin => FirebaseAuth.instance.currentUser?.uid == _adminUid;
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String? _foundUid;

  Future<void> _searchUser() async {
    final userID = _userIdController.text.trim();
    if (userID.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundUser = null;
      _foundUid = null;
    });

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('userID', isEqualTo: userID)
        .limit(1)
        .get();

    setState(() => _isLoading = false);

    if (query.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No user found with this User ID")),
      );
      return;
    }

    setState(() {
      _foundUid = query.docs.first.id;
      _foundUser = query.docs.first.data();
    });
  }

  /// chats/{uidA_uidB}/messages — a stable chat id between admin and the
  /// recipient, built by sorting the two uids so both sides land in the
  /// same thread regardless of who opens it first.
  // ASSUMPTION: adjust this if your existing chat screen builds chat ids
  // differently (e.g. a separate lookup doc instead of a sorted-uid id).
  String _chatIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  Future<void> _topUp() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (_foundUid == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    final targetUid = _foundUid!;
    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? _adminUid;
    String status = "Failed";
    String? transactionId;

    try {
      // 1) Credit the coins.
      await firestore.collection('users').doc(targetUid).update({
        'coins': FieldValue.increment(amount),
      });

      // Refresh balance so we can show/send the *new* total.
      final updatedSnap = await firestore.collection('users').doc(targetUid).get();
      final updatedData = updatedSnap.data() ?? {};
      final newBalance = (updatedData['coins'] ?? 0).toString();

      // Sender's display name.
      final adminSnap = await firestore.collection('users').doc(adminUid).get();
      final senderName = (adminSnap.data()?['name'] as String?) ?? "Admin";

      status = "Success";
      final now = FieldValue.serverTimestamp();

      // 2) Log the transaction.
      final txnRef = firestore.collection('coin_transactions').doc();
      transactionId = txnRef.id;
      await txnRef.set({
        'transactionId': transactionId,
        'userId': targetUid,
        'senderId': adminUid,
        'senderName': senderName,
        'coinsAdded': amount,
        'balanceAfter': newBalance,
        'status': status,
        'timestamp': now,
      });

      final messageText =
          "🪙 Coins Added!\n\n"
          "Transaction ID: $transactionId\n"
          "Coins Added: +$amount\n"
          "Sender: $senderName\n"
          "Current Balance: $newBalance\n"
          "Status: $status";

      // 3) Drop a message into the recipient's inbox/chat with the admin.
      // ASSUMPTION: matches this project's existing chats/{chatId}/messages
      // shape (participants + lastMessage on the parent doc). Share your
      // chat_screen.dart / inbox file names if the real schema differs.
      final chatId = _chatIdFor(adminUid, targetUid);
      final chatRef = firestore.collection('chats').doc(chatId);
      await chatRef.set({
        'participants': [adminUid, targetUid],
        'lastMessage': messageText,
        'lastMessageTime': now,
        'lastSenderId': adminUid,
      }, SetOptions(merge: true));
      await chatRef.collection('messages').add({
        'senderId': adminUid,
        'receiverId': targetUid,
        'type': 'coin_topup',
        'text': messageText,
        'transactionId': transactionId,
        'coinsAdded': amount,
        'senderName': senderName,
        'balanceAfter': newBalance,
        'status': status,
        'timestamp': now,
        'read': false,
      });

      // 4) Push a notification for the recipient.
      await firestore
          .collection('notifications')
          .doc(targetUid)
          .collection('items')
          .add({
        'type': 'coin_topup',
        'title': 'Coins Added',
        'body': "You received +$amount coins from $senderName",
        'transactionId': transactionId,
        'coinsAdded': amount,
        'senderName': senderName,
        'balanceAfter': newBalance,
        'status': status,
        'chatId': chatId,
        'timestamp': now,
        'read': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$amount coins add ho gaye")),
      );
      _amountController.clear();
      setState(() => _foundUser = updatedData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Top-up failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1E),
        body: Center(child: Text("Access Denied", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1930),
        title: const Text("Coin Top-Up"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "User ID",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchUser,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                  child: const Icon(Icons.search, color: Colors.black),
                ),
              ],
            ),
            if (_foundUser != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_foundUser!['name'] ?? "User", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      "Current Balance: ${_foundUser!['coins'] ?? 0} coins",
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Coins to add",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _topUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Add Coins", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}