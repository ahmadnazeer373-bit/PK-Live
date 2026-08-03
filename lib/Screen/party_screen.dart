import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'party_room_screen.dart';

// Rooms lobby / list screen.
// Firestore schema (matches party_room_screen.dart):
//   party_rooms/{roomId}
//     - title       (String)
//     - hostUid     (String)
//     - hostName    (String)
//     - hostAvatar  (String, emoji)
//     - coverImage  (String, optional network image URL used as the card
//                    background; falls back to a gradient + hostAvatar
//                    emoji when not set)
//     - createdAt   (Timestamp)
//   party_rooms/{roomId}/seats/{seatIndex}  -> used here only to show occupied-seat count
//
// NOTE: Room creation is intentionally not available on this screen —
// only active rooms are listed here.

const int _totalSeats = 12;
const int _hotThreshold = 8; // seats occupied at/above this = "HOT" badge

const List<List<Color>> _cardGradientPalette = [
  [Color(0xFF3A1C71), Color(0xFF5B2C6F)],
  [Color(0xFF232526), Color(0xFF414345)],
  [Color(0xFF614385), Color(0xFF516395)],
  [Color(0xFF1F1C2C), Color(0xFF928DAB)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFEE0979), Color(0xFFFF6A00)],
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  [Color(0xFFFF512F), Color(0xFFDD2476)],
];

class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> with SingleTickerProviderStateMixin {
  CollectionReference get _roomsRef => FirebaseFirestore.instance.collection('party_rooms');

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------- Premium app bar ----------------

  Widget _premiumAppBar(int roomCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B1055), Color(0xFF7597DE)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFE8A3), Color(0xFFFFB74D)],
              ).createShader(bounds),
              child: const Text(
                "Party Rooms",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (roomCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pulseDot(size: 6, color: Colors.greenAccent),
                    const SizedBox(width: 5),
                    Text(
                      "$roomCount live",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _pulseDot({required double size, required Color color}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.55 * (1 - t)),
                blurRadius: 6 * t + 2,
                spreadRadius: 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- Glass badge (seat count + hot tag) ----------------

  Widget _glassBadge(String roomId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('party_rooms')
          .doc(roomId)
          .collection('seats')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pulseDot(size: 6, color: Colors.redAccent),
                  const SizedBox(width: 5),
                  const Icon(Icons.headset_mic, color: Colors.white, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    "$count/$_totalSeats",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hotBadge(String roomId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('party_rooms')
          .doc(roomId)
          .collection('seats')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count < _hotThreshold) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, color: Colors.white, size: 12),
              SizedBox(width: 2),
              Text("HOT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            ],
          ),
        );
      },
    );
  }

  // ---------------- Room card ----------------

  Widget _roomCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final title = data['title'] ?? "Party Room";
    final hostName = data['hostName'] ?? "Host";
    final hostAvatar = data['hostAvatar'] ?? "👑";
    final coverImage = (data['coverImage'] ?? "").toString();
    final gradient = _cardGradientPalette[index % _cardGradientPalette.length];
    final isTopRoom = index == 0;

    final card = InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PartyRoomScreen(roomId: doc.id)),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(
            color: isTopRoom ? const Color(0xFFFFD700).withOpacity(0.6) : Colors.white.withOpacity(0.08),
            width: isTopRoom ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isTopRoom ? const Color(0xFFFFD700) : gradient[0]).withOpacity(0.32),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverImage.isNotEmpty)
              Image.network(
                coverImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(hostAvatar, style: const TextStyle(fontSize: 60)),
                ),
              )
            else
              Center(child: Text(hostAvatar, style: const TextStyle(fontSize: 60))),

            // subtle top darken so badges stay legible on bright covers
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 46,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                  ),
                ),
              ),
            ),

            Positioned(top: 8, left: 8, child: _glassBadge(doc.id)),
            Positioned(top: 8, right: 8, child: _hotBadge(doc.id)),

            if (isTopRoom)
              const Positioned(
                bottom: 46,
                left: 8,
                child: Text("👑", style: TextStyle(fontSize: 16)),
              ),

            // Bottom title overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 22, 10, 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.mic, color: Colors.white70, size: 13),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hostName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Staggered fade + rise entrance animation, self-contained per card.
    return TweenAnimationBuilder<double>(
      key: ValueKey(doc.id),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index % 6) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
        );
      },
      child: card,
    );
  }

  // ---------------- Shimmer loading state ----------------

  Widget _shimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final t = _pulseController.value;
          return Container(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.white.withOpacity(0.04), Colors.white.withOpacity(0.09), t),
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.03)]),
            ),
            child: const Icon(Icons.podcasts, color: Colors.white38, size: 34),
          ),
          const SizedBox(height: 14),
          const Text(
            "No active party rooms right now",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            "Check back again soon",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1836), Color(0xFF0D0B1E), Color(0xFF0A0815)],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _roomsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            return Column(
              children: [
                _premiumAppBar(snapshot.hasData ? docs.length : 0),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text("Failed to load rooms", style: TextStyle(color: Colors.white54)),
                        );
                      }
                      if (!snapshot.hasData) {
                        return _shimmerGrid();
                      }
                      if (docs.isEmpty) {
                        return _emptyState();
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        itemCount: docs.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, index) => _roomCard(docs[index], index),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}