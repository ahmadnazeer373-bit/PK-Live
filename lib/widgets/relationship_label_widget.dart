import 'package:flutter/material.dart';
import '../relationship_helper.dart';

class RelationshipLabelWidget extends StatelessWidget {
  final Map<String, dynamic>? relationshipData;
  final double fontSize;
  final bool showEmoji;

  const RelationshipLabelWidget({
    super.key,
    this.relationshipData,
    this.fontSize = 12,
    this.showEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    if (relationshipData == null) return const SizedBox.shrink();

    final color = RelationshipHelper.parseFrameColor(
        relationshipData?['frameColor']);
    final emoji = relationshipData?['relationshipEmoji'] ?? '💕';
    final label = relationshipData?['relationshipLabel'] ?? 'Friend';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showEmoji) ...[
            Text(
              emoji,
              style: TextStyle(fontSize: fontSize),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}