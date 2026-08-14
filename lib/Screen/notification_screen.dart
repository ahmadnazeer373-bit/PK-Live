import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../profile_screen.dart';
import '../vip_utils.dart';
import 'chat_screen.dart';

enum NotificationTab {
  inbox,
  friendRequests,
  notifications,
  visitors,
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  NotificationTab _selectedTab = NotificationTab.inbox;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _deletingChatIds = {};

  // 🔥 Track unread counts per tab
  int _unreadFriendRequests = 0;
  int _unreadNotifications = 0;
  int _unreadVisitors = 0;
  int _unreadChats = 0;
  int _totalUnread = 0;

  StreamSubscription<QuerySnapshot>? _friendRequestSub;
  StreamSubscription<QuerySnapshot>? _notificationSub;
  StreamSubscription<QuerySnapshot>? _visitorSub;
  StreamSubscription<QuerySnapshot>? _chatSub;

  @override
  void initState() {
    super.initState();
    _setupCountListeners();
  }

  @override
  void dispose() {
    _friendRequestSub?.cancel();
    _notificationSub?.cancel();
    _visitorSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  // 🔥 Setup listeners for unread counts
  void _setupCountListeners() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Friend Requests (followers collection)
    _friendRequestSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .listen((snap) {
      setState(() {
        _unreadFriendRequests = snap.docs.length;
        _updateTotalUnread();
      });
    });

    // Notifications (unread items)
    _notificationSub = _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      setState(() {
        _unreadNotifications = snap.docs.length;
        _updateTotalUnread();
      });
    });

    // Visitors - unread count
    _visitorSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('visitors')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      setState(() {
        _unreadVisitors = snap.docs.length;
        _updateTotalUnread();
      });
    });

    // Chats (unread messages)
    _chatSub = _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snap) {
      int unread = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
        unread += (unreadCounts[uid] ?? 0) as int;
      }
      setState(() {
        _unreadChats = unread;
        _updateTotalUnread();
      });
    });
  }

  void _updateTotalUnread() {
    _totalUnread = _unreadFriendRequests + _unreadNotifications + _unreadVisitors + _unreadChats;
  }

  // 🔥 Mark tab as read when opened
  Future<void> _markTabAsRead(NotificationTab tab) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      switch (tab) {
        case NotificationTab.friendRequests:
          break;
        case NotificationTab.notifications:
          final batch = _firestore.batch();
          final snap = await _firestore
              .collection('notifications')
              .doc(uid)
              .collection('items')
              .where('read', isEqualTo: false)
              .get();
          for (final doc in snap.docs) {
            batch.update(doc.reference, {'read': true});
          }
          await batch.commit();
          break;
        case NotificationTab.visitors:
          final batch = _firestore.batch();
          final snap = await _firestore
              .collection('users')
              .doc(uid)
              .collection('visitors')
              .where('read', isEqualTo: false)
              .get();
          for (final doc in snap.docs) {
            batch.update(doc.reference, {'read': true});
          }
          await batch.commit();
          break;
        case NotificationTab.inbox:
          final chats = await _firestore
              .collection('chats')
              .where('participants', arrayContains: uid)
              .get();
          final batch = _firestore.batch();
          for (final chatDoc in chats.docs) {
            final data = chatDoc.data() as Map<String, dynamic>;
            final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
            if ((unreadCounts[uid] ?? 0) as int > 0) {
              unreadCounts[uid] = 0;
              batch.update(chatDoc.reference, {'unreadCounts': unreadCounts});
            }
          }
          await batch.commit();
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint("Error marking tab as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
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
                      Stack(
                        children: [
                          const Text(
                            "Messages",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          if (_totalUnread > 0)
                            Positioned(
                              right: -22,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  _totalUnread > 99 ? '99+' : '$_totalUnread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTab(
                              label: "Inbox",
                              icon: Icons.chat_bubble_outline,
                              tab: NotificationTab.inbox,
                              count: _unreadChats,
                            ),
                            _buildTab(
                              label: "Friend Request",
                              icon: Icons.person_add,
                              tab: NotificationTab.friendRequests,
                              count: _unreadFriendRequests,
                            ),
                            _buildTab(
                              label: "Notifications",
                              icon: Icons.notifications,
                              tab: NotificationTab.notifications,
                              count: _unreadNotifications,
                            ),
                            _buildTab(
                              label: "Visitors",
                              icon: Icons.visibility,
                              tab: NotificationTab.visitors,
                              count: _unreadVisitors,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildTab({
    required String label,
    required IconData icon,
    required NotificationTab tab,
    required int count,
  }) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = tab);
        _markTabAsRead(tab);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF3366)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.pinkAccent.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white54,
                  size: 16,
                ),
                if (count > 0 && !isSelected)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case NotificationTab.inbox:
        return _buildInbox();
      case NotificationTab.friendRequests:
        return _buildFriendRequests();
      case NotificationTab.notifications:
        return _buildNotifications();
      case NotificationTab.visitors:
        return _buildVisitors();
    }
  }

  // 🔥 ========== INBOX (Chats) ==========
  Widget _buildInbox() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
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
          return _buildEmptyState(
            icon: Icons.chat_bubble_outline,
            title: "No Chats",
            subtitle: "When you start a conversation, it will appear here",
          );
        }

        final chats = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final data = chats[index].data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants']);
            
            if (participants.length < 2) {
              return const SizedBox.shrink();
            }
            
            String otherUid;
            try {
              otherUid = participants.firstWhere((id) => id != myUid);
            } catch (e) {
              return const SizedBox.shrink();
            }

            final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
            final avatars = Map<String, dynamic>.from(data['participantAvatars'] ?? {});

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

            final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
            final unreadCount = (unreadCounts[myUid] ?? 0) as int;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isDeleting
                  ? null
                  : () {
                      _markChatAsRead(chatId, myUid);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: otherUid,
                            otherUserName: otherName,
                          ),
                        ),
                      );
                    },
              onLongPress: isDeleting ? null : () => _confirmDeleteChat(chatId, otherName),
              child: Opacity(
                opacity: isDeleting ? 0.4 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF1A1A2E),
                          child: Text(otherAvatar, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    otherName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                    child: Text(
                                      unreadCount > 9 ? '9+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
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
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              timeStr,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markChatAsRead(String chatId, String uid) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
      if ((unreadCounts[uid] ?? 0) as int > 0) {
        unreadCounts[uid] = 0;
        await doc.reference.update({'unreadCounts': unreadCounts});
      }
    } catch (e) {
      debugPrint("Error marking chat as read: $e");
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

  Future<void> _confirmDeleteChat(String chatId, String otherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1730),
        title: const Text("Delete chat?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Your entire chat with $otherName will be permanently deleted. This can't be undone.",
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
      final chatRef = _firestore.collection('chats').doc(chatId);
      final messagesRef = chatRef.collection('messages');

      while (true) {
        final snap = await messagesRef.limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < 400) break;
      }

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

  // 🔥 ========== FRIEND REQUESTS ==========
  Widget _buildFriendRequests() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amberAccent),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.person_add_outlined,
            title: "No Friend Requests",
            subtitle: "When someone follows you, they'll appear here",
          );
        }

        final requests = snapshot.data!.docs;
        return _buildUserList(requests.map((doc) => doc.id).toList());
      },
    );
  }

  // 🔥 ========== NOTIFICATIONS ==========
  Widget _buildNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amberAccent),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.notifications_outlined,
            title: "No Notifications",
            subtitle: "When you get messages or moments, they'll appear here",
          );
        }

        final notifications = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final data = notifications[index].data() as Map<String, dynamic>? ?? {};
            final type = data['type'] ?? '';
            final title = data['title'] ?? '';
            final body = data['body'] ?? '';
            final senderId = data['senderId'] ?? '';
            
            if (senderId.isEmpty) {
              return const SizedBox.shrink();
            }
            
            final timestamp = data['timestamp'] as Timestamp?;
            final bool read = data['read'] ?? false;
            final String notificationId = notifications[index].id;

            return _buildNotificationTile(
              senderId: senderId,
              title: title,
              body: body,
              type: type,
              timestamp: timestamp,
              read: read,
              docId: notificationId,
              notificationData: data,
            );
          },
        );
      },
    );
  }

  // 🔥 ========== VISITORS ==========
  Widget _buildVisitors() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(uid)
          .collection('visitors')
          .orderBy('visitedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amberAccent),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.visibility_off_outlined,
            title: "No Visitors",
            subtitle: "When someone views your profile, they'll appear here",
          );
        }

        final visitors = snapshot.data!.docs;
        return _buildUserList(visitors.map((doc) => doc.id).toList());
      },
    );
  }

  // 🔥 ========== USER LIST ==========
  Widget _buildUserList(List<String> userIds) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUserDetails(userIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amberAccent),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: "No Users Found",
            subtitle: "",
          );
        }

        final users = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildPremiumUserTile(
              uid: user['uid'] ?? '',
              name: user['name'] ?? 'User',
              avatar: user['avatar'] ?? '🧑',
              avatarUrl: user['avatarUrl'] ?? '',
              totalRecharge: user['totalRecharge'] ?? 0,
              showFollowButton: _selectedTab == NotificationTab.friendRequests,
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserDetails(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final futures = userIds.map((uid) => _firestore.collection('users').doc(uid).get()).toList();
      final results = await Future.wait(futures);
      final users = <Map<String, dynamic>>[];

      for (final doc in results) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          users.add({
            'uid': doc.id,
            'name': data['name'] ?? 'User',
            'avatar': data['avatar'] ?? '🧑',
            'avatarUrl': data['avatarUrl'] ?? '',
            'totalRecharge': data['totalRecharge'] ?? 0,
          });
        }
      }
      return users;
    } catch (e) {
      return [];
    }
  }

  int _getVipLevel(int totalRecharge) {
    return vipLevelForCoinsSync(totalRecharge);
  }

  void _openProfile(String uid) {
    if (uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(targetUserId: uid),
      ),
    );
  }

  // 🔥 ========== PREMIUM USER TILE ==========
  Widget _buildPremiumUserTile({
    required String uid,
    required String name,
    required String avatar,
    required String avatarUrl,
    required int totalRecharge,
    bool showFollowButton = false,
  }) {
    final vipLevel = _getVipLevel(totalRecharge);
    final currentUid = _auth.currentUser?.uid;
    final isSelf = currentUid == uid;

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
              Stack(
                children: [
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
                    Text(
                      _selectedTab == NotificationTab.friendRequests
                          ? 'Wants to follow you'
                          : _selectedTab == NotificationTab.visitors
                              ? 'Visited your profile'
                              : '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (showFollowButton && !isSelf)
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(currentUid)
                      .collection('following')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final isFollowing = snapshot.hasData && snapshot.data!.exists;
                    return GestureDetector(
                      onTap: () => _handleFollowRequest(uid, isFollowing),
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
                              isFollowing ? 'Following' : 'Accept',
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

  // 🔥 ========== NOTIFICATION TILE ==========
  Widget _buildNotificationTile({
    required String senderId,
    required String title,
    required String body,
    required String type,
    required Timestamp? timestamp,
    required bool read,
    required String docId,
    required Map<String, dynamic> notificationData,
  }) {
    String timeStr = '';
    if (timestamp != null) {
      final date = timestamp.toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) timeStr = 'Just now';
      else if (diff.inMinutes < 60) timeStr = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24) timeStr = '${diff.inHours}h ago';
      else if (diff.inDays < 7) timeStr = '${diff.inDays}d ago';
      else timeStr = '${(diff.inDays / 7).floor()}w ago';
    }

    IconData icon;
    Color iconColor;
    if (type == 'message') {
      icon = Icons.chat_bubble_outline;
      iconColor = Colors.blueAccent;
    } else if (type == 'moment') {
      icon = Icons.post_add;
      iconColor = Colors.amberAccent;
    } else if (type == 'follow') {
      icon = Icons.person_add;
      iconColor = Colors.pinkAccent;
    } else {
      icon = Icons.notifications;
      iconColor = Colors.purpleAccent;
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(senderId).get(),
      builder: (context, snapshot) {
        String name = 'User';
        String avatar = '🧑';
        String avatarUrl = '';
        int totalRecharge = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          name = data['name'] ?? 'User';
          avatar = data['avatar'] ?? '🧑';
          avatarUrl = data['avatarUrl'] ?? '';
          totalRecharge = data['totalRecharge'] ?? 0;
        }

        return GestureDetector(
          onTap: () => _handleNotificationTap(
            type: type,
            senderId: senderId,
            docId: docId,
            notificationData: notificationData,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: read
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: read
                    ? Colors.white.withOpacity(0.04)
                    : Colors.amberAccent.withOpacity(0.2),
                width: read ? 0.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openProfile(senderId),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(avatar, style: const TextStyle(fontSize: 18))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(icon, color: iconColor, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🔥 ========== HANDLE NOTIFICATION TAP ==========
  Future<void> _handleNotificationTap({
    required String type,
    required String senderId,
    required String docId,
    required Map<String, dynamic> notificationData,
  }) async {
    if (senderId.isEmpty) return;

    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore
            .collection('notifications')
            .doc(uid)
            .collection('items')
            .doc(docId)
            .update({'read': true});
      }
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }

    if (type == 'follow') {
      _openProfile(senderId);
    } else if (type == 'moment') {
      _openMoment(senderId, notificationData);
    } else if (type == 'message') {
      _openChat(senderId);
    } else {
      _openProfile(senderId);
    }
  }

  // 🔥 Open Moment/Post
  void _openMoment(String senderId, Map<String, dynamic> notificationData) {
    if (senderId.isEmpty) return;
    
    final postId = notificationData['postId'] as String?;
    
    if (postId != null && postId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            postId: postId,
            userId: senderId,
          ),
        ),
      );
    } else {
      _openProfile(senderId);
    }
  }

  // 🔥 Open Chat
  void _openChat(String userId) async {
    if (userId.isEmpty) return;
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      final name = data['name'] ?? 'User';
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUserId: userId,
              otherUserName: name,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error opening chat: $e");
    }
  }

  // 🔥 ========== EMPTY STATE ==========
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              icon,
              color: Colors.white24,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
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

  // 🔥 ========== HANDLE FOLLOW REQUEST ==========
  Future<void> _handleFollowRequest(String targetUid, bool isFollowing) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    try {
      if (!isFollowing) {
        final currentUserRef = _firestore.collection('users').doc(currentUid);
        final targetUserRef = _firestore.collection('users').doc(targetUid);
        final followRef = currentUserRef.collection('following').doc(targetUid);

        await followRef.set({
          'followedAt': FieldValue.serverTimestamp(),
          'targetUserId': targetUid,
        });

        await currentUserRef.collection('friends').doc(targetUid).set({
          'friendId': targetUid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await targetUserRef.collection('friends').doc(currentUid).set({
          'friendId': currentUid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await currentUserRef.update({
          'followingCount': FieldValue.increment(1),
          'friendsCount': FieldValue.increment(1),
        });

        await targetUserRef.update({
          'followersCount': FieldValue.increment(1),
          'friendsCount': FieldValue.increment(1),
        });

        await currentUserRef.collection('followers').doc(targetUid).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request accepted!'),
              backgroundColor: Colors.green,
            ),
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
}

// 🔥 ========== POST DETAIL SCREEN ==========
class PostDetailScreen extends StatelessWidget {
  final String postId;
  final String userId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Moment",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plaza_posts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amberAccent),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "Post not found",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final doc = snapshot.data!;
          final data = doc.data() as Map<String, dynamic>? ?? {};
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      child: Text(
                        data['userAvatarEmoji'] ?? '🧑',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      data['userName'] ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if ((data['caption'] ?? '').toString().isNotEmpty)
                  Text(
                    data['caption'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                const SizedBox(height: 10),
                if ((data['imageUrls'] as List?)?.isNotEmpty ?? false)
                  ...((data['imageUrls'] as List?) ?? []).map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url.toString(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 300,
                          color: Colors.white10,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.amberAccent,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 300,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white38,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  )),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.favorite_border,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data['likesCount'] ?? 0}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.mode_comment_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data['commentsCount'] ?? 0}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}