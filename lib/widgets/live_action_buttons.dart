import 'package:flutter/material.dart';

/// Right-side vertical action button stack for the Live Room.
///
/// `onLike` is required (matches existing usage in live_room_screen.dart).
/// The other callbacks are optional — if you don't pass them, those
/// buttons simply won't do anything yet, so this compiles as-is.
class LiveActionButtons extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback? onGift;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  const LiveActionButtons({
    super.key,
    required this.onLike,
    this.onGift,
    this.onShare,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.card_giftcard,
          color: Colors.amber,
          onTap: onGift,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.favorite,
          color: Colors.redAccent,
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.share,
          color: Colors.white,
          onTap: onShare,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.more_vert,
          color: Colors.white,
          onTap: onMore,
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _scale = 1.0;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _scale = 0.85);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _handleTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 24,
          ),
        ),
      ),
    );
  }
}