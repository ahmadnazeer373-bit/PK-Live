import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/vip_service.dart';
import '../vip_utils.dart';

class AdminCoinTopupScreen extends StatefulWidget {
  const AdminCoinTopupScreen({super.key});

  @override
  State<AdminCoinTopupScreen> createState() => _AdminCoinTopupScreenState();
}

class _AdminCoinTopupScreenState extends State<AdminCoinTopupScreen> {
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  Future<void> _searchUser() async {
    final userId = _uidController.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a User ID")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('userID', isEqualTo: userId)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        setState(() {
          _userData = {
            'uid': doc.id,
            'name': data['name'] ?? 'Unknown User',
            'userID': data['userID'] ?? '',
            'vipLevel': data['vipLevel'] ?? 0,
            'coins': data['coins'] ?? 0,
            'totalRecharge': data['totalRecharge'] ?? 0,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ User found: ${_userData!['name']} (ID: ${_userData!['userID']})"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _userData = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ User not found. Check ID."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCoins() async {
    if (_userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please search a user first")),
      );
      return;
    }

    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _userData!['uid'];
      final currentTotalRecharge = (_userData!['totalRecharge'] ?? 0) as int;
      final newTotalRecharge = currentTotalRecharge + amount;

      // 🔥 Calculate new VIP Level based on totalRecharge
      final newVipLevel = vipLevelForCoinsSync(newTotalRecharge);

      print("🔥 Current Total Recharge: $currentTotalRecharge");
      print("🔥 Adding: $amount");
      print("🔥 New Total Recharge: $newTotalRecharge");
      print("🔥 New VIP Level: $newVipLevel");

      // 🔥 Update coins, totalRecharge, AND vipLevel
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'coins': FieldValue.increment(amount),
        'totalRecharge': newTotalRecharge,
        'vipLevel': newVipLevel,
      });

      // 🔥 Refresh user data
      await _refreshUserData(uid);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Added $amount coins! VIP Level: $newVipLevel"),
          backgroundColor: Colors.green,
        ),
      );

      _amountController.clear();
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshUserData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _userData = {
            'uid': uid,
            'name': data['name'] ?? 'Unknown User',
            'userID': data['userID'] ?? '',
            'vipLevel': data['vipLevel'] ?? 0,
            'coins': data['coins'] ?? 0,
            'totalRecharge': data['totalRecharge'] ?? 0,
          };
        });
      }
    } catch (e) {
      print("❌ Refresh error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0B0F),
      appBar: AppBar(
        title: const Text("Admin: Coin Top-Up"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _uidController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter User ID (e.g., 777737)",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xff1B1D2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _searchUser,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text("Search"),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_userData != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff1B1D2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _infoRow("Name", _userData!['name'] ?? 'Unknown'),
                    _infoRow("User ID", _userData!['userID'] ?? 'N/A'),
                    _infoRow("Current VIP", "${_userData!['vipLevel'] ?? 0}"),
                    _infoRow("Current Coins", "${_userData!['coins'] ?? 0}"),
                    _infoRow("Total Recharge", "${_userData!['totalRecharge'] ?? 0}"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter Coins Amount",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xff1B1D2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.monetization_on, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _addCoins,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Add Coins & Auto-Update VIP",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
            if (_userData == null) ...[
              const Spacer(),
              const Center(
                child: Text(
                  "Search a user by their User ID (e.g., 777737)",
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}