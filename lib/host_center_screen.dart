import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agency_owner_dashboard.dart';
import 'income_detail_screen.dart';
import 'services/level_service.dart';
import 'become_host_screen.dart';

// 🔥 PK Live Policy Content
const String pkLivePolicy = '''
PK LIVE POLICY

Last Updated: August 10, 2026

Welcome to PK Live! This policy outlines the rules, guidelines, and standards that all hosts and users must follow while using the PK Live platform.

---

1. GENERAL GUIDELINES

1.1 PK Live is a live streaming platform that allows users to host live sessions, interact with audiences, send and receive gifts, and build communities.

1.2 By using PK Live, you agree to comply with this policy, our Terms of Service, and all applicable laws and regulations.

1.3 Failure to comply with this policy may result in account suspension, permanent ban, or legal action.

---

2. HOSTING RULES

2.1 Content Standards
- All live streams must be appropriate for a general audience.
- Content that is offensive, discriminatory, or promotes violence is strictly prohibited.
- Nudity, sexually explicit content, or suggestive behavior is not allowed.
- No promotion of illegal activities, drugs, or harmful substances.

2.2 Respectful Interaction
- Hosts must treat viewers with respect and dignity.
- Bullying, harassment, or hate speech towards any individual or group is prohibited.
- Do not encourage or participate in cyberbullying.

2.3 Authenticity
- Hosts must present themselves truthfully.
- Impersonation of other users, celebrities, or organizations is prohibited.
- Do not use fake or misleading information in your profile.

---

3. GIFTING & MONETIZATION

3.1 Gifts are virtual items that users can send to hosts during live streams.

3.2 When a user sends a gift:
- 60% of the gift value goes to the receiver as "Earned Coins"
- 40% is retained by PK Live for platform maintenance and development

3.3 Gifts are non-refundable and cannot be exchanged for real currency.

3.4 All gift transactions are recorded and subject to review.

3.5 Any attempt to exploit the gifting system for fraudulent purposes will result in permanent ban and possible legal action.

---

4. EARNED COINS & LEVELS

4.1 Earned coins are virtual currency received through gifts.

4.2 Earned coins can be used for:
- Level progression
- Access to premium features
- Platform activities (where applicable)

4.3 Levels are determined by:
- Sending Level: Based on total coins sent
- Receiving Level: Based on total gifts received

4.4 Level rules are set by the admin team and may be updated periodically.

---

5. USER CONDUCT

5.1 All users must:
- Provide accurate information during registration
- Maintain the security of their account credentials
- Respect the privacy of other users
- Not share personal or sensitive information about others

5.2 Prohibited Activities:
- Spamming, flooding, or disrupting live streams
- Using automated bots or fake accounts
- Attempting to hack, disrupt, or compromise the platform
- Distributing malware, viruses, or harmful code

---

6. PRIVACY & DATA PROTECTION

6.1 PK Live collects minimal personal information to provide our services.

6.2 User data is stored securely and is not shared with third parties without consent, except as required by law.

6.3 Users have the right to:
- Access their personal data
- Request deletion of their account and data
- Opt-out of promotional communications

6.4 For more details, please refer to our Privacy Policy.

---

7. REPORTING & ENFORCEMENT

7.1 Users can report violations of this policy by:
- Using the in-app report feature
- Contacting our support team via the app

7.2 All reports are investigated promptly and confidentially.

7.3 Penalties for violations may include:
- Verbal warning
- Temporary suspension
- Permanent account ban
- Legal action (in severe cases)

---

8. POLICY UPDATES

8.1 PK Live reserves the right to update this policy at any time.

8.2 Users will be notified of significant changes via in-app notifications or email.

8.3 Continued use of the platform after policy changes constitutes acceptance of the new terms.

---

9. CONTACT US

If you have any questions, concerns, or feedback regarding this policy, please contact us through the app's support system.

Thank you for being a part of the PK Live community! 🚀
''';

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
              final coins = ((data?['coins'] ?? 0) as num).toInt();
              final totalGifts = ((data?['totalGifts'] ?? 0) as num).toInt();
              // 🔥 Earned Coins
              final earnedCoins = ((data?['earnedCoins'] ?? 0) as num).toInt();
              // 🔥 Receiving Level - direct from database
              final receivingLevel = (data?['receivingLevel'] ?? 1) as int;

              // 🔥 Check agency status
              final agencyId = data?['agencyId'] as String?;
              final ownedAgencyId = data?['ownedAgencyId'] as String?;

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
                              // 🔥 FIX: Check agency status
                              if (agencyId != null) {
                                // ✅ Host ne agency join ki hai - show agency details
                                _showHostAgencyDetails(context, agencyId);
                              } else if (ownedAgencyId != null) {
                                // ✅ User is agency owner - show owner dashboard
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AgencyOwnerDashboard()),
                                );
                              } else {
                                // ❌ No agency - show become host screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BecomeHostScreen()),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickLink(
                            icon: Icons.shield_outlined,
                            label: "PK Live Policy",
                            color: const Color(0xFFFF6B9D),
                            onTap: () {
                              _showPolicyDialog(context, "PK Live Policy", pkLivePolicy);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // ---------- Total Income Card ----------
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const IncomeDetailScreen()),
                      ),
                      child: Container(
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
                                const Text("Total Income",
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
                                Text("$totalGifts",
                                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Divider(color: Colors.white.withOpacity(0.15), height: 1),
                            const SizedBox(height: 16),
                            // 🔥 3 items in a row
                            Row(
                              children: [
                                _StatItem(label: "Coin Balance", value: "$coins"),
                                _StatItem(label: "Earned Coins", value: "$earnedCoins"),
                                _StatItem(label: "Level", value: "Lv.$receivingLevel"),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // 🔥 Progress Bar - Receiving Level progress
                            _ReceivingLevelProgress(receivingLevel: receivingLevel),
                            const SizedBox(height: 6),
                            Text(
                              "Earn more coins to reach next level",
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                            ),
                          ],
                        ),
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
                    const _AcademyItem(text: "Getting started as a new host on PK Live"),
                    const _AcademyItem(text: "Tips to grow your audience faster"),
                    const _AcademyItem(text: "What makes a top-rated host"),

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

  // 🔥 Show Policy Dialog
  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Show Host's Agency Details (Dialog)
  void _showHostAgencyDetails(BuildContext context, String agencyId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.business, color: Colors.amberAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('agencies').doc(agencyId).snapshots(),
                      builder: (context, agencySnap) {
                        final agencyData = agencySnap.data?.data() as Map<String, dynamic>?;
                        final agencyName = agencyData?['agencyName'] as String? ?? 'Agency';
                        final createdAt = agencyData?['createdAt'] as Timestamp?;
                        
                        // Calculate days
                        String days = '0 days';
                        if (createdAt != null) {
                          final diff = DateTime.now().difference(createdAt.toDate());
                          days = '${diff.inDays} days';
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agencyName,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Agency ID: $agencyId",
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _infoChip(
                                  icon: Icons.calendar_today,
                                  label: "Created $days",
                                  color: Colors.blueAccent,
                                ),
                                const SizedBox(width: 8),
                                _infoChip(
                                  icon: Icons.person,
                                  label: "Agency Manager",
                                  color: Colors.amberAccent,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Hosts Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('agencyId', isEqualTo: agencyId)
                        .snapshots(),
                    builder: (context, hostsSnap) {
                      final totalHosts = hostsSnap.data?.docs.length ?? 0;
                      return Row(
                        children: [
                          const Icon(Icons.groups, color: Colors.white54, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            "Hosts ($totalHosts)",
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      _showHostsList(context, agencyId);
                    },
                    child: Text(
                      "See all",
                      style: TextStyle(
                        color: Colors.amberAccent.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Buttons - Contact Agency & Invite Host
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showContactAgency(context, agencyId);
                      },
                      icon: const Icon(Icons.contact_mail, color: Colors.white70, size: 16),
                      label: const Text("Contact Agency", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Get invite code
                        FirebaseFirestore.instance.collection('agencies').doc(agencyId).get().then((doc) {
                          final inviteCode = doc.data()?['inviteCode'] as String? ?? agencyId;
                          Clipboard.setData(ClipboardData(text: inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invite code copied!")),
                          );
                        });
                      },
                      icon: const Icon(Icons.person_add_alt, color: Colors.white70, size: 16),
                      label: const Text("Invite Host", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Close Button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Colors.amberAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 Helper: Info Chip
  Widget _infoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // 🔥 Show Hosts List
  void _showHostsList(BuildContext context, String agencyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Hosts List",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('agencyId', isEqualTo: agencyId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text("No hosts in this agency", style: TextStyle(color: Colors.white38)),
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown';
                  final avatar = data['avatar'] ?? '🧑';
                  return ListTile(
                    leading: Text(avatar, style: const TextStyle(fontSize: 24)),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      "ID: ${data['userID'] ?? 'N/A'}",
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
  }

  // 🔥 Show Contact Agency
  void _showContactAgency(BuildContext context, String agencyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Contact Agency",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('agencies').doc(agencyId).snapshots(),
              builder: (context, agencySnap) {
                final agencyData = agencySnap.data?.data() as Map<String, dynamic>?;
                final agencyName = agencyData?['agencyName'] as String? ?? 'Agency';
                return Text(
                  "Agency: $agencyName",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              "Contact options will be available here.",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              "Email: support@pklive.com\nPhone: +92 300 1234567",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
  }
}

// 🔥 Receiving Level Progress Widget
class _ReceivingLevelProgress extends StatelessWidget {
  final int receivingLevel;

  const _ReceivingLevelProgress({required this.receivingLevel});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LevelService.instance.getLevelRules(type: 'receiving'),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
            ),
          );
        }

        final rules = snapshot.data!;
        rules.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));

        Map<String, dynamic>? currentRule;
        Map<String, dynamic>? nextRule;

        for (int i = 0; i < rules.length; i++) {
          final rule = rules[i];
          if (rule['level'] == receivingLevel) {
            currentRule = rule;
            if (i + 1 < rules.length) {
              nextRule = rules[i + 1];
            }
            break;
          }
        }

        if (currentRule == null && rules.isNotEmpty) {
          currentRule = rules.first;
          if (rules.length > 1) {
            nextRule = rules[1];
          }
        }

        if (nextRule == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "🌟 Max Level Reached!",
                style: TextStyle(color: Colors.amberAccent.withOpacity(0.9), fontSize: 11),
              ),
            ],
          );
        }

        final currentThreshold = (currentRule?['minCoins'] ?? 0) as int;
        final nextThreshold = (nextRule['minCoins'] ?? 0) as int;
        final needed = nextThreshold - currentThreshold;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: 0,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Level $receivingLevel → Level ${nextRule['level']} (${needed} coins needed)",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
            ),
          ],
        );
      },
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
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
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