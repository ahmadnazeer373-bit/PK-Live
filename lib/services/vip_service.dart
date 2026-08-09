import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vip_level.dart';

class VipService {
  VipService._();
  static final VipService instance = VipService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vipCollection =>
      _firestore.collection('vip_levels');

  Future<List<VipLevel>> getVipLevels() async {
    final snapshot = await _vipCollection.orderBy('level').get();
    return snapshot.docs
        .map((doc) => VipLevel.fromMap(doc.data()))
        .toList();
  }

  Stream<List<VipLevel>> vipLevelsStream() {
    return _vipCollection.orderBy('level').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => VipLevel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<VipLevel?> getVipLevel(int level) async {
    final doc = await _vipCollection.doc("vip$level").get();
    if (!doc.exists) return null;
    return VipLevel.fromMap(doc.data()!);
  }

  Future<int> calculateVipLevelFromTotalRecharge(int totalRecharge) async {
    final levels = await getVipLevels();
    int vip = 0;
    for (final item in levels) {
      if (!item.isActive) continue;
      if (totalRecharge >= item.requiredCoins) {
        vip = item.level;
      }
    }
    return vip;
  }

  Future<VipLevel?> getNextVip(int currentVip) async {
    final levels = await getVipLevels();
    for (final item in levels) {
      if (item.level > currentVip && item.isActive) {
        return item;
      }
    }
    return null;
  }

  double calculateProgress({
    required int totalRecharge,
    required int currentRequired,
    required int nextRequired,
  }) {
    if (nextRequired <= currentRequired) return 1;
    final progress = (totalRecharge - currentRequired) / (nextRequired - currentRequired);
    return progress.clamp(0.0, 1.0);
  }

  Future<void> updateVipLevel({required VipLevel vip}) async {
    await _vipCollection.doc("vip${vip.level}").update(vip.toMap());
  }

  Future<void> setVipStatus({required int level, required bool isActive}) async {
    await _vipCollection.doc("vip$level").update({"isActive": isActive});
  }

  Future<void> updateUserVip({required String uid, required int vipLevel}) async {
    await _firestore.collection("users").doc(uid).update({"vipLevel": vipLevel});
  }

  Future<void> updateRecharge({required String uid, required int totalRecharge}) async {
    final vip = await calculateVipLevelFromTotalRecharge(totalRecharge);
    await _firestore.collection("users").doc(uid).update({
      "totalRecharge": totalRecharge,
      "vipLevel": vip,
    });
  }

  /// 🔥 AUTO UPDATE VIP LEVEL - With Debug Logs
  Future<void> autoUpdateVipLevel(String uid) async {
    try {
      print("🚀 Starting autoUpdateVipLevel for: $uid");
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        print("❌ User not found: $uid");
        return;
      }

      final userData = userDoc.data() ?? {};
      final totalCoins = (userData['coins'] ?? 0) as int;
      final currentVip = (userData['vipLevel'] ?? 0) as int;
      
      print("📊 User: totalCoins=$totalCoins, currentVip=$currentVip");

      final levels = await getVipLevels();
      if (levels.isEmpty) {
        print("❌ No VIP levels found");
        return;
      }
      
      print("📋 VIP levels count: ${levels.length}");
      
      // 🔥 DEBUG: Print all VIP levels
      for (final level in levels) {
        print("🔍 VIP: ${level.level}, required: ${level.requiredCoins}, active: ${level.isActive}");
      }

      int newVipLevel = 0;
      for (final level in levels) {
        if (!level.isActive) continue;
        if (totalCoins >= level.requiredCoins) {
          newVipLevel = level.level;
          print("✅ New VIP level set to: $newVipLevel (required: ${level.requiredCoins})");
        }
      }

      if (newVipLevel != currentVip) {
        await _firestore.collection('users').doc(uid).update({
          'vipLevel': newVipLevel,
          'totalRecharge': totalCoins,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print("✅ VIP Level auto-updated: $currentVip → $newVipLevel");
      } else {
        print("ℹ️ VIP level unchanged: $currentVip");
      }
    } catch (e) {
      print("❌ Error auto-updating VIP: $e");
    }
  }
}