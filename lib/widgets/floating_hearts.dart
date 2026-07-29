import 'package:flutter/material.dart';

class FloatingHearts extends StatefulWidget {
  final Offset? tapPosition;

  const FloatingHearts({
    super.key,
    required this.tapPosition,
  });

  @override
  State<FloatingHearts> createState() => _FloatingHeartsState();
}

class _FloatingHeartsState extends State<FloatingHearts> {
  final List<HeartData> hearts = [];

  @override
  void didUpdateWidget(covariant FloatingHearts oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.tapPosition != null &&
        widget.tapPosition != oldWidget.tapPosition) {
      hearts.add(
        HeartData(
          key: UniqueKey(),
          position: widget.tapPosition!,
        ),
      );

      setState(() {});
    }
  }

  void removeHeart(Key key) {
    hearts.removeWhere((e) => e.key == key);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: hearts
            .map(
              (heart) => HeartAnimation(
                key: heart.key,
                startPosition: heart.position,
                onCompleted: () {
                  removeHeart(heart.key);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class HeartData {
  final Key key;
  final Offset position;

  HeartData({
    required this.key,
    required this.position,
  });
}

class HeartAnimation extends StatefulWidget {
  final Offset startPosition;
  final VoidCallback onCompleted;

  const HeartAnimation({
    super.key,
    required this.startPosition,
    required this.onCompleted,
  });

  @override
  State<HeartAnimation> createState() =>
      _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    controller.forward();

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;

        final dx = widget.startPosition.dx + (25 * t);

        final dy = widget.startPosition.dy - (220 * t);

        return Positioned(
          left: dx,
          top: dy,
          child: Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 0.8 + (0.3 * t),
              child: const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 34,
              ),
            ),
          ),
        );
      },
    );
  }
}