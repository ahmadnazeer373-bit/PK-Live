import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friend_list_page.dart';
import 'widgets/relationship_frame_widget.dart';
import 'widgets/relationship_label_widget.dart';

class RelationshipPage extends StatefulWidget {
  const RelationshipPage({super.key});

  @override
  State<RelationshipPage> createState() => _RelationshipPageState();
}

class _RelationshipPageState extends State<RelationshipPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  List<Map<String, dynamic>> relationships = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRelationships();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>?;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadRelationships() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('relationships')
          .orderBy('createdAt', descending: true)
          .get();

      final now = DateTime.now();
      List<Map<String, dynamic>> activeRelationships = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final expiryDate = createdAt.add(const Duration(days: 30));
          if (now.isBefore(expiryDate)) {
            activeRelationships.add({
              'id': doc.id,
              'friendId': data['friendId'] ?? '',
              'friendName': data['friendName'] ?? 'Unknown',
              'friendAvatar': data['friendAvatar'] ?? '👤',
              'friendAvatarUrl': data['friendAvatarUrl'],
              'relationshipType': data['relationshipType'] ?? '',
              'relationshipLabel': data['relationshipLabel'] ?? '',
              'relationshipEmoji': data['relationshipEmoji'] ?? '',
              'frameColor': data['frameColor'] ?? '#FF6B6B',
              'createdAt': createdAt,
              'expiryDate': expiryDate,
              'daysRemaining': expiryDate.difference(now).inDays,
            });
          }
        }
      }

      setState(() {
        relationships = activeRelationships;
      });
    } catch (e) {
      debugPrint("Error loading relationships: $e");
    }
  }

  void _openFriendList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FriendListPage(),
      ),
    ).then((_) => _loadRelationships());
  }

  Future<void> _removeRelationship(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Relationship',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove this relationship?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('relationships')
          .doc(docId)
          .delete();

      final rel = relationships.firstWhere((r) => r['id'] == docId);
      final friendId = rel['friendId'] as String?;
      if (friendId != null) {
        final friendRels = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .collection('relationships')
            .where('friendId', isEqualTo: uid)
            .get();

        for (var doc in friendRels.docs) {
          await doc.reference.delete();
        }
      }

      setState(() {
        relationships.removeWhere((rel) => rel['id'] == docId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relationship removed'),
            backgroundColor: Colors.green,
          ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = userData?['name'] ?? 'User';
    final avatar = userData?['avatar'] ?? '👤';
    final avatarUrl = userData?['avatarUrl'] as String?;
    final userID = userData?['userID'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        title: const Text(
          'Relationship',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1B1730),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.amberAccent,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ========== USER CARD ==========
                  Container(
                    padding: const EdgeInsets.all(20),
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
                          avatarUrl: avatarUrl,
                          avatar: avatar,
                          radius: 30,
                          relationshipData: null,
                          showBadge: false,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${relationships.length} relationship${relationships.length != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Build',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (userID.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $userID',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ========== RELATIONSHIPS LIST ==========
                  if (relationships.isNotEmpty) ...[
                    const Text(
                      'Your Relationships',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: relationships.length,
                        itemBuilder: (context, index) {
                          final rel = relationships[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              leading: RelationshipFrameWidget(
                                avatarUrl: rel['friendAvatarUrl'],
                                avatar: rel['friendAvatar'] ?? '👤',
                                radius: 22,
                                relationshipData: rel,
                                showBadge: true,
                              ),
                              title: Text(
                                rel['friendName'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      RelationshipLabelWidget(
                                        relationshipData: rel,
                                        fontSize: 10,
                                        showEmoji: true,
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${rel['daysRemaining']} days left',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _removeRelationship(rel['id']),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_outline,
                              color: Colors.white24,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No relationships yet',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap "Build New Relationship" to create one',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ========== BUILD NEW RELATIONSHIP BUTTON ==========
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openFriendList,
                      icon: const Icon(Icons.person_add),
                      label: const Text(
                        'Build New Relationship',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.deepPurple.withOpacity(0.4),
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