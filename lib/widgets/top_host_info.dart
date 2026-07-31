import 'package:flutter/material.dart';

/// Premium version of TopHostInfo — Release 1.1
///
/// Public API is unchanged (userName, likes, viewers, onClose) so this file
/// is a drop-in replacement for the existing widget. Two NEW optional
/// parameters were added (isFollowing, onFollow) — both have safe defaults,
/// so existing call sites that don't pass them will keep compiling.
class TopHostInfo extends StatefulWidget {
  final String userName;
  final int likes;
  final int viewers;
  final VoidCallback onClose;

  /// Optional — defaults keep old call sites working unchanged.
  final bool isFollowing;
  final VoidCallback? onFollow;

  const TopHostInfo({
    super.key,
    required this.userName,
    required this.likes,
    required this.viewers,
    required this.onClose,
    this.isFollowing = false,
    this.onFollow,
  });

  @override
  State<TopHostInfo> createState() => _TopHostInfoState();
}

class _TopHostInfoState extends State<TopHostInfo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _liveController;
  late final Animation<double> _liveGlow;

  @override
  void initState() {
    super.initState();

    // Subtle pulsing glow behind the LIVE badge.
    _liveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _liveGlow = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _liveController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _liveController.dispose();
    super.dispose();
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    }
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return "$value";
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // LEFT: HOST CARD
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.userName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildLiveBadge(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildStatsRow(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFollowButton(),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // RIGHT: VIEWER AVATARS + CLOSE
            _buildRightSide(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6EC7), Color(0xFFFFD36E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const CircleAvatar(
        radius: 21,
        backgroundColor: Colors.black,
        backgroundImage: NetworkImage(
          "https://i.pravatar.cc/150?img=12",
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return AnimatedBuilder(
      animation: _liveGlow,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(_liveGlow.value * 0.7),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
          SizedBox(width: 4),
          Text(
            "LIVE",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatBubble(
          icon: Icons.favorite,
          iconColor: Colors.redAccent,
          label: _formatCount(widget.likes),
        ),
        const SizedBox(width: 8),
        _StatBubble(
          icon: Icons.remove_red_eye,
          iconColor: Colors.white,
          label: _formatCount(widget.viewers),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: widget.onFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: widget.isFollowing
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFF4B8B), Color(0xFFFF7A59)],
                ),
          color: widget.isFollowing ? Colors.white.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(20),
          border: widget.isFollowing
              ? Border.all(color: Colors.white.withOpacity(0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isFollowing ? Icons.check : Icons.add,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 3),
            Text(
              widget.isFollowing ? "Following" : "Follow",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSide() {
    const avatarUrls = [
      "https://i.pravatar.cc/100?img=1",
      "https://i.pravatar.cc/100?img=2",
      "https://i.pravatar.cc/100?img=3",
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18.0 * (avatarUrls.length - 1) + 30,
          height: 30,
          child: Stack(
            children: [
              for (int i = 0; i < avatarUrls.length; i++)
                Positioned(
                  left: i * 18.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage(avatarUrls[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 46),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

class _StatBubble extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatBubble({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}