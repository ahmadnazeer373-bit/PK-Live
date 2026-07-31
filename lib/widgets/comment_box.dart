import 'package:flutter/material.dart';

/// Bottom message area for the Live Room.
///
/// Shows a scrollable list of recent chat messages above the input row,
/// plus a gift button next to the send button.
class CommentBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onGift;
  final List<String> messages;

  const CommentBox({
    super.key,
    required this.controller,
    required this.onSend,
    this.onGift,
    this.messages = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent messages list
            if (messages.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 160,
                child: ListView.builder(
                  reverse: true,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 6),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[messages.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (messages.isNotEmpty) const SizedBox(height: 6),

            // Input row
            Row(
              children: [
                // Gift button
                GestureDetector(
                  onTap: onGift,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.35),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: Colors.amber,
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: SizedBox(
                      height: 46,
                      child: Center(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: Colors.white,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          decoration: const InputDecoration(
                            hintText: "Say something...",
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF4B8B), Color(0xFFFF7A59)],
                      ),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}