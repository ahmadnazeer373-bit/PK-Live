import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'auth_screen.dart';
import 'agency_application_screen.dart';
import 'admin_agency_review_screen.dart';
import 'gift_catalog_admin_screen.dart';
import 'admin_coin_topup_screen.dart';
import 'Screen/vip_admin_screen.dart';
import 'Screen/party_room_screen.dart';
import 'pk_live_card_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'become_host_screen.dart';
import 'host_center_screen.dart';
import 'agency_owner_dashboard.dart';
import 'Screen/vip_center_screen.dart';
import 'Screen/level_rules_screen.dart';
import 'services/level_service.dart';
import 'vip_utils.dart';
import 'screen/chat_screen.dart';
import 'Screen/create_post_screen.dart';
import 'widgets/post_card.dart';
import 'follow_list_screen.dart';

const String _adminUid = "1dd7eMMAm9dp6QqOzQsr5eJXPjB2";

class ProfileScreen extends StatefulWidget {
  final String? targetUserId;

  const ProfileScreen({super.key, this.targetUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0;
  bool _isAssigningUserId = false;
  bool _isCreatingRoom = false;
  List<Map<String, dynamic>> _levelRules = [];
  
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  String get _userIdToShow {
    if (widget.targetUserId != null && widget.targetUserId!.isNotEmpty) {
      return widget.targetUserId!;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  bool get _isOwnProfile {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return widget.targetUserId == null ||
        widget.targetUserId!.isEmpty ||
        widget.targetUserId == currentUid;
  }

  @override
  void initState() {
    super.initState();
    _loadLevelRules();
    if (!_isOwnProfile) {
      _checkFollowStatus();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadLevelRules() async {
    try {
      final sendingRules = await LevelService.instance.getLevelRules(type: 'sending');
      final receivingRules = await LevelService.instance.getLevelRules(type: 'receiving');
      setState(() {
        _levelRules = [...sendingRules, ...receivingRules];
      });
    } catch (e) {
      print("❌ Error loading level rules: $e");
    }
  }

  Color _getLevelColor(int level) {
    for (final rule in _levelRules) {
      if (rule['level'] == level) {
        final colorHex = rule['color'] ?? '#FFD700';
        try {
          return Color(int.parse(colorHex.replaceAll('#', '0xFF')));
        } catch (_) {
          return Colors.amber;
        }
      }
    }
    return Colors.grey;
  }

  Future<void> _refreshProfile() async {
    await _loadLevelRules();
    if (!_isOwnProfile) {
      await _checkFollowStatus();
    }
    setState(() {});
  }

  // 🔥 FIXED: Sirf following subcollection check karein
  Future<void> _checkFollowStatus() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _userIdToShow.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(_userIdToShow)
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

  // 🔥 FIXED: Sirf following subcollection use karein
  Future<void> _toggleFollow() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _userIdToShow.isEmpty || _isFollowLoading) return;

    setState(() => _isFollowLoading = true);

    try {
      final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
      final targetUserRef = FirebaseFirestore.instance.collection('users').doc(_userIdToShow);
      
      // 🔥 SIRF following SUBCOLLECTION USE KAREIN
      final followRef = currentUserRef.collection('following').doc(_userIdToShow);

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
          'targetUserId': _userIdToShow,
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
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  void _openChat() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    
    if (_userIdToShow == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't chat with yourself")),
      );
      return;
    }

    setState(() => _isFollowLoading = true);

    try {
      final followingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(_userIdToShow)
          .get();

      final followerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userIdToShow)
          .collection('following')
          .doc(currentUid)
          .get();

      final iFollowThem = followingDoc.exists;
      final theyFollowMe = followerDoc.exists;

      if (!iFollowThem || !theyFollowMe) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B1930),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amberAccent),
                SizedBox(width: 10),
                Text(
                  "Cannot Message",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              "You can only message users who follow you back.\n\nPlease follow them and ask them to follow you to start chatting.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Got it",
                  style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        setState(() => _isFollowLoading = false);
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(_userIdToShow);
      final doc = await userRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? 'User';
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                otherUserId: _userIdToShow,
                otherUserName: name,
              ),
            ),
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
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<String> _getNextUserId() async {
    final counterRef = FirebaseFirestore.instance.collection('meta').doc('userIdCounter');

    final nextId = await FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int newId;
      if (!snapshot.exists) {
        newId = 1123456;
      } else {
        final lastId = (snapshot.data()?['lastId'] as num).toInt();
        newId = lastId + 1;
      }

      transaction.set(counterRef, {'lastId': newId});
      return newId;
    });

    return nextId.toString();
  }

  Future<void> _backfillUserIdIfMissing(String uid, String existingUserID) async {
    if (existingUserID.isNotEmpty || _isAssigningUserId) return;
    _isAssigningUserId = true;
    try {
      final newUserID = await _getNextUserId();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'userID': newUserID});
    } catch (e) {
      debugPrint("Failed to backfill userID: $e");
    } finally {
      _isAssigningUserId = false;
    }
  }

  Future<void> _openMyRoom() async {
    final uid = _userIdToShow;
    if (uid.isEmpty || _isCreatingRoom) return;

    if (!_isOwnProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only open your own room")),
      );
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('party_rooms')
        .where('hostUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (!mounted) return;

    if (query.docs.isNotEmpty) {
      final roomId = query.docs.first.id;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PartyRoomScreen(roomId: roomId)),
      );
      return;
    }

    await _createMyRoom(uid);
  }

  Future<void> _createMyRoom(String uid) async {
    setState(() => _isCreatingRoom = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final hostName = userData['name'] ?? "Host";

      final roomDoc = await FirebaseFirestore.instance.collection('party_rooms').add({
        'title': "$hostName's Room",
        'hostUid': uid,
        'hostName': hostName,
        'hostAvatar': userData['avatar'] ?? "👑",
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PartyRoomScreen(roomId: roomDoc.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't create room: $e")),
      );
    } finally {
      if (mounted) setState(() => _isCreatingRoom = false);
    }
  }

  Future<void> _copyUserId(String userID) async {
    if (userID.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: userID));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text("Copied!", textAlign: TextAlign.center),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B1930),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 140, vertical: 40),
        ),
      );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Do you want to sign out?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _signOut();
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't sign out: $e")),
      );
    }
  }

  void _navigateToCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePostScreen(),
      ),
    );
  }

  void _navigateToFollowList(FollowListType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListScreen(
          userId: _userIdToShow,
          listType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _userIdToShow;

    if (uid.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("User not found", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Error loading profile:\n${snapshot.error}",
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

            final avatar = data['avatar'] ?? "🧑";
            final avatarUrl = data['avatarUrl'] as String?;
            final coverIndex = data['coverIndex'] ?? 0;
            final coverPhotoUrl = data['coverPhotoUrl'] as String?;
            final name = data['name'] ?? "User";
            final userID = data['userID'] ?? "";
            if (userID.isEmpty && _isOwnProfile) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _backfillUserIdIfMissing(uid, userID);
              });
            }
            final country = data['country'] ?? "";
            final personalNote = data['bio'] ?? "";

            final coins = (data['coins'] ?? 0).toString();
            final earnedCoins = (data['earnedCoins'] ?? 0).toString();
            final ownedAgencyId = data['ownedAgencyId'] as String?;
            final agencyId = data['agencyId'] as String?;

            final friendsCount = (data['friendsCount'] ?? 0).toString();
            final followersCount = (data['followersCount'] ?? 0).toString();
            final followingCount = (data['followingCount'] ?? 0).toString();
            
            final age = data['age'];
            final ageString = age?.toString() ?? '';
            
            final gender = (data['gender'] as String?)?.toLowerCase();
            
            final sendLevel = data['sendingLevel'] ?? 1;
            final receiveLevel = data['receivingLevel'] ?? 1;
            
            final totalRecharge = (data['totalRecharge'] ?? 0) as int;
            final vipLevel = vipLevelForCoinsSync(totalRecharge);

            final sendColor = _getLevelColor(sendLevel);
            final receiveColor = _getLevelColor(receiveLevel);

            IconData? genderIcon;
            Color genderColor = Colors.white54;
            if (gender == 'male') {
              genderIcon = Icons.male;
              genderColor = const Color(0xFF4FC3F7);
            } else if (gender == 'female') {
              genderIcon = Icons.female;
              genderColor = const Color(0xFFFF6FA5);
            }

            final covers = [
              [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
              [const Color(0xFF1F1C2C), const Color(0xFF928DAB)],
              [const Color(0xFFDA22FF), const Color(0xFF9733EE)],
              [const Color(0xFF0F2027), const Color(0xFF2C5364)],
              [const Color(0xFF373B44), const Color(0xFF4286F4)],
              [const Color(0xFFEE0979), const Color(0xFFFF6A00)],
            ];

            final hasCoverPhoto = coverPhotoUrl != null && coverPhotoUrl.isNotEmpty;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1B1730), Color(0xFF0E0C18)],
                    stops: [0.0, 0.35],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 220,
                          width: double.infinity,
                          decoration: hasCoverPhoto
                              ? BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(coverPhotoUrl),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : BoxDecoration(
                                  gradient: LinearGradient(colors: covers[coverIndex]),
                                ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.05),
                                  const Color(0xFF0E0C18).withOpacity(0.85),
                                ],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          left: 16,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ),
                        if (_isOwnProfile)
                          Positioned(
                            top: 40,
                            right: 60,
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('notifications')
                                  .doc(uid)
                                  .collection('items')
                                  .where('read', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, notifSnapshot) {
                                final unreadCount = notifSnapshot.data?.docs.length ?? 0;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                                        );
                                      },
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF0E0C18), width: 1.5),
                                          ),
                                          child: Text(
                                            unreadCount > 9 ? "9+" : "$unreadCount",
                                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        if (_isOwnProfile)
                          Positioned(
                            top: 40,
                            right: 16,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                                );
                              },
                            ),
                          ),
                        Positioned(
                          bottom: -45,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.35),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0E0C18),
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.white10,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Text(avatar, style: const TextStyle(fontSize: 40))
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 55),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _copyUserId(userID),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("ID: $userID", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy_rounded, size: 13, color: Colors.white38),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (country.isNotEmpty)
                                Text(country, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              _socialCountClickable(friendsCount, "Friends", FollowListType.friends),
                              _socialDivider(),
                              _socialCountClickable(followersCount, "Followers", FollowListType.followers),
                              _socialDivider(),
                              _socialCountClickable(followingCount, "Following", FollowListType.following),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (ageString.isNotEmpty && ageString != 'null' && ageString != '')
                                _iconValuePill(icon: Icons.cake, value: ageString, color: Colors.amberAccent),
                              _iconValuePill(
                                icon: Icons.workspace_premium,
                                value: vipLevel > 0 ? "VIP $vipLevel" : "VIP 0",
                                color: vipLevel > 0 ? Colors.amber : Colors.grey,
                              ),
                              if (genderIcon != null)
                                _iconValuePill(
                                  icon: genderIcon,
                                  value: gender == 'male' ? "Male" : "Female",
                                  color: genderColor,
                                ),
                              _iconValuePill(
                                icon: Icons.diamond,
                                value: "$sendLevel",
                                color: sendColor,
                              ),
                              _iconValuePill(
                                icon: Icons.favorite,
                                value: "$receiveLevel",
                                color: receiveColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (personalNote.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.note,
                                    color: Colors.white38,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      personalNote,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_isOwnProfile) ...[
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('plaza_posts')
                                  .where('userId', isEqualTo: uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                return Row(
                                  children: [
                                    _tabButton("About me", 0),
                                    const SizedBox(width: 20),
                                    _tabButton("Moment", 1, count: count.toString()),
                                  ],
                                );
                              },
                            ),
                            const Divider(color: Colors.white12, height: 24),
                            
                            if (selectedTab == 0) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _walletStatCard(
                                      icon: Icons.monetization_on,
                                      label: "Coins",
                                      value: coins,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _walletStatCard(
                                      icon: Icons.monetization_on_outlined,
                                      label: "Earned Coins",
                                      value: earnedCoins,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (ownedAgencyId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AgencyOwnerDashboard()),
                                      );
                                    } else if (agencyId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const HostCenterScreen()),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const BecomeHostScreen()),
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    ownedAgencyId != null
                                        ? Icons.dashboard_customize
                                        : (agencyId != null ? Icons.mic_external_on : Icons.workspace_premium),
                                    color: Colors.amberAccent,
                                  ),
                                  label: Text(
                                    ownedAgencyId != null
                                        ? "Agency Dashboard"
                                        : (agencyId != null ? "Host Center" : "Become a Host"),
                                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.amberAccent.withOpacity(0.10),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Colors.amberAccent),
                                    elevation: 0,
                                    shadowColor: Colors.amberAccent.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildPremiumGrid(),

                              const SizedBox(height: 16),

                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _menuListTile(
                                      icon: Icons.meeting_room_outlined,
                                      label: "My Room",
                                      onTap: _openMyRoom,
                                    ),
                                    const Divider(color: Colors.white12, height: 1, indent: 56),
                                    _menuListTile(
                                      icon: Icons.badge_outlined,
                                      label: "My PK-Live Card",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const PkLiveCardScreen()),
                                        );
                                      },
                                    ),
                                    const Divider(color: Colors.white12, height: 1, indent: 56),
                                    _menuListTile(
                                      icon: Icons.settings_outlined,
                                      label: "Setting",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // BOTTOM ICONS (Points, Pulsation, Pending)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _bottomIconTile(
                                      icon: Icons.star_border,
                                      label: "Points",
                                      value: "0",
                                      color: Colors.amberAccent,
                                    ),
                                    _bottomIconTile(
                                      icon: Icons.favorite_border,
                                      label: "Pulsation",
                                      value: "0",
                                      color: Colors.pinkAccent,
                                    ),
                                    _bottomIconTile(
                                      icon: Icons.pending_outlined,
                                      label: "Pending",
                                      value: "0",
                                      color: Colors.blueAccent,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              if (FirebaseAuth.instance.currentUser?.uid == _adminUid) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AdminAgencyReviewScreen()),
                                      );
                                    },
                                    icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.greenAccent),
                                    label: const Text(
                                      "Admin: Review Agencies",
                                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent.withOpacity(0.10),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Colors.greenAccent),
                                      elevation: 0,
                                      shadowColor: Colors.greenAccent.withOpacity(0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const GiftCatalogAdminScreen()),
                                      );
                                    },
                                    icon: const Icon(Icons.card_giftcard, color: Colors.greenAccent),
                                    label: const Text(
                                      "Admin: Gift Catalog",
                                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent.withOpacity(0.10),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Colors.greenAccent),
                                      elevation: 0,
                                      shadowColor: Colors.greenAccent.withOpacity(0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AdminCoinTopupScreen()),
                                      );
                                    },
                                    icon: const Icon(Icons.monetization_on_outlined, color: Colors.greenAccent),
                                    label: const Text(
                                      "Admin: Coin Top-Up",
                                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent.withOpacity(0.10),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Colors.greenAccent),
                                      elevation: 0,
                                      shadowColor: Colors.greenAccent.withOpacity(0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const VipAdminScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.workspace_premium,
                                      color: Colors.greenAccent,
                                    ),
                                    label: const Text(
                                      "Admin: VIP Management",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent.withOpacity(0.10),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(
                                        color: Colors.greenAccent,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const LevelRulesScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.settings_applications,
                                      color: Colors.greenAccent,
                                    ),
                                    label: const Text(
                                      "Admin: Level Rules",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent.withOpacity(0.10),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Colors.greenAccent),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                            ] else ...[
                              _buildMomentTab(uid),
                            ],
                          ] else ...[
                            const SizedBox(height: 8),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _actionButton(
                                    icon: Icons.chat_bubble_outline,
                                    label: "Message",
                                    color: Colors.blueAccent,
                                    onTap: _openChat,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                
                                Expanded(
                                  child: _isFollowLoading
                                      ? Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.amberAccent,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        )
                                      : _actionButton(
                                          icon: _isFollowing ? Icons.check : Icons.person_add,
                                          label: _isFollowing ? "Following" : "Follow",
                                          color: _isFollowing ? Colors.grey : Colors.amberAccent,
                                          onTap: _toggleFollow,
                                        ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Text(
                                  "Viewing @$name's profile",
                                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            _buildMomentTab(uid),
                            const SizedBox(height: 30),
                          ],
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ========== MOMENT TAB ==========
  Widget _buildMomentTab(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Text(
                "Moments",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('plaza_posts')
                    .where('userId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '0',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  final count = snapshot.data!.docs.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              if (_isOwnProfile)
                GestureDetector(
                  onTap: _navigateToCreatePost,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF3366)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Create',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('plaza_posts')
              .where('userId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Colors.amberAccent,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.post_add_outlined,
                        color: Colors.white24,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isOwnProfile ? "No moments yet" : "No moments yet",
                        style: const TextStyle(color: Colors.white38),
                      ),
                      if (_isOwnProfile)
                        Text(
                          "Tap 'Create' to share your moment!",
                          style: const TextStyle(color: Colors.white24),
                        ),
                    ],
                  ),
                ),
              );
            }

            final posts = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return PostCard(doc: posts[index]);
              },
            );
          },
        ),
      ],
    );
  }

  // ========== WIDGETS ==========
  
  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.20),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumGrid() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Premium Features",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.75,
            children: [
              _premiumGridItem(
                icon: Icons.workspace_premium,
                label: "VIP Center",
                color: Colors.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VipCenterScreen()),
                  );
                },
              ),
              _premiumGridItem(
                icon: Icons.people_outline,
                label: "Relationship",
                color: Colors.pinkAccent,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Relationship coming soon")),
                  );
                },
              ),
              _premiumGridItem(
                icon: Icons.backpack_outlined,
                label: "Backpack",
                color: Colors.greenAccent,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Backpack coming soon")),
                  );
                },
              ),
              _premiumGridItem(
                icon: Icons.store_outlined,
                label: "Store",
                color: Colors.blueAccent,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Store coming soon")),
                  );
                },
              ),
              _premiumGridItem(
                icon: Icons.sports_esports_outlined,
                label: "Games",
                color: Colors.purpleAccent,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Games coming soon")),
                  );
                },
              ),
              _premiumGridItem(
                icon: Icons.more_horiz,
                label: "More",
                color: Colors.grey,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("More features coming soon")),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _premiumGridItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.25),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialCountClickable(String value, String label, FollowListType type) {
    return GestureDetector(
      onTap: () => _navigateToFollowList(type),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white12,
    );
  }

  Widget _iconValuePill({required IconData icon, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _bottomIconTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.16), Colors.white.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, {String? count}) {
    final isSelected = selectedTab == index;
    final displayLabel = count != null ? "$label ($count)" : label;
    
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayLabel,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isSelected ? 22 : 0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuListTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amberAccent.withOpacity(0.22), Colors.amberAccent.withOpacity(0.08)],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.amberAccent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.35), color.withOpacity(0.12)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 8),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}