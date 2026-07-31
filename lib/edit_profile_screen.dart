import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  int coverIndex = 0;
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
      coverIndex = data['coverIndex'] ?? 0;
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
      'coverIndex': coverIndex,
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

  void _pickAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: avatarOptions.map((emoji) {
            return GestureDetector(
              onTap: () {
                setState(() => avatar = emoji);
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
      ),
    );
  }

  void _pickCover() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: List.generate(coverOptions.length, (index) {
            final colors = coverOptions[index];
            return GestureDetector(
              onTap: () {
                setState(() => coverIndex = index);
                Navigator.pop(context);
              },
              child: Container(
                width: 70,
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                  border: coverIndex == index
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            );
          }),
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
            Stack(
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: coverOptions[coverIndex]),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 16,
                  child: GestureDetector(
                    onTap: _pickCover,
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
                Positioned(
                  bottom: -35,
                  left: 20,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF12121F),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white10,
                            child: Text(avatar, style: const TextStyle(fontSize: 34)),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
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
              ],
            ),
            const SizedBox(height: 50),
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