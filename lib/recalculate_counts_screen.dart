import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🛠️ ONE-TIME ADMIN TOOL
///
/// Recomputes followersCount / followingCount / friendsCount for every user
/// from the *actual* following/followers relationships in Firestore.
///
/// Why this is needed: a bug in an earlier version of the Firestore rules
/// could cause an unfollow to delete the relationship doc successfully but
/// then throw permission-denied on the very next step (the mutual-follow
/// check), which meant the followersCount/followingCount/friendsCount
/// decrement never ran. That leaves the count fields out of sync with the
/// real relationships, even though the lists themselves are now correct.
///
/// This screen walks every user, counts their real following/followers/
/// friends docs, and overwrites the three count fields to match reality.
/// Run it once after deploying the corrected rules, then it's safe to
/// remove this screen (or just stop navigating to it) — it does not need
/// to be a permanent part of the app.
///
/// Must be run while signed in as the admin account, since the recalculation
/// needs to read every user's following/followers data (only the admin uid
/// is allowed to do that under the current Firestore rules).
class RecalculateCountsScreen extends StatefulWidget {
  const RecalculateCountsScreen({super.key});

  @override
  State<RecalculateCountsScreen> createState() => _RecalculateCountsScreenState();
}

class _RecalculateCountsScreenState extends State<RecalculateCountsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isRunning = false;
  bool _isDone = false;
  int _processed = 0;
  int _total = 0;
  int _changed = 0;
  final List<String> _log = [];

  Future<void> _runRecalculation() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      setState(() => _log.add('❌ Not signed in.'));
      return;
    }

    setState(() {
      _isRunning = true;
      _isDone = false;
      _processed = 0;
      _changed = 0;
      _log.clear();
      _log.add('Starting recalculation…');
    });

    try {
      final usersSnap = await _firestore.collection('users').get();
      setState(() => _total = usersSnap.docs.length);

      for (final userDoc in usersSnap.docs) {
        final uid = userDoc.id;

        // Actual "following" ids for this user.
        final followingSnap =
            await _firestore.collection('users').doc(uid).collection('following').get();
        final followingIds = followingSnap.docs.map((d) => d.id).toSet();

        // Actual followers: anyone whose "following" subcollection contains
        // a doc with targetUserId == uid.
        final followersSnap = await _firestore
            .collectionGroup('following')
            .where('targetUserId', isEqualTo: uid)
            .get();
        final followerIds = followersSnap.docs
            .map((d) => d.reference.parent.parent?.id)
            .whereType<String>()
            .toSet();

        final friendIds = followingIds.intersection(followerIds);

        final int correctFollowing = followingIds.length;
        final int correctFollowers = followerIds.length;
        final int correctFriends = friendIds.length;

        final data = userDoc.data();
        final int currentFollowing = (data['followingCount'] is num)
            ? (data['followingCount'] as num).toInt()
            : 0;
        final int currentFollowers = (data['followersCount'] is num)
            ? (data['followersCount'] as num).toInt()
            : 0;
        final int currentFriends = (data['friendsCount'] is num)
            ? (data['friendsCount'] as num).toInt()
            : 0;

        final bool needsUpdate = currentFollowing != correctFollowing ||
            currentFollowers != correctFollowers ||
            currentFriends != correctFriends;

        if (needsUpdate) {
          await _firestore.collection('users').doc(uid).update({
            'followingCount': correctFollowing,
            'followersCount': correctFollowers,
            'friendsCount': correctFriends,
          });
          setState(() {
            _changed++;
            _log.add(
              '✔ $uid: following $currentFollowing→$correctFollowing, '
              'followers $currentFollowers→$correctFollowers, '
              'friends $currentFriends→$correctFriends',
            );
          });
        }

        setState(() => _processed++);
      }

      setState(() {
        _isDone = true;
        _log.add('Done. $_changed of $_total users had stale counts corrected.');
      });
    } catch (e) {
      setState(() => _log.add('❌ Error: $e'));
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recalculate Follow Counts')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isRunning && !_isDone)
              ElevatedButton(
                onPressed: _runRecalculation,
                child: const Text('Run Recalculation'),
              ),
            if (_isRunning) ...[
              LinearProgressIndicator(
                value: _total == 0 ? null : _processed / _total,
              ),
              const SizedBox(height: 8),
              Text('Processed $_processed / $_total users…'),
            ],
            if (_isDone) ...[
              Text('✅ Finished. $_changed of $_total users corrected.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _runRecalculation,
                child: const Text('Run Again'),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, i) => Text(
                  _log[i],
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}