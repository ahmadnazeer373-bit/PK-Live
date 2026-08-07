import 'package:cloud_firestore/cloud_firestore.dart';

/// Bulk-add gifts to the `gift_catalog` collection in one go, instead of
/// adding them one-by-one through the admin dialog.
///
/// Matches the EXACT schema used by GiftCatalogAdminScreen / SendGiftSheet:
/// name, emoji, coinPrice, category, isGlobal, hasSound, createdAt.
/// Categories must be one of: "Event", "Hot", "VIP", "Customized"
/// (these are the only 4 tabs the send-gift sheet reads from).
///
/// HOW TO USE:
/// 1. Edit the `giftSeedList` below — add/remove/change gifts as you like.
/// 2. Call `seedGiftCatalog()` once (e.g. temporarily wire it to a button,
///    or call it from main() a single time), then remove the call.
/// 3. Re-running is safe-ish but will create duplicates since it just calls
///    .add() — if you re-run, delete old entries first or add a check.

final List<Map<String, dynamic>> giftSeedList = [
  // ---------- Hot ----------
  {'emoji': '🌹', 'name': 'Rose', 'coinPrice': 10, 'category': 'Hot', 'isGlobal': false, 'hasSound': false},
  {'emoji': '💋', 'name': 'Kiss', 'coinPrice': 20, 'category': 'Hot', 'isGlobal': false, 'hasSound': false},
  {'emoji': '🍫', 'name': 'Chocolate', 'coinPrice': 30, 'category': 'Hot', 'isGlobal': false, 'hasSound': false},
  {'emoji': '🎈', 'name': 'Balloon', 'coinPrice': 50, 'category': 'Hot', 'isGlobal': false, 'hasSound': false},
  {'emoji': '🧸', 'name': 'Teddy Bear', 'coinPrice': 80, 'category': 'Hot', 'isGlobal': false, 'hasSound': false},
  {'emoji': '🎁', 'name': 'Gift Box', 'coinPrice': 100, 'category': 'Hot', 'isGlobal': false, 'hasSound': false},

  // ---------- VIP ----------
  {'emoji': '👑', 'name': 'Crown', 'coinPrice': 500, 'category': 'VIP', 'isGlobal': true, 'hasSound': true},
  {'emoji': '💎', 'name': 'Diamond', 'coinPrice': 1000, 'category': 'VIP', 'isGlobal': true, 'hasSound': true},
  {'emoji': '🚗', 'name': 'Sports Car', 'coinPrice': 2000, 'category': 'VIP', 'isGlobal': true, 'hasSound': true},
  {'emoji': '🛥️', 'name': 'Yacht', 'coinPrice': 5000, 'category': 'VIP', 'isGlobal': true, 'hasSound': true},
  {'emoji': '✈️', 'name': 'Private Jet', 'coinPrice': 10000, 'category': 'VIP', 'isGlobal': true, 'hasSound': true},

  // ---------- Event ----------
  {'emoji': '🎉', 'name': 'Party Popper', 'coinPrice': 150, 'category': 'Event', 'isGlobal': true, 'hasSound': true},
  {'emoji': '🎆', 'name': 'Fireworks', 'coinPrice': 300, 'category': 'Event', 'isGlobal': true, 'hasSound': true},
  {'emoji': '🎂', 'name': 'Birthday Cake', 'coinPrice': 200, 'category': 'Event', 'isGlobal': false, 'hasSound': true},
  {'emoji': '🏆', 'name': 'Trophy', 'coinPrice': 400, 'category': 'Event', 'isGlobal': true, 'hasSound': false},

  // ---------- Customized ----------
  {'emoji': '💌', 'name': 'Love Letter', 'coinPrice': 60, 'category': 'Customized', 'isGlobal': false, 'hasSound': false},
  {'emoji': '🌟', 'name': 'Star', 'coinPrice': 90, 'category': 'Customized', 'isGlobal': false, 'hasSound': false},
];

/// Writes every gift in [giftSeedList] to Firestore using a batch write
/// (single network round-trip instead of N separate .add() calls).
Future<void> seedGiftCatalog() async {
  final collection = FirebaseFirestore.instance.collection('gift_catalog');
  final batch = FirebaseFirestore.instance.batch();

  for (final gift in giftSeedList) {
    final docRef = collection.doc(); // auto-generated id
    batch.set(docRef, {
      ...gift,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}

/// Safe wrapper: only seeds if `gift_catalog` is currently EMPTY.
/// This makes it safe to call automatically every time the admin logs in —
/// it will never create duplicate gifts on repeat app launches.
Future<void> checkAndSeedGiftCatalog() async {
  final snapshot =
      await FirebaseFirestore.instance.collection('gift_catalog').limit(1).get();

  if (snapshot.docs.isEmpty) {
    await seedGiftCatalog();
  }
}