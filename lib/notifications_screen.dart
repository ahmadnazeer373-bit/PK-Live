import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _markRead(String uid, String notifId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(notifId)
        .update({'read': true});
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return "";
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'coin_topup':
        return Icons.monetization_on;
      case 'follow':
        return Icons.person_add;
      case 'message':
        return Icons.chat_bubble;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'coin_topup':
        return Colors.amberAccent;
      case 'follow':
        return Colors.greenAccent;
      case 'message':
        return Colors.blueAccent;
      default:
        return Colors.amberAccent;
    }
  }

  void _openDetail(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1930),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getIconColor(type).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getIcon(type), color: _getIconColor(type)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['title'] ?? "Notification",
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (type == 'coin_topup') ...[
              _detailRow("Transaction ID", data['transactionId']?.toString() ?? "-"),
              _detailRow("Coins Added", "+${data['coinsAdded'] ?? 0}"),
              _detailRow("Sender Name", data['senderName']?.toString() ?? "-"),
              _detailRow("Date & Time", _timeAgo(data['timestamp'] as Timestamp?)),
              _detailRow("Current Balance", data['balanceAfter']?.toString() ?? "-"),
              _detailRow("Status", data['status']?.toString() ?? "-",
                  valueColor: (data['status'] == "Success") ? Colors.greenAccent : Colors.redAccent),
            ] else if (type == 'follow') ...[
              _detailRow("User", data['senderName']?.toString() ?? "-"),
              _detailRow("Action", "Started following you"),
              _detailRow("Date & Time", _timeAgo(data['timestamp'] as Timestamp?)),
            ] else if (type == 'message') ...[
              _detailRow("From", data['senderName']?.toString() ?? "-"),
              _detailRow("Message", data['messagePreview']?.toString() ?? data['body'] ?? ""),
              _detailRow("Date & Time", _timeAgo(data['timestamp'] as Timestamp?)),
            ] else
              Text(data['body'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(
            value,
            style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1E),
        body: Center(child: Text("Login required", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1930),
        title: const Text("Notifications"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .doc(uid)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("No notifications yet", style: TextStyle(color: Colors.white38)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['read'] == true;
              final ts = data['timestamp'] as Timestamp?;
              final type = data['type'] ?? '';

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (!isRead) _markRead(uid, doc.id);
                  _openDetail(context, data);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white.withOpacity(0.04) : _getIconColor(type).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead ? Colors.white.withOpacity(0.08) : _getIconColor(type).withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: _getIconColor(type).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getIcon(type), color: _getIconColor(type), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? "Notification",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              data['body'] ?? "",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                            ),
                            const SizedBox(height: 4),
                            Text(_timeAgo(ts), style: const TextStyle(color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: _getIconColor(type), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}