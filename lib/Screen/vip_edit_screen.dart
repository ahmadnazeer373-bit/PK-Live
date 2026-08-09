import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../providers/vip_admin_provider.dart';

class VipEditScreen extends StatefulWidget {
  final Map<String, dynamic> vipData;
  final int index;

  const VipEditScreen({
    super.key,
    required this.vipData,
    required this.index,
  });

  @override
  State<VipEditScreen> createState() => _VipEditScreenState();
}

class _VipEditScreenState extends State<VipEditScreen> {
  late TextEditingController _levelNameController;
  late TextEditingController _coinsController;
  late TextEditingController _benefitsController;
  late TextEditingController _dailyRewardController;
  late TextEditingController _badgeController;
  late TextEditingController _frameController;
  late TextEditingController _entryController;
  late TextEditingController _bubbleController;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.vipData;

    // 🔥 Benefits ko String mein convert karein agar List hai
    String benefitsString = '';
    if (data['benefits'] != null) {
      if (data['benefits'] is List) {
        benefitsString = (data['benefits'] as List).join(', ');
      } else {
        benefitsString = data['benefits'].toString();
      }
    }

    _levelNameController = TextEditingController(text: data['level'] ?? '');
    _coinsController = TextEditingController(text: (data['coins'] ?? 0).toString());
    _benefitsController = TextEditingController(text: benefitsString);
    _dailyRewardController = TextEditingController(text: (data['dailyReward'] ?? 0).toString());
    
    // 🔥 DEFAULT VALUES - Agar Firebase mein fields nahi hain toh yeh use honge
    _badgeController = TextEditingController(
      text: data['badge']?.toString() ?? '1',
    );
    _frameController = TextEditingController(
      text: data['frame']?.toString() ?? 'gold',
    );
    _entryController = TextEditingController(
      text: data['entry']?.toString() ?? '✨',
    );
    _bubbleController = TextEditingController(
      text: data['bubble']?.toString() ?? '#FFD700',
    );
    
    _isActive = data['status'] ?? false;
  }

  @override
  void dispose() {
    _levelNameController.dispose();
    _coinsController.dispose();
    _benefitsController.dispose();
    _dailyRewardController.dispose();
    _badgeController.dispose();
    _frameController.dispose();
    _entryController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final levelName = _levelNameController.text.trim();
    final coins = int.tryParse(_coinsController.text.trim());
    final dailyReward = int.tryParse(_dailyRewardController.text.trim());

    if (levelName.isEmpty || coins == null || dailyReward == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<VipAdminProvider>(context, listen: false);

      // 🔥 Benefits ko List<String> mein convert karein
      List<String> benefitsList = [];
      if (_benefitsController.text.trim().isNotEmpty) {
        benefitsList = _benefitsController.text
            .trim()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final Map<String, dynamic> updatedData = {
        'level': levelName,
        'coins': coins,
        'dailyReward': dailyReward,
        'benefits': benefitsList,
        'badge': _badgeController.text.trim(),
        'frame': _frameController.text.trim(),
        'entry': _entryController.text.trim(),
        'bubble': _bubbleController.text.trim(),
        'status': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await provider.updateVipLevel(
        id: widget.vipData['id'],
        data: updatedData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ VIP Level updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to update: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0B0F),
      appBar: AppBar(
        title: Text(
          "Edit ${widget.vipData['level'] ?? 'VIP'}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.amber),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              controller: _levelNameController,
              label: "VIP Level Name",
              icon: Icons.stars,
              required: true,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _coinsController,
              label: "Required Coins",
              icon: Icons.monetization_on,
              keyboardType: TextInputType.number,
              required: true,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _dailyRewardController,
              label: "Daily Reward Coins",
              icon: Icons.emoji_events,
              keyboardType: TextInputType.number,
              required: true,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _benefitsController,
              label: "Benefits (comma separated)",
              icon: Icons.list_alt,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            const Divider(color: Colors.white24),
            const SizedBox(height: 12),

            const Text(
              "VIP Perks",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _badgeController,
              label: "Badge",
              icon: Icons.verified,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _frameController,
              label: "Frame",
              icon: Icons.crop_3_2,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _entryController,
              label: "Entry",
              icon: Icons.login,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _bubbleController,
              label: "Chat Bubble",
              icon: Icons.chat_bubble_outline,
            ),
            const SizedBox(height: 24),

            // 🔥 Status Switch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff1B1D2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isActive ? Icons.check_circle : Icons.block,
                        color: _isActive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "VIP Level Status",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isActive,
                    activeColor: Colors.amber,
                    onChanged: (value) {
                      setState(() => _isActive = value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🔥 Save Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xff1B1D2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          labelStyle: TextStyle(
            color: required ? Colors.amber : Colors.white54,
          ),
          prefixIcon: Icon(icon, color: Colors.amber),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}