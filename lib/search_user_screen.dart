import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'profile_screen.dart';

/// Push this screen when the user taps the search icon on the home page:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchUserScreen()));
class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final _controller = TextEditingController();
  final _firestore = FirebaseFirestore.instance;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _searched = true;
    });

    try {
      // 🔥 EXACT MATCH search on userID (not prefix search)
      final snap = await _firestore
          .collection('users')
          .where('userID', isEqualTo: query)
          .limit(30)
          .get();

      if (!mounted) return;
      setState(() {
        _results = snap.docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Search by ID...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_searched) {
      return const Center(
        child: Text('Type a user ID and press search',
            style: TextStyle(color: Colors.grey)),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No user found with that ID',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final doc = _results[index];
        final data = doc.data();
        final name = (data['name'] ?? data['displayName'] ?? 'User').toString();
        final userID = (data['userID'] ?? '').toString();
        final avatarUrl = (data['avatarUrl'] ?? '').toString();
        final gender = (data['gender'] ?? '').toString().toLowerCase();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          title: Text(name),
          subtitle: Text('ID: $userID'),
          trailing: Icon(
            gender == 'female' ? Icons.female : Icons.male,
            color: gender == 'female' ? Colors.pinkAccent : Colors.blueAccent,
          ),
          // 🔥 CHANGED: Popup ki jagah full ProfileScreen open karein
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(targetUserId: doc.id),
              ),
            );
          },
        );
      },
    );
  }
}