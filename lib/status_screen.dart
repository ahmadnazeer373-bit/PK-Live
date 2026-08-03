import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Screen/create_post_screen.dart';
import 'widgets/post_card.dart';

// ASSUMPTIONS (adjust if your Firestore schema differs):
// - Collection: 'plaza_posts'
//   fields: userId, userName, userAvatar, userTier (badge text like
//   "VIP9"/"Pro"), verified (bool), caption, imageUrls (List<String>),
//   likesCount (number), likedBy (List<String> of userIds),
//   commentsCount (number), createdAt (Timestamp)
// - Collection: 'users' (already used elsewhere in the app)
//   additionally uses a 'followers' field (List<String> of userIds)
//   for the follow button on each post's avatar

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0518),
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: Colors.amber, size: 20),
            SizedBox(width: 6),
            Text("Plaza", style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plaza_posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Something went wrong",
                  style: TextStyle(color: Colors.white54)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("No posts yet. Be the first to post!",
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) => PostCard(doc: docs[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purpleAccent,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        ),
        child: const Icon(Icons.send, color: Colors.white),
      ),
    );
  }
}