import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Host Center — dashboard hosts ke liye: earnings, quick links, aur
/// onboarding tips. Firestore field names assume kiye gaye hain
/// (users/{uid}: monthlyIncome, coins, activeDays, watchMinutes) —
/// apne actual schema ke mutabiq badal lein.
class HostCenterScreen extends StatelessWidget {
  const HostCenterScreen({super.key});

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1E),
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
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final monthlyIncome = (data?['monthlyIncome'] ?? 0).toString();
              final coins = (data?['coins'] ?? 0).toString();
              final activeDays = (data?['activeDays'] ?? 0).toString();
              final watchMinutes = (data?['watchMinutes'] ?? 0).toString();

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- Header ----------
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            "Host Center",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ---------- Quick Links ----------
                    Row(
                      children: [
                        Expanded(
                          child: _QuickLink(
                            icon: Icons.groups_rounded,
                            label: "My Agency",
                            color: const Color(0xFFFFB347),
                            onTap: () {
                              // Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyOwnerDashboard()));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickLink(
                            icon: Icons.account_balance_wallet_rounded,
                            label: "Wallet",
                            color: const Color(0xFF64D2FF),
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickLink(
                            icon: Icons.shield_outlined,
                            label: "Guidelines",
                            color: const Color(0xFFFF6B9D),
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // ---------- Earnings Card ----------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FF7), Color(0xFF3B1E7A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: Colors.purple.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("This Month's Earnings",
                                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
                                child: const Icon(Icons.monetization_on, color: Colors.deepPurple, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(monthlyIncome,
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Divider(color: Colors.white.withOpacity(0.15), height: 1),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _StatItem(label: "Coins", value: coins),
                              _StatItem(label: "Active Days", value: activeDays),
                              _StatItem(label: "Watch Time", value: "$watchMinutes min"),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ---------- Promo Banner ----------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_outlined, color: Colors.amberAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Keep hosting to unlock bigger monthly rewards",
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ---------- Host Academy ----------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Host Academy",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("See more", style: TextStyle(color: Colors.amberAccent.withOpacity(0.9), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AcademyItem(text: "Getting started as a new host"),
                    _AcademyItem(text: "Tips to grow your audience faster"),
                    _AcademyItem(text: "What makes a top-rated host"),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLink({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
        ],
      ),
    );
  }
}

class _AcademyItem extends StatelessWidget {
  final String text;

  const _AcademyItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.amberAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}