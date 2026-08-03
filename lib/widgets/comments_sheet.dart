import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sending) return;

    setState(() => _sending = true);

    final postRef = FirebaseFirestore.instance
        .collection('plaza_posts')
        .doc(widget.postId);

    await postRef.collection('comments').add({
      'userId': user.uid,
      'userName': user.displayName ?? 'User',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await postRef.update({'commentsCount': FieldValue.increment(1)});

    _controller.clear();
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text("Comments",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('plaza_posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("No comments yet",
                          style: TextStyle(color: Colors.white54)),
                    );
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data =
                          docs[i].data() as Map<String, dynamic>? ?? {};
                      return ListTile(
                        title: Text(
                          (data['userName'] ?? 'User').toString(),
                          style:
                              const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        subtitle: Text(
                          (data['text'] ?? '').toString(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.pinkAccent),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}