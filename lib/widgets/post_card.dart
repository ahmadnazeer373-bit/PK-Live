import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'comments_sheet.dart';
import '../Screen/create_post_screen.dart';
import '../profile_screen.dart';

class PostCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  const PostCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final String authorId = (data['userId'] ?? '').toString();
    final String userName = (data['userName'] ?? 'User').toString();
    final String userAvatar = (data['userAvatar'] ?? '').toString();
    final String userAvatarEmoji = (data['userAvatarEmoji'] ?? '🧑').toString();
    final String userTier = (data['userTier'] ?? '').toString();
    final bool verified = data['verified'] == true;
    final String caption = (data['caption'] ?? '').toString();
    final List imageUrls = (data['imageUrls'] as List?) ?? [];
    final int likesCount = (data['likesCount'] ?? 0) as int;
    final List likedBy = (data['likedBy'] as List?) ?? [];
    final int commentsCount = (data['commentsCount'] ?? 0) as int;
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isLiked = currentUid != null && likedBy.contains(currentUid);
    final bool isOwner = currentUid != null && currentUid == authorId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0F2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FollowableAvatar(
                authorId: authorId,
                avatarUrl: userAvatar,
                avatarEmoji: userAvatarEmoji,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          targetUserId: authorId,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                color: Colors.lightBlueAccent, size: 15),
                          ],
                        ],
                      ),
                      if (userTier.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Colors.pinkAccent, Colors.purple]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            userTier,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white54),
                onPressed: () => _showOptionsSheet(
                  context,
                  isOwner: isOwner,
                  caption: caption,
                  imageUrls: imageUrls,
                ),
              ),
            ],
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                caption,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          if (imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrls.length == 1
                    ? _buildImage(imageUrls[0])
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: imageUrls.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemBuilder: (context, i) => _buildImage(imageUrls[i]),
                      ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                createdAt != null ? _timeAgo(createdAt.toDate()) : '',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              _LikeButton(
                postId: doc.id,
                isLiked: isLiked,
                likesCount: likesCount,
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1A0F2E),
                    isScrollControlled: true,
                    builder: (_) => CommentsSheet(postId: doc.id),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined,
                        color: Colors.white54, size: 20),
                    const SizedBox(width: 4),
                    Text('$commentsCount',
                        style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 200,
        color: Colors.white10,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.amberAccent,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 200,
        color: Colors.white10,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white38,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                'Image not available',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(
    BuildContext context, {
    required bool isOwner,
    required String caption,
    required List imageUrls,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0F2E),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white70),
                  title: const Text("Edit post",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePostScreen(
                          postId: doc.id,
                          initialCaption: caption,
                          initialImageUrls: List<String>.from(imageUrls),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text("Delete post",
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete(context);
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white70),
                  title: const Text("Report post",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A0F2E),
        title: const Text("Delete post?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This can't be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

class _LikeButton extends StatelessWidget {
  final String postId;
  final bool isLiked;
  final int likesCount;

  const _LikeButton({
    required this.postId,
    required this.isLiked,
    required this.likesCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        final ref =
            FirebaseFirestore.instance.collection('plaza_posts').doc(postId);
        if (isLiked) {
          await ref.update({
            'likedBy': FieldValue.arrayRemove([uid]),
            'likesCount': FieldValue.increment(-1),
          });
        } else {
          await ref.update({
            'likedBy': FieldValue.arrayUnion([uid]),
            'likesCount': FieldValue.increment(1),
          });
        }
      },
      child: Row(
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.redAccent : Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text('$likesCount', style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _FollowableAvatar extends StatefulWidget {
  final String authorId;
  final String avatarUrl;
  final String avatarEmoji;

  const _FollowableAvatar({
    required this.authorId,
    required this.avatarUrl,
    this.avatarEmoji = '🧑',
  });

  @override
  State<_FollowableAvatar> createState() => _FollowableAvatarState();
}

class _FollowableAvatarState extends State<_FollowableAvatar> {
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || widget.authorId.isEmpty || currentUid == widget.authorId) return;

    try {
      // 🔥 SIRF following SUBCOLLECTION CHECK KAREIN
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(widget.authorId)
          .get();

      if (mounted) {
        setState(() {
          _isFollowing = doc.exists;
        });
      }
    } catch (e) {
      debugPrint("Error checking follow status: $e");
    }
  }

  Future<void> _toggleFollow() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || widget.authorId.isEmpty || _isLoading) return;
    if (currentUid == widget.authorId) return;

    setState(() => _isLoading = true);

    try {
      final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
      final targetUserRef = FirebaseFirestore.instance.collection('users').doc(widget.authorId);
      
      // 🔥 SIRF following SUBCOLLECTION USE KAREIN
      final followRef = currentUserRef.collection('following').doc(widget.authorId);

      if (_isFollowing) {
        // 🔥 UNFOLLOW
        await followRef.delete();
        await currentUserRef.update({
          'followingCount': FieldValue.increment(-1),
        });
        await targetUserRef.update({
          'followersCount': FieldValue.increment(-1),
        });

        if (mounted) {
          setState(() => _isFollowing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Unfollowed")),
          );
        }
      } else {
        // 🔥 FOLLOW - Sirf following subcollection mein add
        await followRef.set({
          'followedAt': FieldValue.serverTimestamp(),
          'targetUserId': widget.authorId,
        });

        await currentUserRef.update({
          'followingCount': FieldValue.increment(1),
        });
        await targetUserRef.update({
          'followersCount': FieldValue.increment(1),
        });

        if (mounted) {
          setState(() => _isFollowing = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Followed!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openProfile() {
    if (widget.authorId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          targetUserId: widget.authorId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isSelf = currentUid == widget.authorId;

    return GestureDetector(
      onTap: _openProfile,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            backgroundImage: widget.avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(widget.avatarUrl) as ImageProvider
                : null,
            child: widget.avatarUrl.isEmpty
                ? Text(
                    widget.avatarEmoji,
                    style: const TextStyle(fontSize: 20),
                  )
                : null,
          ),
          if (!isSelf && widget.authorId.isNotEmpty)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: _toggleFollow,
                child: _isLoading
                    ? Container(
                        width: 22,
                        height: 22,
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A0F2E),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.amberAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A0F2E),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isFollowing ? Icons.check_circle : Icons.add_circle,
                          color: _isFollowing
                              ? Colors.greenAccent
                              : Colors.pinkAccent,
                          size: 20,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}