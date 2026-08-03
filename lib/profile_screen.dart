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
import 'Screen/party_room_screen.dart';
import 'pk_live_card_screen.dart';
import 'notifications_screen.dart';
// ASSUMPTION: adjust this import path / class name once confirmed —
// this should point to your existing settings_screen.dart.
import 'settings_screen.dart';
// ASSUMPTION: adjust these import paths / class names if they differ from
// what was built earlier in your project (become_host_screen.dart,
// host_center_screen.dart, agency_owner_dashboard.dart).
import 'become_host_screen.dart';
import 'host_center_screen.dart';
import 'agency_owner_dashboard.dart';

// Only this UID will see the Admin option in the profile screen.
const String _adminUid = "1dd7eMMAm9dp6QqOzQsr5eJXPjB2";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0; // 0 = About me, 1 = Moment
  bool _isAssigningUserId = false;
  bool _isCreatingRoom = false;

  User? get user => FirebaseAuth.instance.currentUser;

  /// Same sequential counter used at signup. Old accounts created before
  /// the userID system existed are missing this field — this backfills
  /// them automatically the first time they open their profile.
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
    final uid = user?.uid;
    if (uid == null || _isCreatingRoom) return;

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

    // No active room yet — create one now and jump straight in.
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

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("Login required", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: StreamBuilder<DocumentSnapshot>(
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final avatar = data['avatar'] ?? "🧑";
          final avatarUrl = data['avatarUrl'] as String?;
          final coverIndex = data['coverIndex'] ?? 0;
          final coverPhotoUrl = data['coverPhotoUrl'] as String?;
          final name = data['name'] ?? "User";
          final userID = data['userID'] ?? "";
          if (userID.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _backfillUserIdIfMissing(uid, userID);
            });
          }
          final country = data['country'] ?? "";
          final bio = data['bio'] ?? "";

          // ASSUMPTION: adjust field names if your schema differs.
          final coins = (data['coins'] ?? 0).toString();
          final diamonds = (data['diamonds'] ?? 0).toString();
          final ownedAgencyId = data['ownedAgencyId'] as String?;
          final agencyId = data['agencyId'] as String?;

          // ASSUMPTION: adjust these field names if your users/{uid}
          // schema uses different keys for these values.
          final friendsCount = (data['friendsCount'] ?? 0).toString();
          final followersCount = (data['followersCount'] ?? 0).toString();
          final followingCount = (data['followingCount'] ?? 0).toString();
          final age = data['age']?.toString();
          final gender = (data['gender'] as String?)?.toLowerCase();
          final sendLevel = data['sendLevel']?.toString() ?? data['sendingLevel']?.toString() ?? "1";
          final receiveLevel = data['receiveLevel']?.toString() ?? data['receivingLevel']?.toString() ?? "1";

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

                      // ---------- Friends / Followers / Following ----------
                      Row(
                        children: [
                          _socialCount(friendsCount, "Friends"),
                          _socialDivider(),
                          _socialCount(followersCount, "Followers"),
                          _socialDivider(),
                          _socialCount(followingCount, "Following"),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ---------- Age / Gender / Send level / Receive level ----------
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (age != null) _iconValuePill(icon: Icons.cake, value: age, color: Colors.amberAccent),
                          if (genderIcon != null)
                            _iconValuePill(
                              icon: genderIcon,
                              value: gender == 'male' ? "Male" : "Female",
                              color: genderColor,
                            ),
                          _iconValuePill(icon: Icons.arrow_upward, value: sendLevel, color: const Color(0xFF7CD992)),
                          _iconValuePill(icon: Icons.arrow_downward, value: receiveLevel, color: const Color(0xFF7CB8FF)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _badge("Lv.1", Colors.blueAccent),
                          _badge("New Member", Colors.pinkAccent),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _tabButton("About me", 0),
                          const SizedBox(width: 20),
                          _tabButton("Moment", 1),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      if (selectedTab == 0) ...[
                        if (bio.isNotEmpty) ...[
                          Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 20),
                        ],

                        // ---------- Coins & Diamonds ----------
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
                                icon: Icons.diamond,
                                label: "Diamonds",
                                value: diamonds,
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ---------- Become a Host / Host Center / Agency Dashboard ----------
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
                        const SizedBox(height: 24),

                        // ---------- My Room / My PK-Live Card / Setting ----------
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

                        if (user?.uid == _adminUid) ...[
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
                        ],
                        if (ownedAgencyId == null && agencyId == null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AgencyApplicationScreen()),
                                );
                              },
                              icon: const Icon(Icons.business_center_outlined, color: Colors.amberAccent),
                              label: const Text(
                                "Apply for Agency",
                                style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
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
                          const SizedBox(height: 14),
                        ],
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text("No moments yet", style: TextStyle(color: Colors.white38)),
                          ),
                        ),
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
    );
  }

  Widget _socialCount(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
        ],
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

  Widget _tabButton(String label, int index) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
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