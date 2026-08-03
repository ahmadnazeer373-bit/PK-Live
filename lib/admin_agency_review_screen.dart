import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// IMPORTANT: replace this with your own Firebase Auth UID(s).
// Only UIDs listed here can access this screen and approve/reject agencies.
// You can find your UID in Firebase Console -> Authentication -> Users.
const List<String> adminUids = [
  "1dd7eMMAm9dp6QqOzQsr5eJXPjB2",
];

class AdminAgencyReviewScreen extends StatelessWidget {
  const AdminAgencyReviewScreen({super.key});

  bool get _isAdmin =>
      adminUids.contains(FirebaseAuth.instance.currentUser?.uid);

  Future<void> _approve(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final uid = data['uid'] as String;
    final agencyName = data['agencyName'] as String? ?? "Unnamed Agency";

    try {
      final agencyRef = FirebaseFirestore.instance.collection('agencies').doc();
      final batch = FirebaseFirestore.instance.batch();

      // Agency doc ID itself is used as the invite code — always unique.
      batch.set(agencyRef, {
        'agencyName': agencyName,
        'ownerUid': uid,
        'inviteCode': agencyRef.id,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(doc.reference, {
        'status': 'approved',
        'agencyId': agencyRef.id,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Owner is automatically also a host of their own agency.
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'agencyId': agencyRef.id,
        'ownedAgencyId': agencyRef.id,
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$agencyName approved")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approve failed: $e")),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context, DocumentSnapshot doc) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Reject Application", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Wajah (optional)",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reject", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await doc.reference.update({
        'status': 'rejected',
        'rejectionReason': reasonController.text.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Reject failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1E),
        body: Center(
          child: Text("Access Denied", style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1930),
        title: const Text("Agency Applications"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agency_applications')
            .where('status', isEqualTo: 'pending')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("No pending applications", style: TextStyle(color: Colors.white38)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['agencyName'] ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text("Applicant: ${data['applicantName'] ?? ''}",
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text("Address: ${data['address'] ?? ''}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text("Mobile: ${data['mobile'] ?? ''}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text("Email: ${data['email'] ?? ''}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _docThumb(context, "Selfie", data['selfieUrl']),
                        const SizedBox(width: 8),
                        _docThumb(context, "CNIC Front", data['cnicFrontUrl']),
                        const SizedBox(width: 8),
                        _docThumb(context, "CNIC Back", data['cnicBackUrl']),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _reject(context, doc),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Reject", style: TextStyle(color: Colors.redAccent)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approve(context, doc),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade400,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Approve", style: TextStyle(color: Colors.black)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _docThumb(BuildContext context, String label, String? url) {
    if (url == null) return const SizedBox.shrink();
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                child: Image.network(url),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
