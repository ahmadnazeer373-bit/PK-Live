import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // 🔥 IMPORTANT

import '../providers/vip_provider.dart';
import '../widgets/vip_card.dart';
import '../widgets/vip_progress_bar.dart';
import '../widgets/vip_benefit_item.dart';
import '../widgets/vip_level_item.dart';

class VipCenterScreen extends StatefulWidget {
  const VipCenterScreen({super.key});

  @override
  State<VipCenterScreen> createState() => _VipCenterScreenState();
}

class _VipCenterScreenState extends State<VipCenterScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final provider = Provider.of<VipProvider>(context, listen: false);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final totalCoins = (userDoc.data()?['coins'] ?? 0) as int;
        
        await provider.refresh(totalRecharge: totalCoins);
        provider.startListening(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VipProvider>(
      builder: (context, vip, child) {
        return Scaffold(
          backgroundColor: const Color(0xff0F1018),

          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            title: const Text(
              "VIP Center",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),

          body: vip.isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VipCard(
                          vip: vip.currentVip,
                          totalRecharge: vip.totalRecharge,
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "VIP Progress",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),

                        VipProgressBar(
                          progress: vip.progress,
                        ),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${vip.totalRecharge} Coins",
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              vip.nextVip == null
                                  ? "MAX VIP"
                                  : "Next : VIP ${vip.nextVip!.level}",
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        const Text(
                          "VIP Privileges",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (vip.currentVip != null)
                          ...vip.currentVip!.benefits.map(
                            (benefit) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: VipBenefitItem(
                                title: benefit,
                              ),
                            ),
                          ),
                        const SizedBox(height: 30),

                        const Text(
                          "VIP Levels",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: vip.vipLevels.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = vip.vipLevels[index];
                            final unlocked = vip.userVipLevel >= item.level;
                            final current = vip.userVipLevel == item.level;

                            return VipLevelItem(
                              vip: item,
                              isUnlocked: unlocked,
                              isCurrent: current,
                            );
                          },
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              /// Store Screen Coming Soon
                            },
                            child: const Text(
                              "Recharge to Upgrade VIP",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        Center(
                          child: Text(
                            vip.currentVip == null
                                ? "Become VIP Today!"
                                : "Current VIP : ${vip.currentVip!.title}",
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    final provider = Provider.of<VipProvider>(context, listen: false);
    provider.stopListening();
    super.dispose();
  }
}