import 'package:flutter/material.dart';

import '../widgets/top_host_info.dart';
import '../widgets/live_action_buttons.dart';
import '../widgets/comment_box.dart';
import '../widgets/floating_hearts.dart';
import '../widgets/gift_sheet.dart';

class LiveRoomScreen extends StatefulWidget {
  final String userName;

  const LiveRoomScreen({
    super.key,
    required this.userName,
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  int likeCount = 0;
  int viewers = 256;

  Offset? heartPosition;

  final List<String> messages = [];

  final TextEditingController commentController =
      TextEditingController();

  void addLike() {
    setState(() {
      likeCount++;
    });
  }

  void sendComment() {
    final text = commentController.text.trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      messages.add("${widget.userName}: $text");
    });

    commentController.clear();
  }

  void openGiftSheet() {
    showGiftSheet(
      context,
      onGiftSent: (gift) {
        setState(() {
          messages.add(
            "${widget.userName} sent ${gift.emoji} ${gift.name}",
          );
        });
      },
    );
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          setState(() {
            heartPosition = details.localPosition;
            likeCount++;
          });
        },
        child: SizedBox.expand(
          child: Stack(
            children: [

              // Background
              Positioned.fill(
                child: Image.network(
                  "https://picsum.photos/600/1200",
                  fit: BoxFit.cover,
                ),
              ),

              // Dark Overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromARGB(120, 0, 0, 0),
                        Colors.transparent,
                        Colors.transparent,
                        Color.fromARGB(180, 0, 0, 0),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Hearts
              Positioned.fill(
                child: FloatingHearts(
                  tapPosition: heartPosition,
                ),
              ),

              // Top Host
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TopHostInfo(
                  userName: widget.userName,
                  likes: likeCount,
                  viewers: viewers,
                  onClose: () {
                    Navigator.pop(context);
                  },
                ),
              ),

              // Right Buttons
              Positioned(
                right: 15,
                bottom: 210,
                child: LiveActionButtons(
                  onLike: addLike,
                  onGift: openGiftSheet,
                ),
              ),

              // Bottom Comment
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CommentBox(
                  controller: commentController,
                  messages: messages,
                  onGift: openGiftSheet,
                  onSend: sendComment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}