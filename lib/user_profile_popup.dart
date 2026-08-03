import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Call this to open the profile popup for a given user document.
///
/// Usage:
///   showUserProfilePopup(context, userDoc);
///
/// where `userDoc` is a QueryDocumentSnapshot / DocumentSnapshot from the
/// `users` collection (as returned by the search screen).
Future<void> showUserProfilePopup(
  BuildContext context,
  Map<String, dynamic> userData,
  String targetUid,
) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => UserProfilePopup(userData: userData, targetUid: targetUid),
  );
}

class UserProfilePopup extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String targetUid;

  const UserProfilePopup({
    super.key,
    required this.userData,
    required this.targetUid,
  });

  @override
  State<UserProfilePopup> createState() => _UserProfilePopupState();
}

class _UserProfilePopupState extends State<UserProfilePopup> {
  final _firestore = FirebaseFirestore.instance;
  final _currentUid = FirebaseAuth.instance.currentUser?.uid;

  bool _isFollowing = false;
  bool _followLoading = true;
  bool _sayHiLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (_currentUid == null) {
      setState(() => _followLoading = false);
      return;
    }
    final doc = await _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('following')
        .doc(widget.targetUid)
        .get();
    if (!mounted) return;
    setState(() {
      _isFollowing = doc.exists;
      _followLoading = false;
    });
  }

  Future<void> _toggleFollow() async {
    if (_currentUid == null) return;
    setState(() => _followLoading = true);

    final myFollowingRef = _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('following')
        .doc(widget.targetUid);
    final theirFollowerRef = _firestore
        .collection('users')
        .doc(widget.targetUid)
        .collection('followers')
        .doc(_currentUid);
    final myUserRef = _firestore.collection('users').doc(_currentUid);
    final theirUserRef = _firestore.collection('users').doc(widget.targetUid);

    final batch = _firestore.batch();

    if (_isFollowing) {
      // Unfollow
      batch.delete(myFollowingRef);
      batch.delete(theirFollowerRef);
      batch.update(myUserRef, {'followingCount': FieldValue.increment(-1)});
      batch.update(theirUserRef, {'followersCount': FieldValue.increment(-1)});
    } else {
      // Follow
      batch.set(myFollowingRef, {'timestamp': FieldValue.serverTimestamp()});
      batch.set(theirFollowerRef, {'timestamp': FieldValue.serverTimestamp()});
      batch.update(myUserRef, {'followingCount': FieldValue.increment(1)});
      batch.update(theirUserRef, {'followersCount': FieldValue.increment(1)});
    }

    try {
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _isFollowing = !_isFollowing;
        _followLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _followLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Follow failed: $e')));
    }
  }

  Future<void> _sayHi() async {
    if (_currentUid == null) return;
    setState(() => _sayHiLoading = true);

    // Same chatId pattern already used by the coin top-up inbox messages:
    // sorted "uidA_uidB"
    final ids = [_currentUid!, widget.targetUid]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    try {
      final batch = _firestore.batch();
      batch.set(messageRef, {
        'senderId': _currentUid,
        'text': '👋 Hi!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      batch.set(
        chatRef,
        {
          'participants': ids,
          'lastMessage': '👋 Hi!',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': _currentUid,
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      if (!mounted) return;
      setState(() => _sayHiLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hi sent! 👋')));

      // TODO: agar aapki app mein already ChatScreen class hai to yahan
      // Navigator.push karke us chat par navigate kar dein, e.g.:
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => ChatScreen(chatId: chatId, otherUid: widget.targetUid),
      // ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sayHiLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.userData;
    final name = (data['name'] ?? data['displayName'] ?? 'User').toString();
    final userID = (data['userID'] ?? '').toString();
    final avatarUrl = (data['avatarUrl'] ?? '').toString();
    final gender = (data['gender'] ?? '').toString().toLowerCase();
    final age = data['age']?.toString() ?? '-';
    final sendLevel =
        (data['sendLevel'] ?? data['sendingLevel'] ?? 0).toString();
    final receiveLevel =
        (data['receiveLevel'] ?? data['receivingLevel'] ?? 0).toString();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 42, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('ID: $userID',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 14),

            // Icon-pill row: gender, age, send level, receive level
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _pill(
                  gender == 'female' ? Icons.female : Icons.male,
                  gender == 'female' ? 'Female' : 'Male',
                  gender == 'female' ? Colors.pinkAccent : Colors.blueAccent,
                ),
                _pill(Icons.cake, age, Colors.orangeAccent),
                _pill(Icons.arrow_upward, 'Send $sendLevel', Colors.green),
                _pill(Icons.arrow_downward, 'Receive $receiveLevel',
                    Colors.purple),
              ],
            ),
            const SizedBox(height: 20),

            // Say Hi + Follow row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sayHiLoading ? null : _sayHi,
                    icon: _sayHiLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.waving_hand, size: 18),
                    label: const Text('Say Hi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _followLoading ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFollowing ? Colors.grey.shade300 : Colors.pink,
                      foregroundColor:
                          _isFollowing ? Colors.black87 : Colors.white,
                    ),
                    icon: _followLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            _isFollowing ? Icons.check : Icons.add,
                            size: 18,
                          ),
                    label: Text(_isFollowing ? 'Following' : 'Follow'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}