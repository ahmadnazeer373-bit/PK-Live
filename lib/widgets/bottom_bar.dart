import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onLiveTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onLiveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(icon: Icons.home, label: "Home", index: 0),
              _navItem(icon: Icons.donut_large, label: "Status", index: 1),
              _liveItem(),
              _navItem(icon: Icons.chat_bubble_outline, label: "Messages", index: 2),
              _navItem(icon: Icons.person_outline, label: "Profile", index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveItem() {
    return GestureDetector(
      onTap: onLiveTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.redAccent, Colors.deepOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.videocam,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool selected = currentIndex == index;
    final color = selected ? Colors.redAccent : Colors.white54;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}