import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// Cloudinary config
const String _cloudinaryCloudName = 'bmdl7tkd';
const String _cloudinaryUploadPreset = 'euhkghkc';

class AgencyApplicationScreen extends StatefulWidget {
  const AgencyApplicationScreen({super.key});

  @override
  State<AgencyApplicationScreen> createState() => _AgencyApplicationScreenState();
}

class _AgencyApplicationScreenState extends State<AgencyApplicationScreen> {
  final TextEditingController agencyNameController = TextEditingController();
  final TextEditingController applicantNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  File? _selfieImage;
  File? _cnicFrontImage;
  File? _cnicBackImage;
  bool _isSubmitting = false;

  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _pickImage(void Function(File) onPicked) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => onPicked(File(picked.path)));
    }
  }

  Future<String> _uploadImageToCloudinary(File imageFile) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(resBody);
      return data['secure_url'] as String;
    } else {
      throw Exception('Cloudinary upload failed (${response.statusCode}): $resBody');
    }
  }

  Future<void> _submitApplication() async {
    final uid = user?.uid;
    if (uid == null) return;

    if (agencyNameController.text.trim().isEmpty ||
        applicantNameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        mobileController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sab fields fill karein")),
      );
      return;
    }
    if (_selfieImage == null || _cnicFrontImage == null || _cnicBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selfie aur CNIC (front + back) upload karein")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final selfieUrl = await _uploadImageToCloudinary(_selfieImage!);
      final cnicFrontUrl = await _uploadImageToCloudinary(_cnicFrontImage!);
      final cnicBackUrl = await _uploadImageToCloudinary(_cnicBackImage!);

      await FirebaseFirestore.instance.collection('agency_applications').doc(uid).set({
        'uid': uid,
        'agencyName': agencyNameController.text.trim(),
        'applicantName': applicantNameController.text.trim(),
        'address': addressController.text.trim(),
        'mobile': mobileController.text.trim(),
        'email': emailController.text.trim(),
        'selfieUrl': selfieUrl,
        'cnicFrontUrl': cnicFrontUrl,
        'cnicBackUrl': cnicBackUrl,
        'status': 'pending',
        'rejectionReason': null,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application submit ho gayi — review ka intezar karein")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submit nahi ho saka: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetForReapply(String uid) async {
    await FirebaseFirestore.instance.collection('agency_applications').doc(uid).delete();
  }

  @override
  void dispose() {
    agencyNameController.dispose();
    applicantNameController.dispose();
    addressController.dispose();
    mobileController.dispose();
    emailController.dispose();
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
            stream: FirebaseFirestore.instance.collection('agency_applications').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final status = data?['status'] as String?;

              if (status == 'pending') {
                return _statusView(
                  icon: Icons.hourglass_top,
                  color: Colors.amberAccent,
                  title: "Application Under Review",
                  subtitle: "Aapki agency application review mein hai. Approve hote hi aapko notify kar diya jayega.",
                );
              }

              if (status == 'approved') {
                return _statusView(
                  icon: Icons.verified,
                  color: Colors.greenAccent,
                  title: "Agency Approved!",
                  subtitle: "Mubarak ho — aapki agency \"${data?['agencyName'] ?? ''}\" approve ho chuki hai. Apna invite code \"My Agency\" section mein dekhein.",
                );
              }

              if (status == 'rejected') {
                final reason = data?['rejectionReason'] as String?;
                return _statusView(
                  icon: Icons.cancel,
                  color: Colors.redAccent,
                  title: "Application Rejected",
                  subtitle: reason != null && reason.isNotEmpty
                      ? "Wajah: $reason"
                      : "Aapki application reject ho gayi hai.",
                  showReapply: true,
                  onReapply: () => _resetForReapply(uid),
                );
              }

              // No application yet -> show form
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
                          "Create Agency",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        "Documents aur details submit karein — hum jald review karenge",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          _field(controller: agencyNameController, hint: "Agency Name", icon: Icons.business),
                          const SizedBox(height: 16),
                          _field(controller: applicantNameController, hint: "Your Full Name", icon: Icons.person_outline),
                          const SizedBox(height: 16),
                          _field(controller: mobileController, hint: "Mobile Number", icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 16),
                          _field(controller: emailController, hint: "Email", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _field(controller: addressController, hint: "Address", icon: Icons.location_on_outlined, maxLines: 2),
                          const SizedBox(height: 20),
                          _imagePickerBox(
                            label: "Selfie with CNIC",
                            icon: Icons.face_retouching_natural,
                            image: _selfieImage,
                            onTap: () => _pickImage((f) => _selfieImage = f),
                          ),
                          const SizedBox(height: 14),
                          _imagePickerBox(
                            label: "CNIC Front",
                            icon: Icons.badge_outlined,
                            image: _cnicFrontImage,
                            onTap: () => _pickImage((f) => _cnicFrontImage = f),
                          ),
                          const SizedBox(height: 14),
                          _imagePickerBox(
                            label: "CNIC Back",
                            icon: Icons.badge_outlined,
                            image: _cnicBackImage,
                            onTap: () => _pickImage((f) => _cnicBackImage = f),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.zero,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
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
                                    "Submit Application",
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
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

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.amberAccent),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.amberAccent),
        ),
      ),
    );
  }

  Widget _imagePickerBox({
    required String label,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            clipBehavior: Clip.antiAlias,
            child: image != null
                ? Image.file(image, fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.amberAccent, size: 30),
                      const SizedBox(height: 8),
                      Text(
                        "Tap to upload",
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _statusView({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool showReapply = false,
    VoidCallback? onReapply,
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
            if (showReapply)
              TextButton(
                onPressed: onReapply,
                child: const Text("Dobara Apply Karein", style: TextStyle(color: Colors.amberAccent)),
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