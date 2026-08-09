import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullScreenVideoGift extends StatefulWidget {
  final String videoUrl;
  final String senderName;
  final String receiverName;
  final String giftName;

  const FullScreenVideoGift({
    super.key,
    required this.videoUrl,
    required this.senderName,
    required this.receiverName,
    required this.giftName,
  });

  @override
  State<FullScreenVideoGift> createState() => _FullScreenVideoGiftState();
}

class _FullScreenVideoGiftState extends State<FullScreenVideoGift> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        if (mounted) {
          _controller.play();
          setState(() {
            _isInitialized = true;
          });
        }
      }).catchError((error) {
        print("⚠️ Video error: $error");
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    _controller.addListener(() {
      if (_controller.value.isCompleted && !_isClosing) {
        _autoCloseVideo();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _autoCloseVideo() {
    if (mounted && !_isClosing) {
      _isClosing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } catch (e) {
            print("⚠️ Error closing video: $e");
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          : Container(color: Colors.black),
    );
  }
}