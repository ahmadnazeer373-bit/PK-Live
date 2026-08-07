import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String _adminUid = "1dd7eMMAm9dp6QqOzQsr5eJXPjB2";

class GiftCatalogAdminScreen extends StatefulWidget {
  const GiftCatalogAdminScreen({super.key});

  @override
  State<GiftCatalogAdminScreen> createState() => _GiftCatalogAdminScreenState();
}

class _GiftCatalogAdminScreenState extends State<GiftCatalogAdminScreen> {
  bool get _isAdmin => FirebaseAuth.instance.currentUser?.uid == _adminUid;

  static const List<String> _categories = ["Event", "Hot", "VIP", "Customized"];

  // 🔥 3 Options: Emoji, Image, Video
  static const List<String> _giftTypes = ["Emoji", "Image", "Video"];

  /// Curated starter gifts across all four categories. Each entry:
  /// [emoji, name, coinPrice, category, isGlobal, hasSound].
  static const List<List<Object>> _sampleGifts = [
    // ---------------- Event (30) ----------------
    ["🎆", "Fireworks", 500, "Event", true, true],
    ["🎉", "Party Popper", 100, "Event", false, true],
    ["🎊", "Confetti", 60, "Event", false, false],
    ["🎂", "Birthday Cake", 300, "Event", false, true],
    ["🎈", "Balloon", 30, "Event", false, false],
    ["🎗️", "Ribbon", 40, "Event", false, false],
    ["🧨", "Firecracker", 150, "Event", false, true],
    ["📯", "Party Horn", 80, "Event", false, true],
    ["🎁", "Gift Box", 120, "Event", false, false],
    ["🏆", "Trophy", 400, "Event", false, false],
    ["🎖️", "Medal", 200, "Event", false, false],
    ["🥳", "Party Hat", 50, "Event", false, false],
    ["🎏", "Streamers", 45, "Event", false, false],
    ["🕯️", "Candle", 25, "Event", false, false],
    ["🧁", "Cupcake", 60, "Event", false, false],
    ["🍾", "Champagne", 350, "Event", false, true],
    ["🥂", "Toast", 90, "Event", false, false],
    ["🔔", "Wedding Bell", 300, "Event", false, true],
    ["🎇", "New Year Countdown", 800, "Event", true, true],
    ["🎄", "Christmas Tree", 600, "Event", true, false],
    ["🎅", "Santa Hat", 200, "Event", false, false],
    ["🎃", "Pumpkin", 150, "Event", false, false],
    ["🥚", "Easter Egg", 80, "Event", false, false],
    ["🎓", "Graduation Cap", 250, "Event", false, false],
    ["💍", "Wedding Rings", 5000, "Event", false, true],
    ["💐", "Bouquet", 300, "Event", false, false],
    ["🍰", "Wedding Cake", 1200, "Event", true, true],
    ["💘", "Love Fireworks", 2000, "Event", true, true],
    ["🌟", "Anniversary Star", 700, "Event", false, false],
    ["🎭", "Carnival Mask", 180, "Event", false, false],

    // ---------------- Hot (30) ----------------
    ["☁️", "Cloud", 30000, "Hot", true, true],
    ["🌹", "rose", 50, "Hot", false, false],
    ["💰", "Treasure", 100, "Hot", false, false],
    ["❄️", "Air conditioner", 20000, "Hot", true, false],
    ["🧧", "lucky bag", 15000, "Hot", false, false],
    ["🎮", "Tetris", 90000, "Hot", true, true],
    ["🏰", "Moving Castle", 100000, "Hot", true, true],
    ["💎", "diamond", 8000, "Hot", false, true],
    ["🌈", "Rainbow", 3000, "Hot", false, false],
    ["🦄", "Unicorn", 12000, "Hot", true, true],
    ["🐉", "Dragon", 50000, "Hot", true, true],
    ["🦅", "Phoenix", 60000, "Hot", true, true],
    ["🦋", "Butterfly", 2000, "Hot", false, false],
    ["🌌", "Galaxy", 40000, "Hot", true, true],
    ["🌠", "Shooting Star", 5000, "Hot", false, true],
    ["☄️", "Meteor", 25000, "Hot", true, true],
    ["🔫", "Golden Gun", 35000, "Hot", false, true],
    ["🏍️", "Motorbike", 45000, "Hot", true, true],
    ["🏀", "Basketball", 3000, "Hot", false, false],
    ["⚽", "Football", 3000, "Hot", false, false],
    ["🎸", "Guitar", 8000, "Hot", false, true],
    ["🎹", "Piano", 10000, "Hot", false, true],
    ["🥁", "Drum Set", 9000, "Hot", false, true],
    ["🎧", "Headphones", 4000, "Hot", false, true],
    ["📷", "Camera", 6000, "Hot", false, false],
    ["🍦", "Ice Cream", 500, "Hot", false, false],
    ["🍿", "Popcorn", 400, "Hot", false, false],
    ["🍕", "Pizza", 700, "Hot", false, false],
    ["🍔", "Burger", 600, "Hot", false, false],
    ["🍩", "Donut", 350, "Hot", false, false],

    // ---------------- VIP (30) ----------------
    ["👑", "Crown", 150000, "VIP", true, true],
    ["🛥️", "Yacht", 200000, "VIP", true, true],
    ["🏎️", "Sports Car", 180000, "VIP", true, true],
    ["✈️", "Private Jet", 250000, "VIP", true, true],
    ["🏯", "Castle", 220000, "VIP", true, false],
    ["🚀", "Rocket", 300000, "VIP", true, true],
    ["🏛️", "Mansion", 280000, "VIP", true, false],
    ["🏝️", "Island", 350000, "VIP", true, true],
    ["🪙", "Gold Bar", 100000, "VIP", false, false],
    ["💰", "Treasure Chest", 120000, "VIP", false, false],
    ["⌚", "Luxury Watch", 90000, "VIP", false, false],
    ["🚁", "Helicopter", 260000, "VIP", true, true],
    ["🚤", "Submarine", 240000, "VIP", true, false],
    ["🛸", "Space Ship", 400000, "VIP", true, true],
    ["🪑", "Throne", 200000, "VIP", false, false],
    ["🐎", "Royal Carriage", 210000, "VIP", false, false],
    ["🏰", "Palace", 320000, "VIP", true, false],
    ["🦁", "Golden Lion", 150000, "VIP", true, true],
    ["🐲", "Dragon King", 350000, "VIP", true, true],
    ["🔥", "Phoenix Throne", 380000, "VIP", true, true],
    ["👑", "Emperor Crown", 500000, "VIP", true, true],
    ["💎", "Diamond Tiara", 300000, "VIP", false, true],
    ["🦅", "Golden Eagle", 180000, "VIP", true, false],
    ["🚢", "Luxury Cruise", 270000, "VIP", true, true],
    ["🏖️", "Private Island", 450000, "VIP", true, true],
    ["🗿", "Golden Statue", 160000, "VIP", false, false],
    ["🔱", "Royal Scepter", 140000, "VIP", false, false],
    ["💎", "Diamond Necklace", 200000, "VIP", false, false],
    ["💳", "Platinum Card", 130000, "VIP", false, false],
    ["👑", "Galaxy Crown", 500000, "VIP", true, true],

    // ---------------- Customized (30) ----------------
    ["❤️", "Heart", 20, "Customized", false, false],
    ["💋", "Kiss", 50, "Customized", false, false],
    ["🧸", "Teddy Bear", 200, "Customized", false, false],
    ["💍", "Ring", 5000, "Customized", false, true],
    ["💌", "Love Letter", 80, "Customized", false, false],
    ["🌷", "Perfume", 400, "Customized", false, false],
    ["🍫", "Chocolate", 60, "Customized", false, false],
    ["💐", "Flower Bouquet", 300, "Customized", false, false],
    ["🧪", "Love Potion", 150, "Customized", false, false],
    ["🏹", "Cupid Arrow", 250, "Customized", false, false],
    ["🔒", "Love Lock", 180, "Customized", false, false],
    ["💍", "Promise Ring", 3000, "Customized", false, true],
    ["🌹", "Valentine Rose", 500, "Customized", false, false],
    ["🎈", "Love Balloon", 120, "Customized", false, false],
    ["💄", "Kissing Lips", 90, "Customized", false, false],
    ["🤗", "Hug", 40, "Customized", false, false],
    ["📝", "Love Note", 30, "Customized", false, false],
    ["💕", "Sweetheart", 100, "Customized", false, false],
    ["🍽️", "Romantic Dinner", 800, "Customized", false, true],
    ["🕯️", "Candle Light", 60, "Customized", false, false],
    ["🎵", "Love Song", 700, "Customized", false, true],
    ["🎶", "Music Box", 900, "Customized", false, true],
    ["🖼️", "Photo Frame", 200, "Customized", false, false],
    ["✉️", "Love Envelope", 70, "Customized", false, false],
    ["💎", "Diamond Heart", 6000, "Customized", false, true],
    ["♾️", "Infinity Symbol", 1500, "Customized", false, false],
    ["🕊️", "Love Birds", 400, "Customized", false, false],
    ["🎈", "Heart Balloon", 150, "Customized", false, false],
    ["🪽", "Cupid Wings", 2000, "Customized", false, false],
    ["♾️", "Eternal Love", 8000, "Customized", true, true],
  ];

  Future<void> _seedSampleGifts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add sample gifts?", style: TextStyle(color: Colors.white)),
        content: Text(
          "This adds ${_sampleGifts.length} starter gifts across Event, Hot, VIP and Customized. Existing gifts won't be touched.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Add Gifts", style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('gift_catalog');

    for (final gift in _sampleGifts) {
      final docRef = collection.doc();
      batch.set(docRef, {
        'emoji': gift[0],
        'name': gift[1],
        'coinPrice': gift[2],
        'category': gift[3],
        'isGlobal': gift[4],
        'hasSound': gift[5],
        'imageUrl': null,
        'videoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_sampleGifts.length} gifts added!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add gifts: $e")),
      );
    }
  }

  Future<void> _openGiftForm({DocumentSnapshot? existing}) async {
    final nameController = TextEditingController(text: existing?.get('name') ?? '');
    final emojiController = TextEditingController(text: existing?.get('emoji') ?? '🎁');
    final priceController = TextEditingController(
      text: existing != null ? existing.get('coinPrice').toString() : '',
    );
    final imageUrlController = TextEditingController(
      text: existing != null ? (existing.get('imageUrl') as String? ?? '') : '',
    );
    final videoUrlController = TextEditingController(
      text: existing != null ? (existing.get('videoUrl') as String? ?? '') : '',
    );

    // 🔥 Current gift type detect karein
    String giftType = "Emoji";
    if (existing != null) {
      final data = existing.data() as Map<String, dynamic>? ?? {};
      if (data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty) {
        giftType = "Video";
      } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
        giftType = "Image";
      }
    }

    String category = (existing?.data() as Map<String, dynamic>?)?['category'] as String? ?? _categories.first;
    bool isGlobal = (existing?.data() as Map<String, dynamic>?)?['isGlobal'] as bool? ?? false;
    bool hasSound = (existing?.data() as Map<String, dynamic>?)?['hasSound'] as bool? ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1930),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? "Add Gift" : "Edit Gift",
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔥 Gift Type Dropdown (Emoji / Image / Video)
                DropdownButtonFormField<String>(
                  value: giftType,
                  dropdownColor: const Color(0xFF1B1930),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Gift Type",
                    labelStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.category, color: Colors.amberAccent),
                  ),
                  items: _giftTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                type == "Emoji"
                                    ? const Icon(Icons.emoji_emotions, color: Colors.yellow, size: 18)
                                    : type == "Image"
                                        ? const Icon(Icons.image, color: Colors.green, size: 18)
                                        : const Icon(Icons.videocam, color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Text(type, style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        giftType = value;
                        // 🔥 Agar Emoji select kiya toh image/video URLs clear karein
                        if (value == "Emoji") {
                          imageUrlController.text = "";
                          videoUrlController.text = "";
                        } else if (value == "Image") {
                          videoUrlController.text = "";
                        } else if (value == "Video") {
                          imageUrlController.text = "";
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Emoji Field (sirf Emoji type mein dikhe)
                if (giftType == "Emoji")
                  TextField(
                    controller: emojiController,
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: "Emoji",
                      labelStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(Icons.emoji_emotions, color: Colors.yellow),
                    ),
                  ),

                // Image URL Field (sirf Image type mein dikhe)
                if (giftType == "Image")
                  TextField(
                    controller: imageUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Image URL",
                      labelStyle: TextStyle(color: Colors.white54),
                      hintText: "https://res.cloudinary.com/.../image.png",
                      hintStyle: TextStyle(color: Colors.white24),
                      prefixIcon: Icon(Icons.image, color: Colors.green),
                    ),
                  ),

                // Video URL Field (sirf Video type mein dikhe)
                if (giftType == "Video")
                  TextField(
                    controller: videoUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Video URL",
                      labelStyle: TextStyle(color: Colors.white54),
                      hintText: "https://res.cloudinary.com/.../video.mp4",
                      hintStyle: TextStyle(color: Colors.white24),
                      prefixIcon: Icon(Icons.videocam, color: Colors.blue),
                    ),
                  ),

                const SizedBox(height: 8),

                // Gift Name
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Gift Name",
                    labelStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.label, color: Colors.white54),
                  ),
                ),

                // Coin Price
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Coin Price",
                    labelStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.monetization_on, color: Colors.amberAccent),
                  ),
                ),

                const SizedBox(height: 8),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: const Color(0xFF1B1930),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Category",
                    labelStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.category, color: Colors.white54),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),

                const SizedBox(height: 6),

                // Global Gift Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.amberAccent,
                  title: Row(
                    children: const [
                      Icon(Icons.public, color: Colors.purpleAccent, size: 18),
                      SizedBox(width: 8),
                      Text("Global Gift", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  value: isGlobal,
                  onChanged: (value) => setDialogState(() => isGlobal = value),
                ),

                // Sound Effect Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.amberAccent,
                  title: Row(
                    children: const [
                      Icon(Icons.music_note, color: Colors.blueAccent, size: 18),
                      SizedBox(width: 8),
                      Text("Sound Effect", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  value: hasSound,
                  onChanged: (value) => setDialogState(() => hasSound = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save", style: TextStyle(color: Colors.amberAccent)),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final price = int.tryParse(priceController.text.trim());
    if (nameController.text.trim().isEmpty || price == null || price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid name and coin price")),
      );
      return;
    }

    // 🔥 Data prepare karein — sirf selected type ki value save hogi
    final Map<String, dynamic> data = {
      'name': nameController.text.trim(),
      'coinPrice': price,
      'category': category,
      'isGlobal': isGlobal,
      'hasSound': hasSound,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 🔥 Gift type ke hisaab se fields set karein
    if (giftType == "Emoji") {
      data['emoji'] = emojiController.text.trim().isEmpty ? "🎁" : emojiController.text.trim();
      data['imageUrl'] = null;
      data['videoUrl'] = null;
    } else if (giftType == "Image") {
      data['emoji'] = "🖼️";
      data['imageUrl'] = imageUrlController.text.trim();
      data['videoUrl'] = null;
    } else if (giftType == "Video") {
      data['emoji'] = "🎬";
      data['imageUrl'] = null;
      data['videoUrl'] = videoUrlController.text.trim();
    }

    if (existing == null) {
      await FirebaseFirestore.instance.collection('gift_catalog').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await existing.reference.update(data);
    }
  }

  Future<void> _deleteGift(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Gift?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Delete \"${doc.get('name')}\"?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1E),
        body: Center(child: Text("Access Denied", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1930),
        title: const Text("Gift Catalog"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: "Add sample gifts",
            onPressed: _seedSampleGifts,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openGiftForm(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gift_catalog')
            .orderBy('coinPrice')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amberAccent),
            );
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No gifts yet — tap + to add one",
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final hasVideo = data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty;
              final hasImage = data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // 🔥 Thumbnail
                    hasVideo
                        ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                            ),
                            child: const Icon(
                              Icons.play_circle_filled,
                              color: Colors.blueAccent,
                              size: 30,
                            ),
                          )
                        : hasImage
                            ? Image.network(
                                data['imageUrl'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Text(data['emoji'] ?? "🎁", style: const TextStyle(fontSize: 28)),
                              )
                            : Text(data['emoji'] ?? "🎁", style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? "",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                "${data['coinPrice']} coins",
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 🔥 Type Badge
                              if (hasVideo)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "VIDEO",
                                    style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else if (hasImage)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "IMAGE",
                                    style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "EMOJI",
                                    style: TextStyle(color: Colors.yellow, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              if (data['category'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    data['category'],
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              if (data['isGlobal'] == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.public, color: Colors.purpleAccent, size: 12),
                              ],
                              if (data['hasSound'] == true) ...[
                                const SizedBox(width: 2),
                                const Icon(Icons.music_note, color: Colors.blueAccent, size: 12),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                      onPressed: () => _openGiftForm(existing: doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: () => _deleteGift(doc),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}