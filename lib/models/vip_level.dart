class VipLevel {
  final int level;
  final String title;
  final int requiredCoins;
  final int dailyReward;
  final List<String> benefits;
  final bool isActive;
  final String? badge;
  final String? frame;
  final String? entry;
  final String? bubble;

  VipLevel({
    required this.level,
    required this.title,
    required this.requiredCoins,
    this.dailyReward = 0,
    this.benefits = const [],
    this.isActive = true,
    this.badge,
    this.frame,
    this.entry,
    this.bubble,
  });

  factory VipLevel.fromMap(Map<String, dynamic> map) {
    // 🔥 FIX: String "VIP 1" ko int mein convert
    int levelValue = 0;
    final levelData = map['level'];
    if (levelData is int) {
      levelValue = levelData;
    } else if (levelData is String) {
      final numStr = levelData.replaceAll(RegExp(r'[^0-9]'), '');
      levelValue = int.tryParse(numStr) ?? 0;
    }

    return VipLevel(
      level: levelValue,
      title: map['title'] ?? map['level']?.toString() ?? 'VIP $levelValue',
      requiredCoins: (map['coins'] ?? map['requiredCoins'] ?? 0) as int,
      dailyReward: (map['dailyReward'] ?? 0) as int,
      benefits: (map['benefits'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isActive: (map['status'] ?? map['isActive'] ?? true) as bool,
      badge: map['badge']?.toString(),
      frame: map['frame']?.toString(),
      entry: map['entry']?.toString(),
      bubble: map['bubble']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'title': title,
      'coins': requiredCoins,
      'dailyReward': dailyReward,
      'benefits': benefits,
      'status': isActive,
      'badge': badge,
      'frame': frame,
      'entry': entry,
      'bubble': bubble,
    };
  }
}