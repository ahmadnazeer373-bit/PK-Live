import 'package:flutter/material.dart';

/// Reusable branded PK Live logo widget.
/// Used on Splash screen and Auth (login/signup) screens for consistency.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;

  const AppLogo({super.key, this.size = 100, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Outer glow
          if (showGlow)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.35),
                    blurRadius: size * 0.35,
                    spreadRadius: size * 0.04,
                  ),
                ],
              ),
            ),

          // Main badge - rounded squircle with gradient
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A1C71), Color(0xFF7B2FF7), Color(0xFFFF8C00)],
                stops: [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.7),
                width: size * 0.02,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle inner play-signal arcs (like a broadcast/live icon)
                Positioned(
                  top: size * 0.14,
                  child: Icon(
                    Icons.wifi_rounded,
                    color: Colors.white.withOpacity(0.35),
                    size: size * 0.26,
                  ),
                ),
                // PK monogram
                Padding(
                  padding: EdgeInsets.only(top: size * 0.08),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFFFE9B0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      "PK",
                      style: TextStyle(
                        fontSize: size * 0.36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LIVE pulse dot badge (bottom-right)
          Positioned(
            bottom: -size * 0.02,
            right: -size * 0.02,
            child: Container(
              padding: EdgeInsets.all(size * 0.045),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0B1E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
              ),
              child: Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.redAccent, Colors.deepOrange],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}