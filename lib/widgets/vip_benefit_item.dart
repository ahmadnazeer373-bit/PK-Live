import 'package:flutter/material.dart';

class VipBenefitItem extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;

  const VipBenefitItem({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1B1D2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.amber.withOpacity(.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon ?? Icons.workspace_premium,
              color: iconColor ?? Colors.amber,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
            size: 22,
          ),
        ],
      ),
    );
  }
}