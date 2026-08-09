import 'package:flutter/material.dart';

import '../models/vip_level.dart';

class VipLevelItem extends StatelessWidget {
  final VipLevel vip;
  final bool isUnlocked;
  final bool isCurrent;

  const VipLevelItem({
    super.key,
    required this.vip,
    required this.isUnlocked,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isCurrent
            ? const Color(0xff3B2C00)
            : const Color(0xff1B1D2A),
        border: Border.all(
          color: isCurrent
              ? Colors.amber
              : Colors.white10,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(.30),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),

      child: Row(
        children: [

          /// VIP ICON
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? Colors.amber
                  : Colors.grey.shade700,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked
                  ? Icons.workspace_premium
                  : Icons.lock,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          /// INFO
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Row(
                  children: [

                    Text(
                      vip.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(width: 8),

                    if (isCurrent)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "CURRENT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  "Required Coins : ${vip.requiredCoins}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Daily Reward : ${vip.dailyReward} Coins",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "${vip.benefits.length} VIP Benefits",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          /// STATUS
          Column(
            children: [

              Icon(
                isUnlocked
                    ? Icons.lock_open
                    : Icons.lock,
                color: isUnlocked
                    ? Colors.green
                    : Colors.redAccent,
              ),

              const SizedBox(height: 8),

              Text(
                isUnlocked
                    ? "Unlocked"
                    : "Locked",
                style: TextStyle(
                  color: isUnlocked
                      ? Colors.green
                      : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}