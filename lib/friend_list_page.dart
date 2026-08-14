import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_relationship_type_page.dart';
import 'relationship_helper.dart';
import 'widgets/relationship_frame_widget.dart';

class FriendListPage extends StatefulWidget {
  const FriendListPage({super.key});

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  List<Map<String, dynamic>> allFriends = [];
  List<Map<String, dynamic>> filteredFriends = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  String errorMessage = '';
  final RelationshipHelper _relationshipHelper = RelationshipHelper();

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      print('🔍 Current User UID: $currentUid');

      if (currentUid == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'User not logged in';
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      print('📊 Total users found: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No users found in database';
        });
        return;
      }

      List<Map<String, dynamic>> friendsList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final uid = doc.id;
        final name = data['name'] ?? 'Unknown';

        print('👤 User: $uid - $name');

        if (uid == currentUid) {
          print('⏭️ Skipping current user: $uid');
          continue;
        }

        try {
          final relCheck = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .collection('relationships')
              .where('friendId', isEqualTo: uid)
              .get();

          if (relCheck.docs.isNotEmpty) {
            print('⏭️ Already in relationship with: $uid');
            continue;
          }
        } catch (e) {
          print('⚠️ Could not check relationship for $uid: $e');
        }

        friendsList.add({
          'id': uid,
          'name': name,
          'avatar': data['avatar'] ?? '👤',
          'avatarUrl': data['avatarUrl'] as String?,
        });
      }

      print('✅ Friends loaded: ${friendsList.length}');

      setState(() {
        allFriends = friendsList;
        filteredFriends = friendsList;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading friends: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e';
      });
    }
  }

  void filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredFriends = allFriends;
      } else {
        filteredFriends = allFriends
            .where((friend) => friend['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectFriend(Map<String, dynamic> friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectRelationshipTypePage(
          friendId: friend['id'],
          friendName: friend['name'],
          friendAvatar: friend['avatar'],
          friendAvatarUrl: friend['avatarUrl'],
        ),
      ),
    ).then((_) {
      _loadFriends();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        title: const Text(
          'Select Friend',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1B1730),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ========== SEARCH BAR ==========
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              onChanged: filterFriends,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // ========== FRIEND LIST ==========
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.amberAccent,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading friends...',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.orangeAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _loadFriends,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredFriends.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  color: Colors.white24,
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchController.text.isEmpty
                                      ? 'No friends available'
                                      : 'No friends found',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 16,
                                  ),
                                ),
                                if (searchController.text.isEmpty)
                                  const Text(
                                    'Add friends to build relationships',
                                    style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 14,
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                if (searchController.text.isEmpty)
                                  ElevatedButton.icon(
                                    onPressed: _loadFriends,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Refresh'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = filteredFriends[index];
                              final name = friend['name'] ?? 'Unknown';
                              final avatar = friend['avatar'] ?? '👤';
                              final avatarUrl = friend['avatarUrl'] as String?;

                              return FutureBuilder<Map<String, dynamic>?>(
                                future: _relationshipHelper
                                    .getRelationship(friend['id']),
                                builder: (context, relationshipSnapshot) {
                                  final relationshipData =
                                      relationshipSnapshot.data;
                                  return ListTile(
                                    leading: RelationshipFrameWidget(
                                      avatarUrl: avatarUrl,
                                      avatar: avatar,
                                      radius: 22,
                                      relationshipData: relationshipData,
                                      showBadge: true,
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: relationshipData != null
                                        ? Text(
                                            '${relationshipData['relationshipEmoji']} ${relationshipData['relationshipLabel']}',
                                            style: TextStyle(
                                              color: RelationshipHelper
                                                  .parseFrameColor(
                                                relationshipData[
                                                    'frameColor'],
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        : null,
                                    trailing: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple
                                            .withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.deepPurple,
                                        size: 14,
                                      ),
                                    ),
                                    onTap: () => _selectFriend(friend),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}