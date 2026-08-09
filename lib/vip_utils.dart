import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ========== VIP LEVEL CALCULATION (SYNC) ==========
// This is the SYNC version used in build() methods (no await)
int vipLevelForCoinsSync(int totalRecharge) {
  if (totalRecharge >= 3500000) return 5;
  if (totalRecharge >= 1700000) return 4;
  if (totalRecharge >= 700000) return 3;
  if (totalRecharge >= 400000) return 2;
  if (totalRecharge >= 100000) return 1;
  return 0;
}

// ========== VIP LEVEL CALCULATION (ASYNC) ==========
// This reads from Firestore - use with await
Future<int> getVipLevelForCoins(int totalRecharge) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('vip_rules')
        .orderBy('minCoins', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      return vipLevelForCoinsSync(totalRecharge);
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final minCoins = (data['minCoins'] ?? 0) as int;
      final level = (data['level'] ?? 0) as int;
      if (totalRecharge >= minCoins) {
        return level;
      }
    }
    return 0;
  } catch (e) {
    return vipLevelForCoinsSync(totalRecharge);
  }
}

// ========== VIP LEVEL DETAILS ==========
Future<Map<String, dynamic>> getVipLevelDetails(int totalRecharge) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('vip_rules')
        .orderBy('minCoins')
        .get();

    if (snapshot.docs.isEmpty) {
      return _getDefaultLevelDetails(totalRecharge);
    }

    final rules = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'level': data['level'] ?? 0,
        'minCoins': data['minCoins'] ?? 0,
      };
    }).toList();

    int currentLevel = 0;
    int currentThreshold = 0;
    int nextLevel = 0;
    int nextThreshold = 0;

    for (int i = 0; i < rules.length; i++) {
      final rule = rules[i];
      final minCoins = rule['minCoins'] as int;
      final level = rule['level'] as int;

      if (totalRecharge >= minCoins) {
        currentLevel = level;
        currentThreshold = minCoins;
        if (i + 1 < rules.length) {
          nextLevel = rules[i + 1]['level'] as int;
          nextThreshold = rules[i + 1]['minCoins'] as int;
        } else {
          nextLevel = level;
          nextThreshold = minCoins;
        }
      }
    }

    final needed = nextThreshold - currentThreshold;
    final progress = needed > 0
        ? (totalRecharge - currentThreshold) / (nextThreshold - currentThreshold)
        : 1.0;

    return {
      'currentLevel': currentLevel,
      'nextLevel': nextLevel,
      'needed': needed > 0 ? needed : 0,
      'progress': progress.clamp(0.0, 1.0),
      'currentThreshold': currentThreshold,
      'nextThreshold': nextThreshold,
    };
  } catch (e) {
    return _getDefaultLevelDetails(totalRecharge);
  }
}

Map<String, dynamic> _getDefaultLevelDetails(int totalRecharge) {
  int currentLevel = 0;
  int currentThreshold = 0;
  int nextLevel = 0;
  int nextThreshold = 0;

  final defaultRules = [
    {'level': 1, 'minCoins': 100000},
    {'level': 2, 'minCoins': 400000},
    {'level': 3, 'minCoins': 700000},
    {'level': 4, 'minCoins': 1700000},
    {'level': 5, 'minCoins': 3500000},
  ];

  for (int i = 0; i < defaultRules.length; i++) {
    final rule = defaultRules[i];
    final minCoins = rule['minCoins'] as int;
    final level = rule['level'] as int;

    if (totalRecharge >= minCoins) {
      currentLevel = level;
      currentThreshold = minCoins;
      if (i + 1 < defaultRules.length) {
        nextLevel = defaultRules[i + 1]['level'] as int;
        nextThreshold = defaultRules[i + 1]['minCoins'] as int;
      } else {
        nextLevel = level;
        nextThreshold = minCoins;
      }
    }
  }

  final needed = nextThreshold - currentThreshold;
  final progress = needed > 0
      ? (totalRecharge - currentThreshold) / (nextThreshold - currentThreshold)
      : 1.0;

  return {
    'currentLevel': currentLevel,
    'nextLevel': nextLevel,
    'needed': needed > 0 ? needed : 0,
    'progress': progress.clamp(0.0, 1.0),
    'currentThreshold': currentThreshold,
    'nextThreshold': nextThreshold,
  };
}

// ========== VIP WIDGETS ==========

/// VIP Badge - Shows "VIP X" with gradient colors
class VipBadge extends StatelessWidget {
  final int level;
  final double fontSize;

  const VipBadge({super.key, required this.level, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: vipGradient(level),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "VIP $level",
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// VIP Avatar Frame - Wraps avatar with VIP gradient border
class VipAvatarFrame extends StatelessWidget {
  final Widget child;
  final int level;
  final double borderWidth;

  const VipAvatarFrame({
    super.key,
    required this.child,
    required this.level,
    this.borderWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return child;
    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: vipGradient(level),
      ),
      child: child,
    );
  }
}

/// VIP Gradient - Returns LinearGradient based on VIP level
LinearGradient vipGradient(int level) {
  switch (level) {
    case 1:
      return const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFFF4D03F)]);
    case 2:
      return const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFFF5F5F5)]);
    case 3:
      return const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]);
    case 4:
      return const LinearGradient(colors: [Color(0xFFE0115F), Color(0xFFFF6B9D)]);
    case 5:
      return const LinearGradient(colors: [Color(0xFF9B30FF), Color(0xFFD580FF)]);
    default:
      return const LinearGradient(colors: [Colors.grey, Colors.grey]);
  }
}

/// VIP Color - Returns primary color based on VIP level
Color vipColor(int level) {
  switch (level) {
    case 1:
      return const Color(0xFFCD7F32);
    case 2:
      return const Color(0xFFC0C0C0);
    case 3:
      return const Color(0xFFFFD700);
    case 4:
      return const Color(0xFFE0115F);
    case 5:
      return const Color(0xFF9B30FF);
    default:
      return Colors.grey;
  }
}