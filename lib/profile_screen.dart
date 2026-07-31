import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0; // 0 = About me, 1 = Moment

  User? get user => FirebaseAuth.instance.currentUser;

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