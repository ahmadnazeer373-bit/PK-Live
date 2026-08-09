import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agency_application_screen.dart';
import 'join_agency_screen.dart';
import 'agency_owner_dashboard.dart';
import 'host_center_screen.dart';

class BecomeHostScreen extends StatelessWidget {
  const BecomeHostScreen({super.key});

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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0B1E), Color(0xFF2B1055), Color(0xFF7597DE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final ownedAgencyId = userData?['ownedAgencyId'] as String?;
              final agencyId = userData?['agencyId'] as String?;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "Become a Host",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        "You need to join an agency to become a live host",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (agencyId != null) ...[
                      _infoBanner(
                        icon: Icons.verified,
                        color: Colors.greenAccent,
                        text: "You're already a host with an agency — ready to Go Live!",
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (agencyId != null && ownedAgencyId == null) ...[
                      _optionCard(
                        context,
                        icon: Icons.leaderboard_outlined,
                        color: Colors.tealAccent,
                        title: "Host Dashboard",
                        subtitle: "View your earnings, coins, and activity",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HostCenterScreen()),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (ownedAgencyId != null) ...[
                      _optionCard(
                        context,
                        icon: Icons.dashboard_customize_outlined,
                        color: Colors.amberAccent,
                        title: "My Agency Dashboard",
                        subtitle: "View your invite code and approve host requests",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AgencyOwnerDashboard()),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      // 🔥 SWAPPED: Join Agency PEHLE
                      _optionCard(
                        context,
                        icon: Icons.group_add_outlined,
                        color: Colors.tealAccent,
                        title: "Join an Agency",
                        subtitle: "Enter an agency owner's invite code to become a host",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const JoinAgencyScreen()),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 🔥 SWAPPED: Create Your Own Agency BAAD MEIN
                      _optionCard(
                        context,
                        icon: Icons.business_center_outlined,
                        color: Colors.amberAccent,
                        title: "Create Your Own Agency",
                        subtitle: "Submit documents and become the owner of your own agency",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AgencyApplicationScreen()),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _infoBanner({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _optionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}