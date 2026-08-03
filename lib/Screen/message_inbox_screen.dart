import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';

class MessageInboxScreen extends StatefulWidget {
  const MessageInboxScreen({super.key});

  @override
  State<MessageInboxScreen> createState() => _MessageInboxScreenState();
}

class _MessageInboxScreenState extends State<MessageInboxScreen> {
  final Set<String> _deletingChatIds = {};

  Future<void> _confirmAndDeleteChat(String chatId, String otherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1730),
        title: const Text("Delete chat?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Your entire chat with $otherName (all messages) will be permanently deleted. This can't be undone.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingChatIds.add(chatId));

    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final messagesRef = chatRef.collection('messages');

      // Delete all messages in the subcollection first (in batches, since
      // a chat could have more messages than a single batch allows).
      while (true) {
        final snap = await messagesRef.limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < 400) break;
      }

      // Then delete the chat document itself.
      await chatRef.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete chat, please try again")),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingChatIds.remove(chatId));
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? "PM" : "AM";
      return "$hour:$minute $period";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return "Yesterday";
    }
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- Premium header ----------------
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2B1055), Color(0xFF7597DE)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    "Messages",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // ---------------- Chat list ----------------
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: myUid)
                    .orderBy('lastMessageTime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amberAccent),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 48),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No chats yet",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }

                  final chats = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    itemCount: chats.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final data = chats[index].data() as Map<String, dynamic>;
                      final participants = List<String>.from(data['participants']);
                      final otherUid = participants.firstWhere((id) => id != myUid);

                      final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
                      final avatars = Map<String, dynamic>.from(data['participantAvatars'] ?? {});

                      // Profile name only — never falls back to an email
                      // address, even if the name field wasn't set for
                      // some reason.
                      final rawName = names[otherUid];
                      final otherName = (rawName is String && rawName.trim().isNotEmpty) ? rawName : "User";
                      final otherAvatar = (avatars[otherUid] is String && (avatars[otherUid] as String).isNotEmpty)
                          ? avatars[otherUid] as String
                          : "🧑";

                      final lastMessage = (data['lastMessage'] as String?) ?? "";
                      final ts = data['lastMessageTime'] as Timestamp?;
                      final timeStr = ts != null ? _formatTime(ts.toDate()) : "";

                      final chatId = chats[index].id;
                      final isDeleting = _deletingChatIds.contains(chatId);

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: isDeleting
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(otherUserId: otherUid, otherUserName: otherName),
                                  ),
                                );
                              },
                        onLongPress: isDeleting ? null : () => _confirmAndDeleteChat(chatId, otherName),
                        child: Opacity(
                          opacity: isDeleting ? 0.4 : 1,
                          child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              // Profile picture (gradient-ringed avatar,
                              // consistent with the rest of the app)
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: const Color(0xFF1A1A2E),
                                  child: Text(otherAvatar, style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      otherName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      lastMessage.isEmpty ? "Start the conversation" : lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              isDeleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          timeStr,
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
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