import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'Screen/message_inbox_screen.dart';
import 'profile_screen.dart';
import 'status_screen.dart';
import 'Screen/go_live_screen.dart';
import 'widgets/bottom_bar.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int currentIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    StatusScreen(),
    MessageInboxScreen(),
    ProfileScreen(),
  ];

  void _openGoLive() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoLiveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() => currentIndex = index);
        },
        onLiveTap: _openGoLive,
      ),
    );
  }
}