import 'package:flutter/material.dart';

/// Lifetime-spending thresholds (in coins) for VIP levels 1–20.
/// A user's VIP level is the highest level whose threshold their
/// lifetime spend (users/{uid}.totalSent) has reached or passed.
/// Level 0 means "not VIP yet" (below the level-1 threshold).
const List<int> vipThresholds = [
  150000, // VIP 1
  230000, // VIP 2
  350000, // VIP 3
  550000, // VIP 4
  850000, // VIP 5
  1300000, // VIP 6
  2000000, // VIP 7
  3000000, // VIP 8
  4500000, // VIP 9
  7000000, // VIP 10
  11000000, // VIP 11
  17000000, // VIP 12
  26000000, // VIP 13
  40000000, // VIP 14
  60000000, // VIP 15
  90000000, // VIP 16
  140000000, // VIP 17
  210000000, // VIP 18
  320000000, // VIP 19
  500000000, // VIP 20
];

/// Returns the VIP level (0–20) for a given lifetime coin spend.
/// 0 means the user hasn't reached VIP 1 yet.
int vipLevelForSpend(int totalSent) {
  int level = 0;
  for (int i = 0; i < vipThresholds.length; i++) {
    if (totalSent >= vipThresholds[i]) {
      level = i + 1;
    } else {
      break;
    }
  }
  return level;
}

/// How many coins still needed to reach the next VIP level.
/// Returns null if already at the max level (VIP 20).
int? coinsToNextVipLevel(int totalSent) {
  final level = vipLevelForSpend(totalSent);
  if (level >= vipThresholds.length) return null;
  return vipThresholds[level] - totalSent;
}

/// Display label, e.g. "VIP 7". Empty string if level is 0.
String vipLabel(int level) => level > 0 ? "VIP $level" : "";

/// Tiered color scheme so higher levels visually stand out more:
/// 1–5 bronze, 6–10 silver, 11–15 gold, 16–20 diamond/red.
Color vipColor(int level) {
  if (level >= 16) return const Color(0xFFFF3B5C); // Diamond/red
  if (level >= 11) return const Color(0xFFFFD700); // Gold
  if (level >= 6) return const Color(0xFFC0C0C0); // Silver
  if (level >= 1) return const Color(0xFFCD7F32); // Bronze
  return Colors.white54;
}

/// Small gradient background to pair with [vipColor] on badges/frames.
List<Color> vipGradient(int level) {
  if (level >= 16) return const [Color(0xFFFF3B5C), Color(0xFF7B2FF7)];
  if (level >= 11) return const [Color(0xFFFFD700), Color(0xFFFF8C00)];
  if (level >= 6) return const [Color(0xFFE0E0E0), Color(0xFF9E9E9E)];
  if (level >= 1) return const [Color(0xFFCD7F32), Color(0xFF8B4513)];
  return const [Colors.transparent, Colors.transparent];
}

/// Small pill badge showing "VIP N" — used in chat, seats, profile popups.
/// Renders nothing (SizedBox.shrink) for level 0 so call sites can drop
/// it in unconditionally.
class VipBadge extends StatelessWidget {
  final int level;
  final double fontSize;
  const VipBadge({super.key, required this.level, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: vipGradient(level)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        vipLabel(level),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Decorative ring/frame to wrap around an avatar for VIP users. Renders
/// the [child] unchanged for level 0.
class VipAvatarFrame extends StatelessWidget {
  final int level;
  final Widget child;
  final double borderWidth;
  const VipAvatarFrame({super.key, required this.level, required this.child, this.borderWidth = 2.5});

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return child;
    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: vipGradient(level)),
      ),
      child: child,
    );
  }
}