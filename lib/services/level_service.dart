import 'package:cloud_firestore/cloud_firestore.dart';

class LevelService {
  LevelService._();
  static final LevelService instance = LevelService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get level rules for specific type (sending/receiving)
  Future<List<Map<String, dynamic>>> getLevelRules({required String type}) async {
    final snapshot = await _firestore
        .collection('level_rules')
        .where('type', isEqualTo: type)
        .orderBy('level')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'level': data['level'] ?? 0,
        'minAmount': data['minAmount'] ?? 0,
        'color': data['color'] ?? '#FFD700',
        'type': data['type'] ?? 'sending',
      };
    }).toList();
  }

  /// Calculate level based on total amount and rules
  int calculateLevel(int totalAmount, List<Map<String, dynamic>> rules) {
    int level = 1;
    for (final rule in rules) {
      if (totalAmount >= (rule['minAmount'] as int)) {
        level = rule['level'] as int;
      }
    }
    return level;
  }

  /// Get color for level
  String getLevelColor(int level, List<Map<String, dynamic>> rules) {
    for (final rule in rules) {
      if (rule['level'] == level) {
        return rule['color'] ?? '#FFD700';
      }
    }
    return '#FFD700';
  }

  /// 🔥 Auto update sending level
  Future<void> updateSendingLevel(String uid, int sentAmount) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'totalSent': FieldValue.increment(sentAmount),
      });

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final totalSent = (userDoc.data()?['totalSent'] ?? 0) as int;

      final rules = await getLevelRules(type: 'sending');
      final newLevel = calculateLevel(totalSent, rules);

      await _firestore.collection('users').doc(uid).update({
        'sendingLevel': newLevel,
      });

      print("✅ Sending level updated: $newLevel");
    } catch (e) {
      print("❌ Error updating sending level: $e");
    }
  }

  /// 🔥 Auto update receiving level
  Future<void> updateReceivingLevel(String uid, int receivedAmount) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'totalReceived': FieldValue.increment(receivedAmount),
      });

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final totalReceived = (userDoc.data()?['totalReceived'] ?? 0) as int;

      final rules = await getLevelRules(type: 'receiving');
      final newLevel = calculateLevel(totalReceived, rules);

      await _firestore.collection('users').doc(uid).update({
        'receivingLevel': newLevel,
      });

      print("✅ Receiving level updated: $newLevel");
    } catch (e) {
      print("❌ Error updating receiving level: $e");
    }
  }

  /// 🔥 Initialize user levels
  Future<void> initializeUserLevels(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final Map<String, dynamic> updates = {};

      if (!data.containsKey('totalSent')) updates['totalSent'] = 0;
      if (!data.containsKey('totalReceived')) updates['totalReceived'] = 0;
      if (!data.containsKey('sendingLevel')) updates['sendingLevel'] = 1;
      if (!data.containsKey('receivingLevel')) updates['receivingLevel'] = 1;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
        print("✅ User levels initialized");
      }
    } catch (e) {
      print("❌ Error initializing levels: $e");
    }
  }
}