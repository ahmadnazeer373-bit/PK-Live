import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'profile_screen.dart';
import 'vip_utils.dart';

enum FollowListType {
  friends,
  followers,
  following,
}

class FollowListScreen extends StatefulWidget {
  final String userId;
  final FollowListType listType;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.listType,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  // 🔥 Real-time listeners: list refreshes instantly on any follow/unfollow,
  // from anywhere in the app, without needing to reopen this screen.
  StreamSubscription<QuerySnapshot>? _followingSub;
  StreamSubscription<QuerySnapshot>? _followersSub;

  Set<String> _followingIds = {};
  Set<String> _followerIds = {};
  bool _followingReady = false;
  bool _followersReady = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    _followingSub?.cancel();
    _followersSub?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    if (widget.listType == FollowListType.following) {
      // Live: users/{userId}/following
      _followingSub = _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('following')
          .snapshots()
          .listen((snap) {
        _followingIds = snap.docs.map((d) => d.id).toSet();
        _refreshDisplayedUsers();
      }, onError: (e) => print("Error listening to following: $e"));
    } else if (widget.listType == FollowListType.followers) {
      // Live: every 'following' doc across all users whose targetUserId == widget.userId
      _followersSub = _firestore
          .collectionGroup('following')
          .where('targetUserId', isEqualTo: widget.userId)
          .snapshots()
          .listen((snap) {
        _followerIds = snap.docs
            .map((d) => d.reference.parent.parent?.id)
            .whereType<String>()
            .toSet();
        _refreshDisplayedUsers();
      }, onError: (e) => print("Error listening to followers: $e"));
    } else {
      // Friends = mutual follow, needs both streams live at once
      _followingSub = _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('following')
          .snapshots()
          .listen((snap) {
        _followingIds = snap.docs.map((d) => d.id).toSet();
        _followingReady = true;
        _refreshDisplayedUsers();
      }, onError: (e) => print("Error listening to following: $e"));

      _followersSub = _firestore
          .collectionGroup('following')
          .where('targetUserId', isEqualTo: widget.userId)
          .snapshots()
          .listen((snap) {
        _followerIds = snap.docs
            .map((d) => d.reference.parent.parent?.id)
            .whereType<String>()
            .toSet();
        _followersReady = true;
        _refreshDisplayedUsers();
      }, onError: (e) => print("Error listening to followers: $e"));
    }
  }

  Future<void> _refreshDisplayedUsers() async {
    List<String> ids;
    if (widget.listType == FollowListType.following) {
      ids = _followingIds.toList();
    } else if (widget.listType == FollowListType.followers) {
      ids = _followerIds.toList();
    } else {
      if (!_followingReady || !_followersReady) return; // wait for both sides
      ids = _followingIds.intersection(_followerIds).toList();
    }

    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
      }
      return;
    }

    await _fetchUserDetails(ids);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUserDetails(List<String> userIds) async {
    if (userIds.isEmpty) {
      _users = [];
      return;
    }

    try {
      final futures = userIds.map((uid) => _firestore.collection('users').doc(uid).get()).toList();
      final results = await Future.wait(futures);

      final freshUsers = <Map<String, dynamic>>[];
      for (final doc in results) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          freshUsers.add({
            'uid': doc.id,
            'name': data['name'] ?? 'User',
            'avatar': data['avatar'] ?? '🧑',
            'avatarUrl': data['avatarUrl'] ?? '',
            'totalRecharge': data['totalRecharge'] ?? 0,
          });
        }
      }

      freshUsers.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      _users = freshUsers;
      if (mounted) setState(() {});
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }

  int _getVipLevel(int totalRecharge) {
    return vipLevelForCoinsSync(totalRecharge);
  }

  void _openProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(targetUserId: uid),
      ),
    );
  }

  // 🔥 CHANGE 1: _toggleFollow UPDATED with mutual friends logic
  Future<void> _toggleFollow(String targetUid, bool isFollowing) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || targetUid == currentUid) return;

    try {
      final currentUserRef = _firestore.collection('users').doc(currentUid);
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      final followRef = currentUserRef.collection('following').doc(targetUid);

      if (isFollowing) {
        // UNFOLLOW
        await followRef.delete();
        await currentUserRef.update({'followingCount': FieldValue.increment(-1)});
        await targetUserRef.update({'followersCount': FieldValue.increment(-1)});
        
        // 🔥 NEW: Remove from friends if exists
        await currentUserRef.collection('friends').doc(targetUid).delete();
        await targetUserRef.collection('friends').doc(currentUid).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unfollowed'), backgroundColor: Colors.grey),
          );
        }
      } else {
        // FOLLOW
        await followRef.set({
          'followedAt': FieldValue.serverTimestamp(),
          'targetUserId': targetUid,
        });
        await currentUserRef.update({'followingCount': FieldValue.increment(1)});
        await targetUserRef.update({'followersCount': FieldValue.increment(1)});
        
        // 🔥 NEW: Check for mutual follow
        final reverseCheck = await targetUserRef
            .collection('following')
            .doc(currentUid)
            .get();

        if (reverseCheck.exists) {
          // Mutual follow - add to friends
          await currentUserRef.collection('friends').doc(targetUid).set({
            'friendId': targetUid,
            'timestamp': FieldValue.serverTimestamp(),
          });

          await targetUserRef.collection('friends').doc(currentUid).set({
            'friendId': currentUid,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Followed!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.listType == FollowListType.friends
        ? 'Friends'
        : widget.listType == FollowListType.followers
            ? 'Followers'
            : 'Following';

    final String subtitle = widget.listType == FollowListType.friends
        ? 'Mutual connections'
        : widget.listType == FollowListType.followers
            ? 'People who follow you'
            : 'People you follow';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A0F2E),
                Color(0xFF0D0B1E),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.amberAccent,
              ),
            )
          : _users.isEmpty
              ? _buildEmptyState(title)
              : Column(
                  children: [
                    // 🔥 Stats Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            widget.listType == FollowListType.friends
                                ? Icons.people_alt
                                : widget.listType == FollowListType.followers
                                    ? Icons.person_add_alt_1
                                    : Icons.person_outline,
                            color: Colors.amberAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_users.length} $title',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_users.length}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final String uid = user['uid'] ?? '';
                          final String name = user['name'] ?? 'User';
                          final String avatar = user['avatar'] ?? '🧑';
                          final String avatarUrl = user['avatarUrl'] ?? '';
                          final int vipLevel = _getVipLevel(user['totalRecharge'] ?? 0);
                          final bool isSelf = _auth.currentUser?.uid == uid;

                          return _buildPremiumUserTile(
                            uid: uid,
                            name: name,
                            avatar: avatar,
                            avatarUrl: avatarUrl,
                            vipLevel: vipLevel,
                            isSelf: isSelf,
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  // 🔥 Premium User Tile
  Widget _buildPremiumUserTile({
    required String uid,
    required String name,
    required String avatar,
    required String avatarUrl,
    required int vipLevel,
    required bool isSelf,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => _openProfile(uid),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 🔥 Premium Profile Picture with Glow
              Stack(
                children: [
                  // Glow Effect
                  if (vipLevel > 0)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.amber.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          radius: 0.8,
                        ),
                      ),
                    ),
                  // Profile Picture with VIP Border
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: vipLevel > 0
                          ? const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                            )
                          : null,
                      boxShadow: vipLevel > 0
                          ? [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF0D0B1E),
                        backgroundImage: avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                avatar,
                                style: const TextStyle(fontSize: 22),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // 🔥 Name + VIP
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vipLevel > 0) ...[
                          const SizedBox(width: 6),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.black,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'VIP $vipLevel',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 🔥 Mutual/Badge
                    if (widget.listType == FollowListType.friends)
                      Row(
                        children: [
                          Icon(
                            Icons.sync_alt,
                            color: Colors.greenAccent.withOpacity(0.6),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mutual connection',
                            style: TextStyle(
                              color: Colors.greenAccent.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // 🔥 Follow Button (Premium Style)
              if (!isSelf)
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .collection('following')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final isFollowing = snapshot.hasData && snapshot.data!.exists;
                    return GestureDetector(
                      onTap: () => _toggleFollow(uid, isFollowing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: isFollowing
                              ? LinearGradient(
                                  colors: [
                                    Colors.greenAccent.withOpacity(0.15),
                                    Colors.greenAccent.withOpacity(0.05),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFFFF6B6B), Color(0xFFFF3366)],
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isFollowing
                                ? Colors.greenAccent
                                : Colors.transparent,
                            width: 1,
                          ),
                          boxShadow: isFollowing
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.pinkAccent.withOpacity(0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowing ? Icons.check : Icons.person_add,
                              color: isFollowing
                                  ? Colors.greenAccent
                                  : Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: isFollowing
                                    ? Colors.greenAccent
                                    : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 Empty State
  Widget _buildEmptyState(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.listType == FollowListType.friends
                  ? Icons.people_outline
                  : widget.listType == FollowListType.followers
                      ? Icons.person_add_alt_1
                      : Icons.person_outline,
              color: Colors.white24,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No $title yet',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.listType == FollowListType.friends
                ? 'When you and others follow each other,\nthey\'ll appear here'
                : widget.listType == FollowListType.followers
                    ? 'When people follow you,\nthey\'ll appear here'
                    : 'When you follow people,\nthey\'ll appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}