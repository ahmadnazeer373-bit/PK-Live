import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinAgencyScreen extends StatefulWidget {
  const JoinAgencyScreen({super.key});

  @override
  State<JoinAgencyScreen> createState() => _JoinAgencyScreenState();
}

class _JoinAgencyScreenState extends State<JoinAgencyScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _submitRequest() async {
    final uid = user?.uid;
    if (uid == null) return;

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter an invite code")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final agencyDoc = await FirebaseFirestore.instance.collection('agencies').doc(code).get();

      if (!agencyDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This invite code isn't valid")),
        );
        return;
      }

      final agencyData = agencyDoc.data() as Map<String, dynamic>;
      if (agencyData['status'] != 'active') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This agency isn't active right now")),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('host_join_requests').doc(uid).set({
        'hostUid': uid,
        'agencyId': agencyDoc.id,
        'agencyName': agencyData['agencyName'] ?? '',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request sent — waiting for the agency owner's approval")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Something went wrong while sending: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelRequest(String uid) async {
    await FirebaseFirestore.instance.collection('host_join_requests').doc(uid).delete();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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
            stream: FirebaseFirestore.instance.collection('host_join_requests').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final status = data?['status'] as String?;

              if (status == 'pending') {
                return _statusView(
                  icon: Icons.hourglass_top,
                  color: Colors.amberAccent,
                  title: "Request Pending",
                  subtitle: "Your request to join \"${data?['agencyName'] ?? ''}\" has been sent. Waiting for the owner's approval.",
                  showCancel: true,
                  onCancel: () => _cancelRequest(uid),
                );
              }

              if (status == 'approved') {
                return _statusView(
                  icon: Icons.verified,
                  color: Colors.greenAccent,
                  title: "Agency Joined!",
                  subtitle: "You're now a host of \"${data?['agencyName'] ?? ''}\" — you can Go Live now.",
                );
              }

              if (status == 'rejected') {
                return _statusView(
                  icon: Icons.cancel,
                  color: Colors.redAccent,
                  title: "Request Rejected",
                  subtitle: "Your join request was rejected. Try a different invite code.",
                  showCancel: true,
                  cancelLabel: "Try Again",
                  onCancel: () => _cancelRequest(uid),
                );
              }

              // No request yet -> show form
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
                          "Join an Agency",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        "Get an invite code from the agency owner and enter it here",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _codeController,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: "Invite Code",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.tealAccent),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.zero,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    "Send Join Request",
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _statusView({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool showCancel = false,
    String cancelLabel = "Cancel Request",
    VoidCallback? onCancel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 70),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 24),
            if (showCancel)
              TextButton(
                onPressed: onCancel,
                child: Text(cancelLabel, style: const TextStyle(color: Colors.amberAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back", style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
