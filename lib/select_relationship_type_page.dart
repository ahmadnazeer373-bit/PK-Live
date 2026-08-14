import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'relationship_page.dart';
import 'widgets/relationship_frame_widget.dart';

class SelectRelationshipTypePage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendAvatar;
  final String? friendAvatarUrl;

  const SelectRelationshipTypePage({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    this.friendAvatarUrl,
  });

  @override
  State<SelectRelationshipTypePage> createState() =>
      _SelectRelationshipTypePageState();
}

class _SelectRelationshipTypePageState
    extends State<SelectRelationshipTypePage> {
  String? selectedType;
  bool isSaving = false;

  final List<Map<String, dynamic>> relationshipTypes = [
    {
      'value': 'couple',
      'label': 'Couple',
      'emoji': '💕',
      'color': '#FF6B6B',
      'frameColor': '#FF6B6B',
    },
    {
      'value': 'best_friend',
      'label': 'Best Friend',
      'emoji': '💕',
      'color': '#FF4757',
      'frameColor': '#FF4757',
    },
    {
      'value': 'bro_sis',
      'label': 'Bro/Sis',
      'emoji': '🤝',
      'color': '#3742FA',
      'frameColor': '#3742FA',
    },
    {
      'value': 'game_friend',
      'label': 'Game Friend',
      'emoji': '🎮',
      'color': '#2ED573',
      'frameColor': '#2ED573',
    },
    {
      'value': 'good_friend',
      'label': 'Good Friend',
      'emoji': '👍',
      'color': '#FFA502',
      'frameColor': '#FFA502',
    },
  ];

  Future<void> _saveRelationship() async {
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a relationship type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'You';
      final currentUserAvatar = currentUserDoc.data()?['avatar'] ?? '👤';
      final currentUserAvatarUrl =
          currentUserDoc.data()?['avatarUrl'] as String?;

      final selected = relationshipTypes.firstWhere(
        (type) => type['value'] == selectedType,
      );

      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 30));

      // Save for current user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('relationships')
          .add({
        'friendId': widget.friendId,
        'friendName': widget.friendName,
        'friendAvatar': widget.friendAvatar,
        'friendAvatarUrl': widget.friendAvatarUrl,
        'relationshipType': selectedType,
        'relationshipLabel': selected['label'],
        'relationshipEmoji': selected['emoji'],
        'frameColor': selected['frameColor'],
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': expiryDate,
      });

      // Save for friend
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.friendId)
          .collection('relationships')
          .add({
        'friendId': currentUid,
        'friendName': currentUserName,
        'friendAvatar': currentUserAvatar,
        'friendAvatarUrl': currentUserAvatarUrl,
        'relationshipType': selectedType,
        'relationshipLabel': selected['label'],
        'relationshipEmoji': selected['emoji'],
        'frameColor': selected['frameColor'],
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': expiryDate,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 You are now ${selected['label']} with ${widget.friendName}!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => RelationshipPage(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        title: const Text(
          'Choose a Relationship',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1B1730),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== FRIEND CARD WITH FRAME ==========
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.purple.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  RelationshipFrameWidget(
                    avatarUrl: widget.friendAvatarUrl,
                    avatar: widget.friendAvatar,
                    radius: 28,
                    relationshipData: null,
                    showBadge: false,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.friendName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select relationship type',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '⚠️ This relationship will expire in 30 days',
                          style: TextStyle(
                            color: Colors.orangeAccent.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Choose a relationship',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select how you want to define this relationship',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // ========== RELATIONSHIP TYPES GRID ==========
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: relationshipTypes.length,
                itemBuilder: (context, index) {
                  final type = relationshipTypes[index];
                  final isSelected = selectedType == type['value'];
                  final color = Color(int.parse(
                      type['color']?.replaceAll('#', '0xFF') ?? '0xFFFF6B6B'));

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedType = type['value'];
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withOpacity(0.3),
                                  color.withOpacity(0.1),
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                type['emoji'],
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            type['label'],
                            style: TextStyle(
                              color: isSelected ? color : Colors.white70,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'SELECTED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ========== SAVE BUTTON ==========
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveRelationship,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedType != null
                      ? Colors.deepPurple
                      : Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: selectedType != null ? 8 : 0,
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        selectedType != null
                            ? 'Save Relationship (30 days)'
                            : 'Select a Type',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}