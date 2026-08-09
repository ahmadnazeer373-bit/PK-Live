import 'package:flutter/material.dart';

class VipProgressBar extends StatelessWidget {
  final double progress;

  const VipProgressBar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xff2A2D3E),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 700,
                    ),
                    curve: Curves.easeInOut,
                    width: constraints.maxWidth * value,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xffFFD54F),
                          Color(0xffFFC107),
                          Color(0xffFF9800),
                        ],
                      ),
                    ),
                  );
                },
              ),

              Center(
                child: Text(
                  "${(value * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            _buildPoint(
              title: "Current",
              icon: Icons.workspace_premium,
            ),
            _buildPoint(
              title: "Upgrade",
              icon: Icons.trending_up,
            ),
            _buildPoint(
              title: "Next VIP",
              icon: Icons.emoji_events,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPoint({
    required String title,
    required IconData icon,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.amber,
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}