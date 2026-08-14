import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminFixScreen extends StatefulWidget {
  const AdminFixScreen({super.key});

  @override
  State<AdminFixScreen> createState() => _AdminFixScreenState();
}

class _AdminFixScreenState extends State<AdminFixScreen> {
  bool _isLoading = false;
  String _message = '';
  Color _messageColor = Colors.white;

  // 🔥 KAL WALA FIX - Data Reset + Recalculate
  Future<void> _resetAndRecalculateAll() async {
    setState(() {
      _isLoading = true;
      _message = '🔄 Resetting and recalculating all data...';
      _messageColor = Colors.amberAccent;
    });

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      int fixedCount = 0;
      int errorCount = 0;

      for (final doc in usersSnapshot.docs) {
        try {
          final userId = doc.id;
          
          // 🔥 STEP 1: Delete existing friends subcollection
          final existingFriends = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('friends')
              .get();

          for (final friendDoc in existingFriends.docs) {
            await friendDoc.reference.delete();
          }

          // 🔥 STEP 2: Get all following
          final followingSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('following')
              .get();

          // 🔥 STEP 3: Calculate mutual follows
          int mutualCount = 0;
          final List<String> friendIds = [];

          for (final followDoc in followingSnapshot.docs) {
            final targetId = followDoc.id;
            
            // Check if target also follows this user
            final reverseCheck = await FirebaseFirestore.instance
                .collection('users')
                .doc(targetId)
                .collection('following')
                .doc(userId)
                .get();

            if (reverseCheck.exists) {
              mutualCount++;
              friendIds.add(targetId);
            }
          }

          // 🔥 STEP 4: Update friendsCount
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({'friendsCount': mutualCount});

          // 🔥 STEP 5: Add new friends subcollection
          for (final friendId in friendIds) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('friends')
                .doc(friendId)
                .set({
              'friendId': friendId,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }

          fixedCount++;
        } catch (e) {
          errorCount++;
          print('Error fixing user ${doc.id}: $e');
        }
      }

      setState(() {
        _isLoading = false;
        _message = '✅ Fixed $fixedCount users! (Errors: $errorCount)';
        _messageColor = Colors.greenAccent;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '❌ Error: $e';
        _messageColor = Colors.redAccent;
      });
    }
  }

  // 🔥 Fix Single User - Kal Wala
  Future<void> _fixSingleUser(String userId) async {
    if (userId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _message = '🔄 Fixing user...';
      _messageColor = Colors.amberAccent;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) {
        setState(() {
          _isLoading = false;
          _message = '❌ User not found!';
          _messageColor = Colors.redAccent;
        });
        return;
      }

      // Delete existing friends
      final existingFriends = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      for (final friendDoc in existingFriends.docs) {
        await friendDoc.reference.delete();
      }

      // Get following
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      int mutualCount = 0;
      final List<String> friendIds = [];

      for (final followDoc in followingSnapshot.docs) {
        final targetId = followDoc.id;
        final reverseCheck = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetId)
            .collection('following')
            .doc(userId)
            .get();

        if (reverseCheck.exists) {
          mutualCount++;
          friendIds.add(targetId);
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'friendsCount': mutualCount});

      for (final friendId in friendIds) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('friends')
            .doc(friendId)
            .set({
          'friendId': friendId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _isLoading = false;
        _message = '✅ User $userId fixed! FriendsCount: $mutualCount';
        _messageColor = Colors.greenAccent;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '❌ Error: $e';
        _messageColor = Colors.redAccent;
      });
    }
  }

  // 🔥 Fix All Users - Simple (Without Reset)
  Future<void> _fixAllUsers() async {
    setState(() {
      _isLoading = true;
      _message = '🔄 Fixing users...';
      _messageColor = Colors.amberAccent;
    });

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      int fixedCount = 0;
      int errorCount = 0;

      for (final doc in usersSnapshot.docs) {
        try {
          final userId = doc.id;
          
          final followingSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('following')
              .get();

          int mutualCount = 0;
          for (final followDoc in followingSnapshot.docs) {
            final targetId = followDoc.id;
            final reverseCheck = await FirebaseFirestore.instance
                .collection('users')
                .doc(targetId)
                .collection('following')
                .doc(userId)
                .get();

            if (reverseCheck.exists) {
              mutualCount++;
            }
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({'friendsCount': mutualCount});

          fixedCount++;
        } catch (e) {
          errorCount++;
          print('Error fixing user ${doc.id}: $e');
        }
      }

      setState(() {
        _isLoading = false;
        _message = '✅ Fixed $fixedCount users! (Errors: $errorCount)';
        _messageColor = Colors.greenAccent;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '❌ Error: $e';
        _messageColor = Colors.redAccent;
      });
    }
  }

  // 🔥 View Data
  Future<void> _viewData() async {
    setState(() {
      _isLoading = true;
      _message = '📊 Loading data...';
      _messageColor = Colors.amberAccent;
    });

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      String result = '';
      int count = 0;

      for (final doc in usersSnapshot.docs) {
        if (count >= 10) break;
        final data = doc.data();
        final name = data['name'] ?? 'User';
        final friendsCount = data['friendsCount'] ?? 0;
        final followingCount = data['followingCount'] ?? 0;
        final followersCount = data['followersCount'] ?? 0;
        result += '$name: Friends=$friendsCount, Following=$followingCount, Followers=$followersCount\n';
        count++;
      }

      setState(() {
        _isLoading = false;
        _message = result.isEmpty ? 'No users found' : result;
        _messageColor = Colors.white;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '❌ Error: $e';
        _messageColor = Colors.redAccent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUid != "1dd7eMMAm9dp6QqOzQsr5eJXPjB2") {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0B1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0B1E),
          title: const Text(
            "Access Denied",
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            "You don't have permission to access this page.",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ),
      );
    }

    final TextEditingController _userIdController = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B1E),
        title: const Text(
          "Admin Fix Data",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _messageColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _messageColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _message.contains('✅') 
                        ? Icons.check_circle 
                        : _message.contains('❌') 
                            ? Icons.error 
                            : _message.contains('📊') 
                                ? Icons.insights 
                                : _message.contains('🔄') 
                                    ? Icons.sync 
                                    : Icons.info,
                    color: _messageColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message.isEmpty ? 'Ready to fix data' : _message,
                      style: TextStyle(color: _messageColor, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🔥 KAL WALA FIX BUTTON - Reset + Recalculate
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _resetAndRecalculateAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '🔥 Reset & Recalculate All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // Fix All Users
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _fixAllUsers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Fix All Users',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 20),

            // Fix Single User
            const Text(
              'Fix Single User:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter User ID',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading 
                      ? null 
                      : () => _fixSingleUser(_userIdController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Fix',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 20),

            // View Data
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _viewData,
                icon: const Icon(Icons.visibility, color: Colors.blueAccent),
                label: const Text(
                  "View Data",
                  style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.10),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const Spacer(),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 What this does:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '🔥 Reset & Recalculate - Deletes all friends & recalculates',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    '• Fix All Users - Recalculates friendsCount',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    '• Fix Single User - Fix specific user',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    '• View Data - Shows first 10 users data',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}