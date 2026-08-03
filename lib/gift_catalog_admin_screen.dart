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

  Future<void> _openGiftForm({DocumentSnapshot? existing}) async {
    final nameController = TextEditingController(text: existing?.get('name') ?? '');
    final emojiController = TextEditingController(text: existing?.get('emoji') ?? '🎁');
    final priceController = TextEditingController(
      text: existing != null ? existing.get('coinPrice').toString() : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? "Add Gift" : "Edit Gift", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emojiController,
              style: const TextStyle(color: Colors.white, fontSize: 22),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: "Emoji", labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Gift Name", labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Coin Price", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
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

    final data = {
      'name': nameController.text.trim(),
      'emoji': emojiController.text.trim().isEmpty ? "🎁" : emojiController.text.trim(),
      'coinPrice': price,
      'updatedAt': FieldValue.serverTimestamp(),
    };

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
        content: Text("Delete \"${doc.get('name')}\"?", style: const TextStyle(color: Colors.white70)),
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
            icon: const Icon(Icons.add),
            onPressed: () => _openGiftForm(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('gift_catalog').orderBy('coinPrice').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("No gifts yet \u2014 tap + to add one", style: TextStyle(color: Colors.white38)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(doc.get('emoji') ?? "🎁", style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.get('name') ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          Text("${doc.get('coinPrice')} coins", style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
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