import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'status_screen.dart';
import 'profile_screen.dart';
import 'screen/notification_screen.dart';
import 'Screen/go_live_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const StatusScreen(),
      const GoLiveScreen(),        // 🔥 Index 2 - Live Screen
      const NotificationScreen(),
      ProfileScreen(
        targetUserId: _auth.currentUser?.uid,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: const Color(0xFF0D0B1E),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amberAccent,
        unselectedItemColor: Colors.white38,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: '',
          ),
          // 🔥 LIVE BUTTON - Center
          BottomNavigationBarItem(
            icon: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.live_tv,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            activeIcon: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.live_tv,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            label: '',
          ),
          _buildMessageItem(),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '',
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildMessageItem() {
    return BottomNavigationBarItem(
      icon: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .doc(_auth.currentUser?.uid)
            .collection('items')
            .where('read', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = 0;
          if (snapshot.hasData) {
            unreadCount = snapshot.data!.docs.length;
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.message_outlined),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      activeIcon: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .doc(_auth.currentUser?.uid)
            .collection('items')
            .where('read', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = 0;
          if (snapshot.hasData) {
            unreadCount = snapshot.data!.docs.length;
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.message),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      label: '',
    );
  }
}