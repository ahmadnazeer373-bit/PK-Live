import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../providers/vip_admin_provider.dart';
import 'vip_edit_screen.dart';

class VipAdminScreen extends StatefulWidget {
  const VipAdminScreen({super.key});

  @override
  State<VipAdminScreen> createState() => _VipAdminScreenState();
}

class _VipAdminScreenState extends State<VipAdminScreen> {
  final TextEditingController levelController = TextEditingController();
  final TextEditingController coinsController = TextEditingController();
  final TextEditingController benefitsController = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<VipAdminProvider>(
        context,
        listen: false,
      ).loadVipLevels();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vipProvider = Provider.of<VipAdminProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xff0B0B0F),

      appBar: AppBar(
        title: const Text(
          "VIP System Control",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _adminHeader(),
            const SizedBox(height: 25),

            const Text(
              "VIP Levels Management",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            vipProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                    ),
                  )
                : ListView.builder(
                    itemCount: vipProvider.vipLevels.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),

                    itemBuilder: (context, index) {
                      final vip = vipProvider.vipLevels[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xff3A2A00),
                              Color(0xff151515),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber,
                            width: 1,
                          ),
                        ),

                        child: Row(
                          children: [
                            Container(
                              height: 55,
                              width: 55,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber,
                              ),
                              child: Center(
                                child: Text(
                                  vip["level"]
                                      .toString()
                                      .replaceAll(
                                        "VIP ",
                                        "",
                                      ),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 15),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vip["level"] ?? "",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "Required Coins: ${vip["coins"]}",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Switch(
                              value: vip["status"] ?? false,
                              activeColor: Colors.amber,
                              onChanged: (value) async {
                                await vipProvider.updateVipLevel(
                                  id: vip["id"],
                                  data: {
                                    "status": value,
                                  },
                                );
                              },
                            ),

                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.amber,
                              ),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VipEditScreen(
                                      vipData: vip,
                                      index: index,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  vipProvider.loadVipLevels();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        icon: const Icon(
          Icons.add,
          color: Colors.black,
        ),
        label: const Text(
          "Add VIP Level",
          style: TextStyle(
            color: Colors.black,
          ),
        ),
        onPressed: () {
          _showAddVipDialog();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // 🔥 Admin Header
  Widget _adminHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Colors.amber,
            Colors.orange,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "VIP System Control",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Manage VIP levels and benefits",
            style: TextStyle(
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Add VIP Dialog
  void _showAddVipDialog() {
    levelController.clear();
    coinsController.clear();
    benefitsController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff17171C),
          title: const Text(
            "Add New VIP Level",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: levelController,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: "VIP Level Name",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: coinsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: "Required Coins",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: benefitsController,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: "Benefits (comma separated)",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              onPressed: () async {
                final provider = Provider.of<VipAdminProvider>(
                  context,
                  listen: false,
                );

                final benefits = benefitsController.text
                    .trim()
                    .split(",")
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                await provider.addVipLevel(
                  levelName: levelController.text.trim(),
                  requiredCoins: int.parse(
                    coinsController.text.trim(),
                  ),
                  benefits: benefits,
                );

                levelController.clear();
                coinsController.clear();
                benefitsController.clear();

                Navigator.pop(context);
              },
              child: const Text(
                "Save",
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}