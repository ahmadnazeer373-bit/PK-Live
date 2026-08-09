import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LevelRulesScreen extends StatefulWidget {
  const LevelRulesScreen({super.key});

  @override
  State<LevelRulesScreen> createState() => _LevelRulesScreenState();
}

class _LevelRulesScreenState extends State<LevelRulesScreen> {
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  String _selectedType = 'sending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0B0B0F),
      appBar: AppBar(
        title: const Text("Level Rules"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAddRuleForm(),
            const SizedBox(height: 20),
            const Text(
              "Sending & Receiving Level Rules",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildRulesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRuleForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1B1D2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _levelController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Level",
                    labelStyle: TextStyle(color: Colors.white54),
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _minAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Min Amount",
                    labelStyle: TextStyle(color: Colors.white54),
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _colorController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Color (e.g., #FFD700)",
                    labelStyle: TextStyle(color: Colors.white54),
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      dropdownColor: const Color(0xff1B1D2A),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'sending', child: Text("Sending")),
                        DropdownMenuItem(value: 'receiving', child: Text("Receiving")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _addRule,
                  child: const Text("Add"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Sending"),
              Tab(text: "Receiving"),
            ],
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                _buildRuleListByType('sending'),
                _buildRuleListByType('receiving'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleListByType(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('level_rules')
          .where('type', isEqualTo: type)
          .orderBy('level')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                Text(
                  "No ${type == 'sending' ? 'Sending' : 'Receiving'} rules yet",
                  style: TextStyle(color: Colors.white38),
                ),
                const SizedBox(height: 8),
                Text(
                  "Add rules above",
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final colorHex = data['color'] ?? '#FFD700';
            Color color;
            try {
              color = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
            } catch (_) {
              color = Colors.amber;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff1B1D2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        data['level'].toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Level ${data['level']}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Min Amount: ${data['minAmount']}",
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteRule(docs[index].id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🔥 FIXED: type field properly set
  void _addRule() async {
    final level = int.tryParse(_levelController.text.trim());
    final minAmount = int.tryParse(_minAmountController.text.trim());
    final color = _colorController.text.trim();

    if (level == null || minAmount == null || color.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('level_rules').add({
        'level': level,
        'minAmount': minAmount,
        'color': color,
        'type': _selectedType,  // 🔥 IMPORTANT
        'createdAt': FieldValue.serverTimestamp(),
      });

      _levelController.clear();
      _minAmountController.clear();
      _colorController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ ${_selectedType == 'sending' ? 'Sending' : 'Receiving'} rule added"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteRule(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1B1D2A),
        title: const Text("Delete Rule?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure?", style: TextStyle(color: Colors.white70)),
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
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('level_rules').doc(id).delete();
    }
  }
}