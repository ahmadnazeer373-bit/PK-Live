import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../profile_screen.dart';
import '../vip_utils.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  
  // 🔥 Post data cache
  Map<String, dynamic>? _postData;
  bool _loadingPost = true;

  @override
  void initState() {
    super.initState();
    _fetchPostData();
  }

  Future<void> _fetchPostData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('plaza_posts')
          .doc(widget.postId)
          .get();
      if (doc.exists) {
        setState(() {
          _postData = doc.data() as Map<String, dynamic>?;
          _loadingPost = false;
        });
      } else {
        setState(() => _loadingPost = false);
      }
    } catch (e) {
      setState(() => _loadingPost = false);
    }
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  int _calculateVipLevel(int totalRecharge) {
    return vipLevelForCoinsSync(totalRecharge);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sending) return;

    setState(() => _sending = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      
      final String userName = (userData['name'] ?? 
                               userData['displayName'] ?? 
                               user.displayName ?? 
                               'User').toString();
      
      final String userAvatar = (userData['avatar'] ?? '🧑').toString();
      final String userAvatarUrl = (userData['avatarUrl'] ?? '').toString();
      final int totalRecharge = (userData['totalRecharge'] ?? 0) as int;
      final int vipLevel = _calculateVipLevel(totalRecharge);

      final postRef = FirebaseFirestore.instance
          .collection('plaza_posts')
          .doc(widget.postId);

      await postRef.collection('comments').add({
        'userId': user.uid,
        'userName': userName,
        'userAvatar': userAvatar,
        'userAvatarUrl': userAvatarUrl,
        'vipLevel': vipLevel,
        'totalRecharge': totalRecharge,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({'commentsCount': FieldValue.increment(1)});

      _controller.clear();
      if (mounted) setState(() => _sending = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0B1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 🔥 Handle
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 🔥 Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  "Moment Detail",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.more_horiz,
                  color: Colors.white54,
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          Expanded(
            child: _loadingPost
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.amberAccent,
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔥 ========== POST USER SECTION ==========
                        _buildPostUserSection(),

                        const Divider(color: Colors.white10, height: 1),

                        // 🔥 ========== COMMENTS SECTION ==========
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "All Comments",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        // 🔥 Comments List
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('plaza_posts')
                              .doc(widget.postId)
                              .collection('comments')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              );
                            }
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.comment_outlined,
                                        color: Colors.white24,
                                        size: 48,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        "No comments yet",
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                      Text(
                                        "Be the first to comment!",
                                        style: TextStyle(color: Colors.white24),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final data = docs[i].data() as Map<String, dynamic>? ?? {};
                                
                                final String userId = (data['userId'] ?? '').toString();
                                final String userName = (data['userName'] ?? 'User').toString();
                                final String userAvatar = (data['userAvatar'] ?? '🧑').toString();
                                final String userAvatarUrl = (data['userAvatarUrl'] ?? '').toString();
                                final int vipLevel = (data['vipLevel'] ?? 0) as int;
                                final String text = (data['text'] ?? '').toString();
                                final Timestamp? createdAt = data['createdAt'];
                                final String timeStr = _timeAgo(createdAt);

                                return _buildCommentTile(
                                  userId: userId,
                                  userName: userName,
                                  userAvatar: userAvatar,
                                  userAvatarUrl: userAvatarUrl,
                                  vipLevel: vipLevel,
                                  text: text,
                                  time: timeStr,
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 80), // Space for comment input
                      ],
                    ),
                  ),
          ),

          // 🔥 ========== COMMENT INPUT ==========
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF3366)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 ========== POST USER SECTION ==========
  Widget _buildPostUserSection() {
    if (_postData == null) return const SizedBox.shrink();

    final String userId = (_postData?['userId'] ?? '').toString();
    final String userName = (_postData?['userName'] ?? 'User').toString();
    final String userAvatar = (_postData?['userAvatar'] ?? '🧑').toString();
    final String userAvatarUrl = (_postData?['userAvatarUrl'] ?? '').toString();
    final String caption = (_postData?['caption'] ?? '').toString();
    final Timestamp? createdAt = _postData?['createdAt'];

    // Get VIP level from post data or fetch from user
    final int vipLevel = _postData?['vipLevel'] ?? 0;
    final String timeStr = _timeAgo(createdAt);

    return GestureDetector(
      onTap: () {
        if (userId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                targetUserId: userId,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 Profile Picture
            GestureDetector(
              onTap: () {
                if (userId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        targetUserId: userId,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF0D0B1E),
                    backgroundImage: userAvatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(userAvatarUrl) as ImageProvider
                        : null,
                    child: userAvatarUrl.isEmpty
                        ? Text(
                            userAvatar,
                            style: const TextStyle(fontSize: 20),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 🔥 Name, VIP, Time, Caption
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (vipLevel > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'VIP $vipLevel',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    caption,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 ========== COMMENT TILE ==========
  Widget _buildCommentTile({
    required String userId,
    required String userName,
    required String userAvatar,
    required String userAvatarUrl,
    required int vipLevel,
    required String text,
    required String time,
  }) {
    return GestureDetector(
      onTap: () {
        if (userId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                targetUserId: userId,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 Profile Picture
            GestureDetector(
              onTap: () {
                if (userId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        targetUserId: userId,
                      ),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: userAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(userAvatarUrl) as ImageProvider
                    : null,
                child: userAvatarUrl.isEmpty
                    ? Text(
                        userAvatar,
                        style: const TextStyle(fontSize: 14),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),

            // 🔥 Name, VIP, Comment, Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (vipLevel > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'VIP $vipLevel',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
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