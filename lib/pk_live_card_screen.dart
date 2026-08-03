import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A premium virtual "PK-Live" membership card for the current user —
/// mirrors the same identity details shown below the name on the Profile
/// screen (ID, country, friends/followers/following, age, gender, send &
/// receive level, and badges), styled to match the app's dark/gold theme.
class PkLiveCardScreen extends StatelessWidget {
  const PkLiveCardScreen({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B1E),
        elevation: 0,
        title: const Text("My PK-Live Card", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1730), Color(0xFF0D0B1E)],
            stops: [0.0, 0.5],
          ),
        ),
        child: uid == null
            ? const Center(child: Text("Login required", style: TextStyle(color: Colors.white)))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final name = data['name'] ?? "User";
                  final avatar = data['avatar'] ?? "🧑";
                  final avatarUrl = data['avatarUrl'] as String?;
                  final userID = data['userID']?.toString() ?? uid;
                  final level = data['level']?.toString() ?? "1";

                  // Same fields/fallbacks used below the name on the Profile screen.
                  final country = data['country'] ?? "";
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

                  return SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          // Outer gradient "frame" — creates a glowing gold-edge
                          // border effect around the card.
                          child: Container(
                            padding: const EdgeInsets.all(1.6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.amberAccent.withOpacity(0.9),
                                  Colors.amberAccent.withOpacity(0.15),
                                  Colors.amberAccent.withOpacity(0.6),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.amberAccent.withOpacity(0.18), blurRadius: 40, spreadRadius: 2),
                                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 12)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF2E2760), Color(0xFF15122B), Color(0xFF0D0B1E)],
                                    stops: [0.0, 0.55, 1.0],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Large faint watermark icon
                                    Positioned(
                                      top: -30,
                                      right: -30,
                                      child: Icon(Icons.workspace_premium, size: 150, color: Colors.amberAccent.withOpacity(0.07)),
                                    ),
                                    // Thin diagonal shine streak for a premium
                                    // "card sheen" feel.
                                    Positioned(
                                      top: -60,
                                      left: -40,
                                      child: Transform.rotate(
                                        angle: -0.5,
                                        child: Container(
                                          width: 90,
                                          height: 340,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withOpacity(0.0),
                                                Colors.white.withOpacity(0.06),
                                                Colors.white.withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.bolt, color: Colors.amberAccent, size: 18, shadows: [
                                              Shadow(color: Colors.amberAccent, blurRadius: 8),
                                            ]),
                                            const SizedBox(width: 6),
                                            const Text(
                                              "PK-LIVE",
                                              style: TextStyle(
                                                color: Colors.amberAccent,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 3,
                                                shadows: [
                                                  Shadow(color: Colors.amberAccent, blurRadius: 10),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.amberAccent.withOpacity(0.28),
                                                    Colors.amberAccent.withOpacity(0.08),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                                                boxShadow: [
                                                  BoxShadow(color: Colors.amberAccent.withOpacity(0.2), blurRadius: 8),
                                                ],
                                              ),
                                              child: Text(
                                                "Lv.$level",
                                                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFF8C00)]),
                                                boxShadow: [
                                                  BoxShadow(color: Colors.amberAccent.withOpacity(0.4), blurRadius: 14, spreadRadius: 1),
                                                ],
                                              ),
                                              child: CircleAvatar(
                                                radius: 32,
                                                backgroundColor: const Color(0xFF1A1A2E),
                                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                                child: avatarUrl == null
                                                    ? Text(avatar, style: const TextStyle(fontSize: 28))
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 19,
                                                      fontWeight: FontWeight.bold,
                                                      shadows: [
                                                        Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                                                      ],
                                                    ),
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
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),

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
                                        const SizedBox(height: 16),

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
                                        const SizedBox(height: 14),

                                        // ---------- Badges ----------
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            _badge("Lv.1", Colors.blueAccent),
                                            _badge("New Member", Colors.pinkAccent),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Thin gold divider for a premium "card
                                        // footer" line.
                                        Container(
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.amberAccent.withOpacity(0.0),
                                                Colors.amberAccent.withOpacity(0.4),
                                                Colors.amberAccent.withOpacity(0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
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