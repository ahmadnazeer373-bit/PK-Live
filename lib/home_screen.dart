import 'package:flutter/material.dart';
import 'Screen/live_room_screen.dart';
import 'Screen/party_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class LiveUser {
  final String name;
  final String image;
  final int viewers;
  final String flag;
  final String? tag; // "NEW HOST", "PK", null
  final List<Color> cardGradient;

  const LiveUser({
    required this.name,
    required this.image,
    required this.viewers,
    required this.flag,
    this.tag,
    required this.cardGradient,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _bannerController = PageController(viewportFraction: 0.92);

  final List<LiveUser> liveUsers = const [
    LiveUser(
      name: "Ali",
      image: "🧕",
      viewers: 553,
      flag: "🇵🇰",
      tag: null,
      cardGradient: [Color(0xFF3A1C71), Color(0xFF5B2C6F)],
    ),
    LiveUser(
      name: "Welcome To Ali",
      image: "👨‍🦱",
      viewers: 195,
      flag: "🇵🇰",
      tag: "PK",
      cardGradient: [Color(0xFF232526), Color(0xFF414345)],
    ),
    LiveUser(
      name: "Sara",
      image: "👩",
      viewers: 194,
      flag: "🇮🇳",
      tag: null,
      cardGradient: [Color(0xFF614385), Color(0xFF516395)],
    ),
    LiveUser(
      name: "welcome guyzzz I am",
      image: "👩‍🦳",
      viewers: 133,
      flag: "🇧🇩",
      tag: "PK",
      cardGradient: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
    ),
    LiveUser(
      name: "Zain",
      image: "🧑",
      viewers: 88,
      flag: "🇵🇰",
      tag: "NEW HOST",
      cardGradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    LiveUser(
      name: "Ayesha",
      image: "👩‍🎤",
      viewers: 342,
      flag: "🇵🇰",
      tag: null,
      cardGradient: [Color(0xFFEE0979), Color(0xFFFF6A00)],
    ),
  ];

  late List<LiveUser> filteredUsers = liveUsers;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();

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

  Widget _liveAvatarsRow() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: liveUsers.length,
        itemBuilder: (context, index) {
          final user = liveUsers[index];
          return GestureDetector(
            onTap: () => openLiveRoom(context, user.name),
            child: Container(
              width: 66,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF1A1A2E),
                      child: Text(user.image, style: const TextStyle(fontSize: 22)),
                    ),
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

  Widget _liveCard(LiveUser user) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
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
              child: filteredUsers.isEmpty
                  ? const Center(
                      child: Text("No users found", style: TextStyle(color: Colors.white38)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: filteredUsers.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (context, index) => _liveCard(filteredUsers[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}