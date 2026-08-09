import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<void> checkAndSeedVipLevels() async {
  final snapshot = await _firestore.collection('vip_levels').limit(1).get();

  if (snapshot.docs.isNotEmpty) {
    print("VIP Levels already exist.");
    return;
  }

  print("Creating VIP Levels...");

  final batch = _firestore.batch();

  final vipLevels = [
    _vipLevel(
      level: 1,
      coins: 500,
      reward: 20,
    ),
    _vipLevel(
      level: 2,
      coins: 1500,
      reward: 40,
    ),
    _vipLevel(
      level: 3,
      coins: 3500,
      reward: 70,
    ),
    _vipLevel(
      level: 4,
      coins: 7000,
      reward: 120,
    ),
    _vipLevel(
      level: 5,
      coins: 15000,
      reward: 180,
    ),
    _vipLevel(
      level: 6,
      coins: 30000,
      reward: 260,
    ),
    _vipLevel(
      level: 7,
      coins: 60000,
      reward: 350,
    ),
    _vipLevel(
      level: 8,
      coins: 100000,
      reward: 500,
    ),
    _vipLevel(
      level: 9,
      coins: 180000,
      reward: 700,
    ),
    _vipLevel(
      level: 10,
      coins: 300000,
      reward: 1000,
    ),
  ];
  for (final vip in vipLevels) {
    final doc = _firestore
        .collection('vip_levels')
        .doc("vip${vip['level']}");

    batch.set(doc, vip);
  }

  await batch.commit();

  print("VIP Levels Created Successfully.");
}

/// ==========================================
/// VIP DATA
/// ==========================================

Map<String, dynamic> _vipLevel({
  required int level,
  required int coins,
  required int reward,
}) {
  return {
    "level": level,
    "title": "VIP $level",

    // Coins Required
    "requiredCoins": coins,

    // Assets
    "badge": "vip${level}_badge",
    "frame": "vip${level}_frame",
    "entryEffect": "vip${level}_entry",
    "chatBubble": "vip${level}_bubble",

    // Text Color
    "nameColor": "#FFD700",

    // Reward
    "dailyReward": reward,

    // Status
    "isActive": true,

    // Benefits
    "benefits": [
      "VIP Badge",
      "Exclusive Profile Frame",
      "Special Chat Bubble",
      "VIP Entry Effect",
      "Daily Coins Reward",
    ],
      "Priority Customer Support",
      "Exclusive VIP Gifts",
      "Premium Events Access",
      "VIP Name Color",
      "More Upcoming Benefits",
    ],
  };
}