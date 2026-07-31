import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'auth_screen.dart';
import 'become_host_screen.dart';
import 'admin_agency_review_screen.dart';
import 'agency_owner_dashboard.dart';
import 'host_center_screen.dart';

// Only this UID will see the Admin option in the profile screen.
const String _adminUid = "1dd7eMMAm9dp6QqOzQsr5eJXPjB2";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0; // 0 = About me, 1 = Moment

  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Kya aap sign out karna chahte hain?",
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
        SnackBar(content: Text("Sign out nahi ho saka: $e")),
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
          final coverIndex = data['coverIndex'] ?? 0;
          final coverPhotoUrl = data['coverPhotoUrl'] as String?;
          final name = data['name'] ?? "User";
          final userID = data['userID'] ?? "";
          final country = data['country'] ?? "";
          final bio = data['bio'] ?? "";
          final ownedAgencyId = data['ownedAgencyId'] as String?;
          final agencyId = data['agencyId'] as String?;

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
                      right: 16,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            tooltip: "Sign Out",
                            onPressed: _confirmSignOut,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -45,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white10,
                          child: Text(avatar, style: const TextStyle(fontSize: 40)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text("ID: $userID", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(width: 10),
                          if (country.isNotEmpty)
                            Text(country, style: const TextStyle(color: Colors.white54, fontSize: 13)),
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
                        _sectionTitle("Achievement"),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _achievementCard("VIP", "VIP x2", Icons.workspace_premium, Colors.amber)),
                            const SizedBox(width: 10),
                            Expanded(child: _achievementCard("Active", "Novice", Icons.local_fire_department, Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle("Badge Gallery"),
                        const SizedBox(height: 10),
                        Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text("No badges yet", style: TextStyle(color: Colors.white38)),
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle("Relationship"),
                        const SizedBox(height: 10),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add, color: Colors.white38),
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
                        _hostSectionBanner(context, ownedAgencyId: ownedAgencyId, agencyId: agencyId),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _confirmSignOut,
                            icon: const Icon(Icons.logout, color: Colors.redAccent),
                            label: const Text(
                              "Sign Out",
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
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
          );
        },
      ),
    );
  }

  Widget _hostSectionBanner(BuildContext context, {required String? ownedAgencyId, required String? agencyId}) {
    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final Widget destination;

    if (ownedAgencyId != null) {
      icon = Icons.dashboard_customize_outlined;
      title = "Agency Dashboard";
      subtitle = "Apna invite code aur host requests dekhein";
      destination = const AgencyOwnerDashboard();
    } else if (agencyId != null) {
      icon = Icons.leaderboard_outlined;
      title = "Host Dashboard";
      subtitle = "Apni earnings aur activity dekhein";
      destination = const HostCenterScreen();
    } else {
      icon = Icons.mic_external_on_outlined;
      title = "Become a Host";
      subtitle = "Apni agency banayein ya kisi agency ko join karein";
      destination = const BecomeHostScreen();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white38,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const Text("View all", style: TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _achievementCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}