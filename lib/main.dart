import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'data/gift_seed_data.dart';

// Same admin uid used in gift_catalog_admin_screen.dart
const String _adminUid = "1dd7eMMAm9dp6QqOzQsr5eJXPjB2";

// 🔥 NAYA: Global navigator key for video overlay
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Listens for login state. When the ADMIN account signs in, it checks
  // if `gift_catalog` is empty and auto-seeds it if so. Runs once per
  // sign-in, is a no-op for every other user, and never duplicates gifts
  // on repeat launches since checkAndSeedGiftCatalog() checks first.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null && user.uid == _adminUid) {
      checkAndSeedGiftCatalog();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🔥 NAYA: Required for full-screen video overlay
      title: 'PK Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}