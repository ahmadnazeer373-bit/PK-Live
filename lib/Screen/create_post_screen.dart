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
  // When editing an existing post, pass its id + current data in. Leave
  // these null for the normal "new post" flow.
  final String? postId;
  final String? initialCaption;
  final List<String>? initialImageUrls;

  const CreatePostScreen({
    super.key,
    this.postId,
    this.initialCaption,
    this.initialImageUrls,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final List<XFile> _pickedImages = [];
  // Images the post already had (only relevant in edit mode) — shown
  // alongside newly picked ones; user can remove them before saving.
  List<String> _existingImageUrls = [];
  bool _posting = false;
  bool _deleting = false;

  bool get _isEditing => widget.postId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialCaption != null) {
      _captionController.text = widget.initialCaption!;
    }
    _existingImageUrls = List<String>.from(widget.initialImageUrls ?? []);
  }

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
    if (_captionController.text.trim().isEmpty &&
        _pickedImages.isEmpty &&
        _existingImageUrls.isEmpty) {
      return;
    }

    setState(() => _posting = true);

    try {
      final List<String> newlyUploadedUrls = [];
      for (final img in _pickedImages) {
        final url = await _uploadToCloudinary(File(img.path));
        newlyUploadedUrls.add(url);
      }
      final allImageUrls = [..._existingImageUrls, ...newlyUploadedUrls];

      if (_isEditing) {
        // Editing an existing post — only update the fields the author can
        // change; leave likes/comments/author info untouched.
        await FirebaseFirestore.instance
            .collection('plaza_posts')
            .doc(widget.postId)
            .update({
          'caption': _captionController.text.trim(),
          'imageUrls': allImageUrls,
          'editedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Fetch current user's profile info for name/avatar/tier.
        // TODO: adjust field names below to match your existing 'users' schema
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data() ?? {};

        await FirebaseFirestore.instance.collection('plaza_posts').add({
          'userId': user.uid,
          'userName': userData['name'] ?? user.displayName ?? 'User',
          'userAvatar': userData['avatarUrl'] ?? '',
          'userAvatarEmoji': userData['avatar'] ?? '🧑',
          'userTier': userData['tag'] ?? '',
          'verified': userData['verified'] ?? false,
          'caption': _captionController.text.trim(),
          'imageUrls': allImageUrls,
          'likesCount': 0,
          'likedBy': [],
          'commentsCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 🔔 Notify friends that a new moment was posted.
        await _notifyFriendsOfNewPost(
          user.uid,
          (userData['name'] ?? user.displayName ?? 'User').toString(),
        );
      }

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

  // 🔔 Notify every mutual friend that this user just shared a new moment.
  // Only friends get pinged (not every follower) — keeps it relevant.
  // Failures here never block the post itself; they're just logged.
  Future<void> _notifyFriendsOfNewPost(String uid, String userName) async {
    try {
      final friendsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('friends')
          .get();

      if (friendsSnap.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final friendDoc in friendsSnap.docs) {
        final notifRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc(friendDoc.id)
            .collection('items')
            .doc();
        batch.set(notifRef, {
          'type': 'moment',
          'senderId': uid,
          'title': 'New Moment',
          'body': '$userName shared a new moment',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Failed to notify friends of new post: $e");
    }
  }

  Future<void> _deletePost() async {
    if (!_isEditing || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Post Delete Karein?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Ye post hamesha ke liye delete ho jayegi.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('plaza_posts')
          .doc(widget.postId)
          .delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: $e")),
        );
      }
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0518),
        elevation: 0,
        title: Text(_isEditing ? "Edit Post" : "New Post",
            style: const TextStyle(color: Colors.white)),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _deleting ? null : _deletePost,
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          TextButton(
            onPressed: _posting ? null : _submitPost,
            child: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? "Update" : "Create",
                    style: const TextStyle(
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
                ..._existingImageUrls.map(
                  (url) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _existingImageUrls.remove(url)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ..._pickedImages.map(
                  (img) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(img.path),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _pickedImages.remove(img)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
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