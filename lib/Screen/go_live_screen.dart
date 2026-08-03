import 'package:flutter/material.dart';

// Placeholder "Go Live" screen — opened when the center nav button is tapped.
// TODO: wire this up to your actual camera + streaming SDK
// (whatever live_room_screen.dart / party_screen.dart already use),
// so tapping "Start Streaming" here creates a live room and navigates
// into it the same way home_screen.dart does for existing hosts.
class GoLiveScreen extends StatelessWidget {
  const GoLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Go Live", style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, color: Colors.white24, size: 90),
            const SizedBox(height: 16),
            const Text(
              "Camera preview will appear here",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                // TODO: hook up actual camera + streaming logic here
              },
              child: const Text(
                "Start Streaming",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}