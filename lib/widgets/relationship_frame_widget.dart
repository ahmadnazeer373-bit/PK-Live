import 'package:flutter/material.dart';
import '../relationship_helper.dart';

class RelationshipFrameWidget extends StatelessWidget {
  final String? avatarUrl;
  final String avatar;
  final double radius;
  final Map<String, dynamic>? relationshipData;
  final Widget? child;
  final bool showBadge;

  const RelationshipFrameWidget({
    super.key,
    this.avatarUrl,
    this.avatar = '👤',
    this.radius = 42,
    this.relationshipData,
    this.child,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasRelationship = relationshipData != null;
    final frameColor = hasRelationship
        ? RelationshipHelper.parseFrameColor(relationshipData?['frameColor'])
        : Colors.amber;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasRelationship
            ? RelationshipHelper.getFrameGradient(frameColor)
            : const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
              ),
        boxShadow: [
          hasRelationship
              ? RelationshipHelper.getFrameShadow(frameColor)
              : BoxShadow(
                  color: Colors.amber.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0E0C18),
        ),
        child: child ??
            Stack(
              children: [
                CircleAvatar(
                  radius: radius - 4,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Text(avatar, style: TextStyle(fontSize: radius))
                      : null,
                ),
                // Relationship Badge on Avatar
                if (hasRelationship && showBadge)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: frameColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            relationshipData?['relationshipEmoji'] ?? '💕',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _getShortLabel(
                                relationshipData?['relationshipLabel'] ?? ''),
                            style: TextStyle(
                              color: frameColor,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }

  String _getShortLabel(String label) {
    if (label == 'Best Friend') return 'BF';
    if (label == 'Bro/Sis') return 'BS';
    if (label == 'Game Friend') return 'GF';
    if (label == 'Good Friend') return 'Fr';
    if (label == 'Couple') return '💕';
    return label.length > 3 ? label.substring(0, 2) : label;
  }
}