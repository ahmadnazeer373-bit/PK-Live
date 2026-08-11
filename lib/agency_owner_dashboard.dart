import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyOwnerDashboard extends StatefulWidget {
  const AgencyOwnerDashboard({super.key});

  @override
  State<AgencyOwnerDashboard> createState() => _AgencyOwnerDashboardState();
}

class _AgencyOwnerDashboardState extends State<AgencyOwnerDashboard> {
  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _approveHost(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final hostUid = data['hostUid'] as String;
    final agencyId = data['agencyId'] as String;

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(doc.reference, {'status': 'approved', 'reviewedAt': FieldValue.serverTimestamp()});
      batch.update(FirebaseFirestore.instance.collection('users').doc(hostUid), {'agencyId': agencyId});
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Host approved")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Approve failed: $e")));
      }
    }
  }

  Future<void> _rejectHost(BuildContext context, DocumentSnapshot doc) async {
    try {
      await doc.reference.update({'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reject failed: $e")));
      }
    }
  }

  Future<void> _editAgencyName(String agencyId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Agency Name", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Agency Name", hintStyle: TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save", style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await FirebaseFirestore.instance.collection('agencies').doc(agencyId).update({'agencyName': newName});
    }
  }

  // 🔥 Calculate days since creation
  String _getDaysSince(Timestamp? createdAt) {
    if (createdAt == null) return '0 days';
    final created = createdAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(created);
    return '${difference.inDays} days';
  }

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
            builder: (context, userSnap) {
              final ownedAgencyId = (userSnap.data?.data() as Map<String, dynamic>?)?['ownedAgencyId'] as String?;

              if (ownedAgencyId == null) {
                return const Center(
                  child: Text("You don't have an active agency", style: TextStyle(color: Colors.white38)),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
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
                          "Agency Center",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---------- Agency Card (Updated) ----------
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('agencies').doc(ownedAgencyId).snapshots(),
                      builder: (context, agencySnap) {
                        final agencyData = agencySnap.data?.data() as Map<String, dynamic>?;
                        final agencyName = agencyData?['agencyName'] as String? ?? '';
                        final inviteCode = agencyData?['inviteCode'] as String? ?? ownedAgencyId;
                        final createdAt = agencyData?['createdAt'] as Timestamp?;
                        final ownerUid = agencyData?['ownerUid'] as String?;

                        // 🔥 Get days since creation
                        final daysSince = _getDaysSince(createdAt);

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.04)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔥 Agency Header - Name & ID
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          agencyName,
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "Agency ID: $ownedAgencyId",
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 🔥 Agency Info Row - Created & Manager
                              Row(
                                children: [
                                  _infoChip(
                                    icon: Icons.calendar_today,
                                    label: "Created $daysSince",
                                    color: Colors.blueAccent,
                                  ),
                                  const SizedBox(width: 10),
                                  _infoChip(
                                    icon: Icons.person,
                                    label: "Agency Manager",
                                    color: Colors.amberAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 🔥 Hosts Count with "See All"
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .where('agencyId', isEqualTo: ownedAgencyId)
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
                                      // 🔥 Show all hosts list
                                      _showHostsList(context, ownedAgencyId);
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

                              // 🔥 Action Buttons - Contact Agency & Invite Host
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        // 🔥 Contact Agency - Show contact info
                                        _showContactAgency(context, agencyName, ownerUid);
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
                                        Clipboard.setData(ClipboardData(text: inviteCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Invite code copied! Share it with hosts.")),
                                        );
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

                              // 🔥 Invite Code
                              const Text("Invite Code", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        inviteCode,
                                        style: const TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.copy, color: Colors.white70),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: inviteCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Invite code copied")),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // ---------- Team Income Card ----------
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('agencyId', isEqualTo: ownedAgencyId)
                          .snapshots(),
                      builder: (context, hostsSnap) {
                        final hostDocs = hostsSnap.data?.docs ?? [];
                        final hostUids = hostDocs.map((d) => d.id).toList();
                        final now = DateTime.now();
                        final monthStart = DateTime(now.year, now.month, 1);

                        return StreamBuilder<QuerySnapshot>(
                          stream: hostUids.isEmpty
                              ? const Stream.empty()
                              : FirebaseFirestore.instance
                                  .collection('gift_transactions')
                                  .where('receiverUid', whereIn: hostUids.take(30).toList())
                                  .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
                                  .snapshots(),
                          builder: (context, txnSnap) {
                            final teamIncome = (txnSnap.data?.docs ?? [])
                                .fold<int>(0, (sum, d) => sum + ((d.get('coinPrice') as num).toInt()));

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF2E7BFF), Color(0xFF6A5CFF)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Team Income (This Month)",
                                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                                      const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 20),
                                      const SizedBox(width: 6),
                                      Text("$teamIncome",
                                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: _MiniInfo(label: "Commission", value: "Not set"),
                                      ),
                                      Expanded(
                                        child: _MiniInfo(label: "Invite Bonus", value: "Not set"),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Text(
                                      "Commission % and Invite Bonus rules are still being finalized",
                                      style: TextStyle(color: Colors.white54, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ---------- Host Stats ----------
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('agencyId', isEqualTo: ownedAgencyId)
                          .snapshots(),
                      builder: (context, hostsSnap) {
                        final hostDocs = hostsSnap.data?.docs ?? [];
                        final totalHosts = hostDocs.length;

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('host_join_requests')
                              .where('agencyId', isEqualTo: ownedAgencyId)
                              .where('status', isEqualTo: 'approved')
                              .snapshots(),
                          builder: (context, reqSnap) {
                            final approvedDocs = reqSnap.data?.docs ?? [];
                            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                            final newHosts = approvedDocs.where((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final reviewedAt = data['reviewedAt'];
                              if (reviewedAt is Timestamp) {
                                return reviewedAt.toDate().isAfter(weekAgo);
                              }
                              return false;
                            }).length;

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('host_join_requests')
                                  .where('agencyId', isEqualTo: ownedAgencyId)
                                  .where('status', isEqualTo: 'pending')
                                  .snapshots(),
                              builder: (context, pendingSnap) {
                                final pendingCount = pendingSnap.data?.docs.length ?? 0;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.groups_2_outlined, color: Colors.white70, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Total Hosts: $totalHosts",
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatSquare(
                                            icon: Icons.verified_user_outlined,
                                            iconColor: Colors.greenAccent,
                                            value: '$totalHosts',
                                            label: 'Active Hosts',
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _StatSquare(
                                            icon: Icons.fiber_new_outlined,
                                            iconColor: Colors.amberAccent,
                                            value: '$newHosts',
                                            label: 'New This Week',
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _StatSquare(
                                            icon: Icons.hourglass_top_outlined,
                                            iconColor: Colors.orangeAccent,
                                            value: '$pendingCount',
                                            label: 'Pending',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // ---------- Invite Host / Host Apply ----------
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Copy the invite code above and send it to hosts")),
                              );
                            },
                            icon: const Icon(Icons.person_add_alt, size: 18),
                            label: const Text("Invite Host"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Pending requests are in the list below")),
                              );
                            },
                            icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                            label: const Text("Host Apply"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),
                    const Text("Pending Host Requests", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('host_join_requests')
                          .where('agencyId', isEqualTo: ownedAgencyId)
                          .where('status', isEqualTo: 'pending')
                          .orderBy('requestedAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text("No pending requests", style: TextStyle(color: Colors.white38)),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final hostUid = data['hostUid'] as String? ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    child: const Icon(Icons.person_outline, color: Colors.white70, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('users').doc(hostUid).get(),
                                      builder: (context, hostSnap) {
                                        final hostData = hostSnap.data?.data() as Map<String, dynamic>?;
                                        final hostName = hostData?['name'] as String? ?? hostUid;
                                        return Text(hostName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600));
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.redAccent),
                                    onPressed: () => _rejectHost(context, doc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                                    onPressed: () => _approveHost(context, doc),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 26),

                    // ---------- Agency Academy ----------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Agency Academy", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("See more", style: TextStyle(color: Colors.amberAccent.withOpacity(0.9), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _AcademyItem(text: "How to recruit hosts?"),
                    const _AcademyItem(text: "How to train hosts?"),
                    const _AcademyItem(text: "How to build good relationships with supporters?"),
                    const _AcademyItem(text: "How to build agency organizational structure"),

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

  // 🔥 Show Hosts List Dialog
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

  // 🔥 Show Contact Agency Dialog
  void _showContactAgency(BuildContext context, String agencyName, String? ownerUid) {
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
            Text(
              "Agency: $agencyName",
              style: const TextStyle(color: Colors.white, fontSize: 16),
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

// 🔥 Info Chip Widget
class _infoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _infoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _StatSquare extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatSquare({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
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