import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'splash_screen.dart';
import 'data/gift_seed_data.dart';

import 'providers/vip_provider.dart';
import 'providers/vip_admin_provider.dart';


// Same admin uid used in gift_catalog_admin_screen.dart
const String _adminUid = "1dd7eMMAm9dp6QqOzQsr5eJXPjB2";


// Global navigator key for video overlay
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();


void main() async {

  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );



  // Auto seed gift catalog for admin account
  FirebaseAuth.instance.authStateChanges().listen((user) {

    if (user != null && user.uid == _adminUid) {

      checkAndSeedGiftCatalog();

    }

  });



  runApp(

    MultiProvider(

      providers: [


        // User VIP System
        ChangeNotifierProvider<VipProvider>(

          create: (_) => VipProvider(),

        ),



        // Admin VIP Control Panel
        ChangeNotifierProvider<VipAdminProvider>(

          create: (_) => VipAdminProvider(),

        ),


      ],


      child: const MyApp(),

    ),

  );

}




class MyApp extends StatelessWidget {

  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {


    return MaterialApp(


      navigatorKey: navigatorKey,


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