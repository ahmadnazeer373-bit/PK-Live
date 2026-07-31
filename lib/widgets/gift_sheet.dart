import 'package:flutter/material.dart';

class GiftItem {
  final String emoji;
  final String name;
  final int coins;

  const GiftItem({
    required this.emoji,
    required this.name,
    required this.coins,
  });
}

const List<GiftItem> kGifts = [
  GiftItem(emoji: "🌹", name: "Rose", coins: 10),
  GiftItem(emoji: "❤️", name: "Heart", coins: 20),
  GiftItem(emoji: "🎉", name: "Party", coins: 50),
  GiftItem(emoji: "👑", name: "Crown", coins: 100),
  GiftItem(emoji: "💎", name: "Diamond", coins: 200),
  GiftItem(emoji: "🚗", name: "Car", coins: 500),
  GiftItem(emoji: "🚀", name: "Rocket", coins: 1000),
  GiftItem(emoji: "🏆", name: "Trophy", coins: 2000),
];

/// Shows the gift picker as a modal bottom sheet.
/// Calls [onGiftSent] with the chosen gift when the user taps Send.
Future<void> showGiftSheet(
  BuildContext context, {
  required void Function(GiftItem gift) onGiftSent,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => GiftSheet(onGiftSent: onGiftSent),
  );
}

class GiftSheet extends StatefulWidget {
  final void Function(GiftItem gift) onGiftSent;

  const GiftSheet({
    super.key,
    required this.onGiftSent,
  });

  @override
  State<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedGift = kGifts[selectedIndex];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF15151A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Send a Gift",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "1,250",
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: GridView.builder(
                itemCount: kGifts.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final gift = kGifts[index];
                  final isSelected = index == selectedIndex;

                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedIndex = index);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.pinkAccent.withOpacity(0.18)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.pinkAccent
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            gift.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gift.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            "${gift.coins}",
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onGiftSent(selectedGift);
                },
                child: Text(
                  "Send ${selectedGift.emoji} (${selectedGift.coins} coins)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}