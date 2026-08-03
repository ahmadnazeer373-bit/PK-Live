import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;

// Cloudinary — unsigned upload (mobile app se seedha, bina secret key ke).
// Dashboard: https://console.cloudinary.com -> Settings -> Upload ->
// Upload presets -> Add upload preset -> Signing Mode: "Unsigned".
const String _cloudinaryCloudName = "bmdl7tkd";
const String _cloudinaryUploadPreset = "euhkghkc";

const List<String> avatarOptions = [
  "🧑", "👨", "👩", "👨‍💻", "👩‍🎤", "👑",
  "🥷", "🧙", "😎", "🦁", "🐉", "🤴",
];

const List<List<Color>> coverOptions = [
  [Color(0xFF6A11CB), Color(0xFF2575FC)],
  [Color(0xFF1F1C2C), Color(0xFF928DAB)],
  [Color(0xFFDA22FF), Color(0xFF9733EE)],
  [Color(0xFF0F2027), Color(0xFF2C5364)],
  [Color(0xFF373B44), Color(0xFF4286F4)],
  [Color(0xFFEE0979), Color(0xFFFF6A00)],
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool isLoading = true;
  bool isSaving = false;

  String avatar = "🧑";
  String? avatarUrl;
  int coverIndex = 0;
  String? coverPhotoUrl;
  bool isUploadingAvatar = false;
  bool isUploadingCover = false;
  String nickname = "";
  String birthdate = "";
  String personalNote = "";
  String gender = "";
  String country = "";
  String userID = "";

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = user?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    final data = doc.data() ?? {};

    String uidBasedId = data['userID'] ?? (100000000 + (uid.hashCode.abs() % 899999999)).toString();

    if (data['userID'] == null) {
      await ref.set({'userID': uidBasedId}, SetOptions(merge: true));
    }

    setState(() {
      avatar = data['avatar'] ?? "🧑";
      avatarUrl = data['avatarUrl'] as String?;
      coverIndex = data['coverIndex'] ?? 0;
      coverPhotoUrl = data['coverPhotoUrl'] as String?;
      nickname = data['name'] ?? "";
      birthdate = data['birthdate'] ?? "";
      personalNote = data['bio'] ?? "";
      gender = data['gender'] ?? "";
      country = data['country'] ?? "";
      userID = uidBasedId;
      isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final uid = user?.uid;
    if (uid == null) return;

    setState(() => isSaving = true);

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'avatar': avatar,
      'avatarUrl': avatarUrl,
      'coverIndex': coverIndex,
      'coverPhotoUrl': coverPhotoUrl,
      'name': nickname,
      'birthdate': birthdate,
      'bio': personalNote,
      'gender': gender,
      'country': country,
      'userID': userID,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      setState(() => isSaving = false);
      Navigator.pop(context);
    }
  }

  Future<String?> _cropImage(String sourcePath, {required bool isSquare}) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressQuality: 85,
      aspectRatio: isSquare
          ? const CropAspectRatio(ratioX: 1, ratioY: 1)
          : const CropAspectRatio(ratioX: 3, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isSquare ? "Adjust Profile Photo" : "Adjust Cover Photo",
          toolbarColor: const Color(0xFF1A1A2E),
          toolbarWidgetColor: Colors.white,
          backgroundColor: const Color(0xFF12121F),
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: isSquare ? "Adjust Profile Photo" : "Adjust Cover Photo",
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
        ),
      ],
    );
    return cropped?.path;
  }

  Future<String?> _uploadToCloudinary(String filePath) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload");
      final bytes = await File(filePath).readAsBytes();
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filePath.split('/').last));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      } else {
        debugPrint("Cloudinary upload failed: ${streamedResponse.statusCode} $responseBody");
        return null;
      }
    } catch (e) {
      debugPrint("Cloudinary upload error: $e");
      return null;
    }
  }

  Future<void> _pickAvatarFromGallery() async {
    Navigator.pop(context); // bottom sheet band karein
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    if (!mounted) return;

    final croppedPath = await _cropImage(picked.path, isSquare: true);
    if (croppedPath == null) return; // user ne crop cancel kar diya

    setState(() => isUploadingAvatar = true);
    final url = await _uploadToCloudinary(croppedPath);
    if (!mounted) return;

    setState(() {
      isUploadingAvatar = false;
      if (url != null) avatarUrl = url;
    });

    if (url == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo upload failed, please try again")),
      );
    }
  }

  Future<void> _pickCoverFromGallery() async {
    Navigator.pop(context); // bottom sheet band karein
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    if (!mounted) return;

    final croppedPath = await _cropImage(picked.path, isSquare: false);
    if (croppedPath == null) return; // user ne crop cancel kar diya

    setState(() => isUploadingCover = true);
    final url = await _uploadToCloudinary(croppedPath);
    if (!mounted) return;

    setState(() {
      isUploadingCover = false;
      if (url != null) coverPhotoUrl = url;
    });

    if (url == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cover photo upload failed, please try again")),
      );
    }
  }

  void _pickAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined, color: Colors.redAccent),
              title: const Text("Choose photo from gallery", style: TextStyle(color: Colors.white)),
              onTap: _pickAvatarFromGallery,
            ),
            const Divider(color: Colors.white12),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text("Or choose an emoji avatar", style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: avatarOptions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      avatar = emoji;
                      avatarUrl = null; // emoji chunne par photo hata dein
                    });
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white10,
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _pickCover() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined, color: Colors.redAccent),
              title: const Text("Choose cover photo from gallery", style: TextStyle(color: Colors.white)),
              onTap: _pickCoverFromGallery,
            ),
            const Divider(color: Colors.white12),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text("Or choose a gradient", style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: List.generate(coverOptions.length, (index) {
                final colors = coverOptions[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      coverIndex = index;
                      coverPhotoUrl = null; // gradient chunne par photo hata dein
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 70,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(10),
                      border: coverIndex == index && coverPhotoUrl == null
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTextField(String title, String current, Function(String) onSave) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: title == "Personal Note" ? 3 : 1,
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => onSave(result));
    }
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.redAccent),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final formatted =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() => birthdate = formatted);
    }
  }

  void _pickGender() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ["Male", "Female", "Other"].map((g) {
          return ListTile(
            title: Text(g, style: const TextStyle(color: Colors.white)),
            trailing: gender == g ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () {
              setState(() => gender = g);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _settingsRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ),
            Text(
              value.isEmpty ? "Not set" : value,
              style: TextStyle(color: value.isEmpty ? Colors.white38 : Colors.white, fontSize: 15),
            ),
            if (enabled) const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right, color: Colors.white38, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        actions: [
          isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check, color: Colors.redAccent),
                  onPressed: _saveProfile,
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                children: [
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: coverPhotoUrl != null
                        ? BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(coverPhotoUrl!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : BoxDecoration(
                            gradient: LinearGradient(colors: coverOptions[coverIndex]),
                          ),
                    child: isUploadingCover
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : null,
                  ),
                  Positioned(
                    top: 10,
                    right: 16,
                    child: GestureDetector(
                      onTap: isUploadingCover ? null : _pickCover,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: isUploadingAvatar ? null : _pickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF12121F),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white10,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                        child: isUploadingAvatar
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : (avatarUrl == null
                                ? Text(avatar, style: const TextStyle(fontSize: 34))
                                : null),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _settingsRow(
                    label: "Nickname",
                    value: nickname,
                    onTap: () => _editTextField("Nickname", nickname, (v) => nickname = v),
                  ),
                  _settingsRow(
                    label: "Birthdate",
                    value: birthdate,
                    onTap: _pickBirthdate,
                  ),
                  _settingsRow(
                    label: "Personal Note",
                    value: personalNote,
                    onTap: () => _editTextField("Personal Note", personalNote, (v) => personalNote = v),
                  ),
                  const SizedBox(height: 10),
                  _settingsRow(
                    label: "User ID",
                    value: userID,
                    onTap: () {},
                    enabled: false,
                  ),
                  _settingsRow(
                    label: "Gender",
                    value: gender,
                    onTap: _pickGender,
                  ),
                  _settingsRow(
                    label: "Country/Region",
                    value: country,
                    onTap: () => _editTextField("Country/Region", country, (v) => country = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}