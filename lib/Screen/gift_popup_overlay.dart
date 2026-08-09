import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/full_screen_video_gift.dart';
import '../services/level_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class GiftPopupBus {
  static final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get stream => _controller.stream;
  static void emit(Map<String, dynamic> giftData) => _controller.add(giftData);
}

class GiftPopupOverlay extends StatefulWidget {
  final String roomId;
  const GiftPopupOverlay({super.key, required this.roomId});

  @override
  State<GiftPopupOverlay> createState() => _GiftPopupOverlayState();
}

class _GiftPopupOverlayState extends State<GiftPopupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  StreamSubscription<Map<String, dynamic>>? _busSubscription;

  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _current;
  String? _lastSeenMessageId;
  bool _isFirstSnapshot = true;

  @override
  void initState() {
    super.initState();
    print("🔥🔥🔥 GiftPopupOverlay initState() called!");
    
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<Offset>(begin: const Offset(-1.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _busSubscription = GiftPopupBus.stream.listen(_handleNewGift);
    print("🔥🔥🔥 GiftPopupBus listener registered!");
  }

  @override
  void dispose() {
    _controller.dispose();
    _busSubscription?.cancel();
    super.dispose();
  }

  void _handleNewGift(Map<String, dynamic> giftData) {
    print("🔥🔥🔥 _handleNewGift() called!");
    print("🎁 Gift received: ${giftData['videoUrl']}");

    final videoUrl = giftData['videoUrl'] as String?;
    
    if (videoUrl != null && videoUrl.isNotEmpty && videoUrl.startsWith('http')) {
      print("🎬 Video gift detected! URL: $videoUrl");
      _showVideoOverlay(giftData);
      return;
    }

    print("📦 Normal gift (emoji/image)");
    _queue.add(giftData);
    if (_current == null) _showNext();
  }

  void _showVideoOverlay(Map<String, dynamic> giftData) {
    final videoUrl = giftData['videoUrl'] as String? ?? '';
    print("🚀 Opening video: $videoUrl");
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenVideoGift(
          videoUrl: videoUrl,
          senderName: giftData['senderName'] ?? 'User',
          receiverName: giftData['receiverName'] ?? 'User',
          giftName: giftData['giftName'] ?? 'Gift',
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _current = null;
          _queue.clear();
          _isFirstSnapshot = true;
          _lastSeenMessageId = null;
        });
      }
    });
  }

  Future<void> _showNext() async {
    if (_queue.isEmpty) {
      if (mounted) setState(() => _current = null);
      return;
    }
    final next = _queue.removeAt(0);
    if (mounted) setState(() => _current = next);
    await _controller.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    _showNext();
  }

  Widget _buildAvatar(String? photoUrl, String? emoji, {double radius = 18}) {
    final isNetwork = photoUrl != null &&
        photoUrl.isNotEmpty &&
        photoUrl.startsWith('http');
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      backgroundImage: isNetwork ? NetworkImage(photoUrl) : null,
      child: isNetwork
          ? null
          : Text(
              (emoji != null && emoji.isNotEmpty) ? emoji : "🧑",
              style: TextStyle(fontSize: radius * 0.9),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("🔥🔥🔥 GiftPopupOverlay build() called!");
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('party_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .where('type', isEqualTo: 'gift')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (_isFirstSnapshot) {
          _isFirstSnapshot = false;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            _lastSeenMessageId = snapshot.data!.docs.first.id;
          }
        } else if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          if (doc.id != _lastSeenMessageId) {
            _lastSeenMessageId = doc.id;
            final data = doc.data() as Map<String, dynamic>;
            final isOwnGift =
                data['senderUid'] == FirebaseAuth.instance.currentUser?.uid;
            if (!isOwnGift) {
              _updateReceiverLevel(data);
              
              final videoUrl = data['videoUrl'] as String?;
              if (videoUrl != null && videoUrl.isNotEmpty && videoUrl.startsWith('http')) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  print("🎬 Video gift from Firestore!");
                  _showVideoOverlay(data);
                });
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleNewGift(data);
                });
              }
            }
          }
        }

        if (_current == null) return const SizedBox.shrink();
        final data = _current!;

        return SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A3DE8), Color(0xFF3D2374)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatar(
                    data['senderPhoto'] as String?,
                    data['senderAvatar'] as String?,
                    radius: 18,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (data['senderName'] as String?) ?? "User",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          const Text("Send",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                          const SizedBox(width: 4),
                          _buildAvatar(
                            data['receiverPhoto'] as String?,
                            data['receiverAvatar'] as String?,
                            radius: 9,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(data['giftEmoji'] as String? ?? "🎁",
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 6),
                  Text(
                    "x${data['quantity'] ?? 1}",
                    style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateReceiverLevel(Map<String, dynamic> giftData) async {
    try {
      final receiverUid = giftData['receiverUid'] as String?;
      final totalPrice = (giftData['totalPrice'] ?? 0) as int;
      
      if (receiverUid != null && totalPrice > 0) {
        await LevelService.instance.updateReceivingLevel(receiverUid, totalPrice);
        print("✅ Receiver level updated for: $receiverUid");
      }
    } catch (e) {
      print("❌ Error updating receiver level: $e");
    }
  }
}