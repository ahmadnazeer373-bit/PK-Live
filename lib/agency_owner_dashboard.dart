import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyOwnerDashboard extends StatelessWidget {
  const AgencyOwnerDashboard({super.key});

  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _approveHost(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final hostUid = data['hostUid'] as String;
    final agencyId = data['agencyId'] as String;

    try {
      final batch = FirebaseFirestore.instance.batch();

      batch.update(doc.reference, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      batch.update(FirebaseFirestore.instance.collection('users').doc(hostUid), {
        'agencyId': agencyId,
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Host approve ho gaya")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approve nahi ho saka: $e")),
        );
      }
    }
  }

  Future<void> _rejectHost(BuildContext context, DocumentSnapshot doc) async {
    try {
      await doc.reference.update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Reject nahi ho saka: $e")),
        );
      }
    }
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
                  child: Text("Aapki koi active agency nahi hai", style: TextStyle(color: Colors.white38)),
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
                          "My Agency",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---------- Agency Card + Invite Code ----------
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('agencies').doc(ownedAgencyId).snapshots(),
                      builder: (context, agencySnap) {
                        final agencyData = agencySnap.data?.data() as Map<String, dynamic>?;
                        final agencyName = agencyData?['agencyName'] as String? ?? '';
                        final inviteCode = agencyData?['inviteCode'] as String? ?? ownedAgencyId;

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
                                    child: Text(
                                      agencyName,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
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
                                          const SnackBar(content: Text("Invite code copy ho gaya")),
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
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
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
                            child: Text("Koi pending request nahi", style: TextStyle(color: Colors.white38)),
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

class _StatSquare extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatSquare({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}