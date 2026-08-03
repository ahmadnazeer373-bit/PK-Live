import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IncomeDetailScreen extends StatefulWidget {
  const IncomeDetailScreen({super.key});

  @override
  State<IncomeDetailScreen> createState() => _IncomeDetailScreenState();
}

class _IncomeDetailScreenState extends State<IncomeDetailScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month),
      helpText: "Select Month",
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.amberAccent, surface: Color(0xFF1B1930)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = user?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1E),
        body: Center(child: Text("Login required", style: TextStyle(color: Colors.white))),
      );
    }

    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B1E),
        elevation: 0,
        title: const Text("Income Detail", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gift_transactions')
            .where('receiverUid', isEqualTo: uid)
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(monthEnd))
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final totalIncome = docs.fold<int>(0, (sum, d) => sum + ((d.get('coinPrice') as num).toInt()));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------- Month selector ----------
              GestureDetector(
                onTap: _pickMonth,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white54),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------- Total income card ----------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFF3B1E7A)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total Income", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 20),
                        const SizedBox(width: 6),
                        Text("$totalIncome", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(label: "Basic Salary", value: "0"),
                        ),
                        Expanded(
                          child: _MiniStat(label: "Bonus", value: "0"),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        "Basic Salary & Bonus structure coming soon",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text("Income Source", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text("Gifts", style: TextStyle(color: Colors.white70, fontSize: 13))),
                    Text("$totalIncome coins", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text("Recent Gifts Received", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
                )
              else if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text("No gifts received this month", style: TextStyle(color: Colors.white38))),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['giftName'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 13)),
                              if (createdAt != null)
                                Text(
                                  DateFormat('dd MMM, hh:mm a').format(createdAt),
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        Text("+${data['coinPrice']}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}