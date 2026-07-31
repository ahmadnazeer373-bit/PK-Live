import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Screen/live_room_screen.dart';
import 'Screen/party_screen.dart';

// ASSUMPTIONS (adjust if your Firestore schema differs):
// - Collection: 'users'
// - Field 'isLive' (bool)      -> true when the user is currently live
// - Field 'totalGifts' (number) -> running total of gifts/points received
//   Sorting is done by totalGifts DESC, so the top-gifted host always
//   surfaces first on every load/refresh automatically.
// - Optional fields: 'name', 'avatar' (emoji/url), 'viewers' (int),
//   'flag' (emoji), 'tag' ("PK" | "NEW HOST" | null)
// - Field 'agencyId' (string, nullable) -> set once the user joins an
//   agency. The Go-Live camera button only appears once this field is
//   non-empty. No agency system exists yet — once it's built, simply set
//   this field on the user's document when they join an agency and the
//   button will start showing automatically, no further code changes needed.

const int _pageSize = 60;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class LiveUser {
  final String id;
  final String name;
  final String image;
  final int viewers;
  final String flag;
  final String? tag;
  final num totalGifts;
  final List<Color> cardGradient;

  const LiveUser({
    required this.id,
    required this.name,
    required this.image,
    required this.viewers,
    required this.flag,
    this.tag,
    required this.totalGifts,
    required this.cardGradient,
  });

  factory LiveUser.fromDoc(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LiveUser(
      id: doc.id,
      name: data['name'] ?? "User",
      image: data['avatar'] ?? "🧑",
      viewers: (data['viewers'] ?? 0) is int
          ? data['viewers'] ?? 0
          : (data['viewers'] as num?)?.toInt() ?? 0,
      flag: data['flag'] ?? "🌍",
      tag: data['tag'],
      totalGifts: (data['totalGifts'] ?? 0) as num,
      cardGradient: _gradientPalette[index % _gradientPalette.length],
    );
  }
}

const List<List<Color>> _gradientPalette = [
  [Color(0xFF3A1C71), Color(0xFF5B2C6F)],
  [Color(0xFF232526), Color(0xFF414345)],
  [Color(0xFF614385), Color(0xFF516395)],
  [Color(0xFF1F1C2C), Color(0xFF928DAB)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFEE0979), Color(0xFFFF6A00)],
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  [Color(0xFFFF512F), Color(0xFFDD2476)],
];

class _HomeScreenState extends State<HomeScreen> {
  final PageController _bannerController = PageController(viewportFraction: 0.92);
  final ScrollController _gridController = ScrollController();

  final List<LiveUser> liveUsers = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  late List<LiveUser> filteredUsers = [];
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();

  Query<Map<String, dynamic>> get _baseQuery => FirebaseFirestore.instance
      .collection('users')
      .where('isLive', isEqualTo: true)
      .orderBy('totalGifts', descending: true);

  @override
  void initState() {
    super.initState();
    _fetchInitial();
    _gridController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _gridController.removeListener(_onScroll);
    _gridController.dispose();
    _bannerController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_gridController.hasClients) return;
    final nearBottom = _gridController.position.pixels >=
        _gridController.position.maxScrollExtent - 300;
    if (nearBottom) _fetchMore();
  }

  Future<void> _fetchInitial() async {
    setState(() => _isLoadingInitial = true);
    try {
      final snap = await _baseQuery.limit(_pageSize).get();
      liveUsers
        ..clear()
        ..addAll(snap.docs.asMap().entries.map((e) => LiveUser.fromDoc(e.value, e.key)));
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == _pageSize;
      filteredUsers = liveUsers;
    } catch (e) {
      debugPrint("Failed to load live users: $e");
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _fetchMore() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null || isSearching) return;
    setState(() => _isLoadingMore = true);
    try {
      final snap = await _baseQuery.startAfterDocument(_lastDoc!).limit(_pageSize).get();
      final startIndex = liveUsers.length;
      final newUsers = snap.docs
          .asMap()
          .entries
          .map((e) => LiveUser.fromDoc(e.value, startIndex + e.key))
          .toList();
      setState(() {
        liveUsers.addAll(newUsers);
        filteredUsers = liveUsers;
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length == _pageSize;
      });
    } catch (e) {
      debugPrint("Failed to load more live users: $e");
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    _lastDoc = null;
    _hasMore = true;
    await _fetchInitial();
  }

  void openLiveRoom(BuildContext context, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LiveRoomScreen(userName: name)),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      filteredUsers = query.isEmpty
          ? liveUsers
          : liveUsers
              .where((u) => u.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        searchController.clear();
        filteredUsers = liveUsers;
      }
    });
  }

  void _showRankSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your Rank",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                    ),
                    child: const Icon(Icons.emoji_events, color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Rank: Unranked", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text("Points: 0", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Live rooms mein active raho aur points kamao apna rank badhane ke liye.",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B1055), Color(0xFF7597DE)],
        ),
      ),
      child: isSearching
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "Search users...",
                      hintStyle: const TextStyle(color: Colors.white60, fontSize: 15),
                      isDense: true,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: _toggleSearch,
                ),
              ],
            )
          : Row(
              children: [
                const Text("Mine", style: TextStyle(color: Colors.white60, fontSize: 15)),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PartyScreen()),
                    );
                  },
                  child: const Text("Party", style: TextStyle(color: Colors.white60, fontSize: 15)),
                ),
                const SizedBox(width: 18),
                Column(
                  children: const [
                    Text(
                      "Live",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    SizedBox(
                      width: 20,
                      child: Divider(color: Colors.redAccent, thickness: 2),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showRankSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.black, size: 14),
                        SizedBox(width: 3),
                        Text("Lv.1", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _toggleSearch,
                  child: const Icon(Icons.search, color: Colors.white70, size: 20),
                ),
              ],
            ),
    );
  }

  Widget _bannerCarousel() {
    final banners = [
      ["🎮", "Weekend Gaming Fest", [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)]],
      ["🎁", "Daily Rewards Await", [const Color(0xFFFF512F), const Color(0xFFDD2476)]],
      ["🏆", "Top Host Challenge", [const Color(0xFF11998E), const Color(0xFF38EF7D)]],
    ];

    return SizedBox(
      height: 110,
      child: PageView.builder(
        controller: _bannerController,
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          final colors = banner[2] as List<Color>;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: colors[0].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),
                Text(banner[0] as String, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    banner[1] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Top-gifted hosts strip (first N of the sorted-by-gifts list, so this
  // also naturally reflects whoever is receiving the most gifts right now).
  Widget _liveAvatarsRow() {
    final topHosts = liveUsers.take(12).toList();
    if (topHosts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 96,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: topHosts.length,
        itemBuilder: (context, index) {
          final user = topHosts[index];
          return GestureDetector(
            onTap: () => openLiveRoom(context, user.name),
            child: Container(
              width: 66,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: index < 3
                                ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                                : [const Color(0xFFFF5F6D), const Color(0xFFFFC371)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF1A1A2E),
                          child: Text(user.image, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      if (index < 3)
                        Positioned(
                          top: -6,
                          right: -2,
                          child: Text(
                            index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "LIVE",
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _liveCard(LiveUser user, int rank) {
    return InkWell(
      onTap: () => openLiveRoom(context, user.name),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: user.cardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: user.cardGradient[0].withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Center(
              child: Text(user.image, style: const TextStyle(fontSize: 72)),
            ),
            // Top-left viewer count
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, color: Colors.pinkAccent, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      "${user.viewers}",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            // Top-right tag (PK or flag)
            if (user.tag == "PK")
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.redAccent, Colors.orangeAccent]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "PK",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Positioned(
                top: 8,
                right: 8,
                child: Text(user.flag, style: const TextStyle(fontSize: 16)),
              ),
            // New host ribbon
            if (user.tag == "NEW HOST")
              Positioned(
                top: 10,
                left: -28,
                child: Transform.rotate(
                  angle: -0.78,
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    color: Colors.greenAccent.shade400,
                    alignment: Alignment.center,
                    child: const Text(
                      "NEW HOST",
                      style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            // Top-gifted rank badge (crown for #1 overall)
            if (rank == 0)
              Positioned(
                top: 8,
                left: 8,
                child: Text("👑", style: const TextStyle(fontSize: 16)),
              ),
            // Bottom name overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.mic, color: Colors.white70, size: 13),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _goLiveButton() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final agencyId = data['agencyId'];
        final hasAgency = agencyId != null && agencyId.toString().trim().isNotEmpty;

        if (!hasAgency) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
            tooltip: "Go Live",
            onPressed: () {
              // TODO: wire this to your actual Go-Live flow/screen once it's built.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Go Live flow abhi connect karna hai")),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4),
        child: _goLiveButton(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (!isSearching) ...[
              _bannerCarousel(),
              const SizedBox(height: 4),
              _liveAvatarsRow(),
              const Divider(color: Colors.white12, height: 1),
            ],
            Expanded(
              child: _isLoadingInitial
                  ? _shimmerGrid()
                  : filteredUsers.isEmpty
                      ? const Center(
                          child: Text("No users found", style: TextStyle(color: Colors.white38)),
                        )
                      : RefreshIndicator(
                          color: Colors.amberAccent,
                          backgroundColor: const Color(0xFF1A1A2E),
                          onRefresh: _onRefresh,
                          child: GridView.builder(
                            controller: _gridController,
                            padding: const EdgeInsets.all(10),
                            itemCount: filteredUsers.length + (_hasMore && !isSearching ? 1 : 0),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.78,
                            ),
                            itemBuilder: (context, index) {
                              if (index >= filteredUsers.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.amberAccent,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return _liveCard(filteredUsers[index], index);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}