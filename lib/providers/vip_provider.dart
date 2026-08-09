import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vip_level.dart';
import '../services/vip_service.dart';  // 🔥 IMPORTANT - YAHAN IMPORT HAI

class VipProvider extends ChangeNotifier {
  List<VipLevel> _vipLevels = [];
  int _userVipLevel = 0;
  int _totalRecharge = 0;
  bool _isLoading = false;
  bool _isListening = false;
  String _uid = '';

  List<VipLevel> get vipLevels => _vipLevels;
  int get userVipLevel => _userVipLevel;
  int get totalRecharge => _totalRecharge;
  bool get isLoading => _isLoading;

  VipLevel? get currentVip {
    try {
      return _vipLevels.firstWhere((v) => v.level == _userVipLevel);
    } catch (e) {
      return null;
    }
  }

  VipLevel? get nextVip {
    for (final item in _vipLevels) {
      if (item.level > _userVipLevel && item.isActive) {
        return item;
      }
    }
    return null;
  }

  double get progress {
    final next = nextVip;
    if (next == null) return 1.0;

    final current = currentVip;
    final currentRequired = current != null ? current.requiredCoins : 0;
    final nextRequired = next.requiredCoins;

    if (nextRequired <= currentRequired) return 1.0;

    final progress =
        (_totalRecharge - currentRequired) / (nextRequired - currentRequired);
    return progress.clamp(0.0, 1.0);
  }

  /// 🔥 Initialize provider with user data
  Future<void> refresh({required int totalRecharge}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _totalRecharge = totalRecharge;
      _vipLevels = await VipService.instance.getVipLevels();
      _userVipLevel = await VipService.instance.calculateVipLevelFromTotalRecharge(totalRecharge);
    } catch (e) {
      print("❌ Error refreshing VIP: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🔥 Start listening to user VIP changes (real-time)
  void startListening(String uid) {
    if (_isListening) return;
    _uid = uid;
    _isListening = true;

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        final newRecharge = (data['totalRecharge'] ?? 0) as int;
        final newVip = (data['vipLevel'] ?? 0) as int;

        if (newRecharge != _totalRecharge || newVip != _userVipLevel) {
          _totalRecharge = newRecharge;
          _userVipLevel = newVip;
          notifyListeners();
          print("✅ VIP Provider updated: VIP $_userVipLevel, Recharge $_totalRecharge");
        }
      }
    }, onError: (error) {
      print("❌ VIP listener error: $error");
    });
  }

  void stopListening() {
    _isListening = false;
  }
}