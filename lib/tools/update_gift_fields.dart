// lib/tools/update_gift_fields.dart
// Is file ko sirf EK BAAR run karna hai

import 'package:flutter/material.dart'; // 🔥 IMPORTANT
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;
  final snapshot = await db.collection('gift_catalog').get();
  
  final batch = db.batch();
  int count = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();
    
    // 🔥 Sirf un fields ko update karein jo missing hain
    final Map<String, dynamic> updates = {};
    
    if (!data.containsKey('imageUrl')) {
      updates['imageUrl'] = null;
    }
    if (!data.containsKey('videoUrl')) {
      updates['videoUrl'] = null;
    }
    
    if (updates.isNotEmpty) {
      batch.update(doc.reference, updates);
      count++;
    }
  }

  if (count > 0) {
    await batch.commit();
    print('✅ $count gifts updated successfully!');
  } else {
    print('✅ All gifts already have imageUrl and videoUrl fields!');
  }
}