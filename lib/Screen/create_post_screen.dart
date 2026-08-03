import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Requires these packages in pubspec.yaml (add if not already present):
//   image_picker: ^1.0.7
//   http: ^1.2.2

// ===== FILL THESE IN FROM YOUR CLOUDINARY DASHBOARD =====
const String _cloudinaryCloudName = "bmdl7tkd";
const String _cloudinaryUploadPreset = "euhkghkc";
// =========================================================

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final List<XFile> _pickedImages = [];
  bool _posting = false;

  Future<void> _pickImages() async {
    final images = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      setState(() => _pickedImages.addAll(images));
    }
  }

  // Uploads a single image to Cloudinary using an unsigned upload preset
  // and returns the hosted secure_url.
  Future<String> _uploadToCloudinary(File file) async {
    final uri = Uri.parse(
      "https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload",
    );

    final request = http.MultipartRequest("POST", uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception("Cloudinary upload failed: $resBody");
    }

    final data = jsonDecode(resBody) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  Future<void> _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _posting) return;
    if (_captionController.text.trim().isEmpty && _pickedImages.isEmpty) {
      return;
    }

    setState(() => _posting = true);

    try {
      // Fetch current user's profile info for name/avatar/tier.
      // TODO: adjust field names below to match your existing 'users' schema
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      final List<String> imageUrls = [];
      for (final img in _pickedImages) {
        final url = await _uploadToCloudinary(File(img.path));
        imageUrls.add(url);
      }

      await FirebaseFirestore.instance.collection('plaza_posts').add({
        'userId': user.uid,
        'userName': userData['name'] ?? user.displayName ?? 'User',
        'userAvatar': userData['avatarUrl'] ?? '',
        'userAvatarEmoji': userData['avatar'] ?? '🧑',
        'userTier': userData['tag'] ?? '',
        'verified': userData['verified'] ?? false,
        'caption': _captionController.text.trim(),
        'imageUrls': imageUrls,
        'likesCount': 0,
        'likedBy': [],
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0518),
        elevation: 0,
        title: const Text("New Post", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _posting ? null : _submitPost,
            child: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Post",
                    style: TextStyle(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Share something with Plaza...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._pickedImages.map(
                  (img) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(img.path),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_photo_alternate,
                        color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}