import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comments_sheet.dart';

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
                                fontWeight: FontWeight.w600),
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
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white54),
                onPressed: () => _showOptionsSheet(
                  context,
                  isOwner: isOwner,
                  caption: caption,
                ),
              ),
            ],
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(caption,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          if (imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrls.length == 1
                    ? Image.network(imageUrls[0], fit: BoxFit.cover)
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
                        itemBuilder: (context, i) =>
                            Image.network(imageUrls[i], fit: BoxFit.cover),
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

  void _showOptionsSheet(
    BuildContext context, {
    required bool isOwner,
    required String caption,
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
                  title: const Text("Edit caption",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editCaption(context, caption);
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
                    // TODO: hook up real reporting flow if needed
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _editCaption(BuildContext context, String currentCaption) {
    final controller = TextEditingController(text: currentCaption);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A0F2E),
        title: const Text("Edit caption", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.update({'caption': controller.text.trim()});
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text("Save", style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
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

class _FollowableAvatar extends StatelessWidget {
  final String authorId;
  final String avatarUrl;
  final String avatarEmoji;

  const _FollowableAvatar({
    required this.authorId,
    required this.avatarUrl,
    this.avatarEmoji = '🧑',
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isSelf = currentUid == authorId;

    if (authorId.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white24,
        backgroundImage:
            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(avatarEmoji, style: const TextStyle(fontSize: 20))
            : null,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(authorId)
          .snapshots(),
      builder: (context, snapshot) {
        List followers = [];
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          followers = (data['followers'] as List?) ?? [];
        }
        final bool isFollowing =
            currentUid != null && followers.contains(currentUid);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white24,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(avatarEmoji, style: const TextStyle(fontSize: 20))
                  : null,
            ),
            if (!isSelf)
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: () async {
                    if (currentUid == null) return;
                    final ref = FirebaseFirestore.instance
                        .collection('users')
                        .doc(authorId);
                    if (isFollowing) {
                      await ref.update({
                        'followers': FieldValue.arrayRemove([currentUid])
                      });
                    } else {
                      await ref.update({
                        'followers': FieldValue.arrayUnion([currentUid])
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A0F2E),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFollowing ? Icons.check_circle : Icons.add_circle,
                      color: isFollowing
                          ? Colors.greenAccent
                          : Colors.pinkAccent,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}