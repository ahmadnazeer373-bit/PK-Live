import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'main_nav_screen.dart';
import 'widgets/app_logo.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String? initialName;

  const CompleteProfileScreen({super.key, this.initialName});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final TextEditingController nameController;
  final TextEditingController ageController = TextEditingController();

  String? selectedGender; // "Male" | "Female"
  Country? selectedCountry;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.initialName ?? FirebaseAuth.instance.currentUser?.displayName ?? "",
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF1B1930),
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        inputDecoration: InputDecoration(
          hintText: "Search country",
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      onSelect: (country) {
        setState(() => selectedCountry = country);
      },
    );
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (nameController.text.trim().isEmpty) {
      _showError("Enter your name");
      return;
    }
    final age = int.tryParse(ageController.text.trim());
    if (age == null || age <= 0) {
      _showError("Enter a valid age");
      return;
    }
    if (selectedGender == null) {
      _showError("Select your gender");
      return;
    }
    if (selectedCountry == null) {
      _showError("Select your country");
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': nameController.text.trim(),
        'age': age,
        'gender': selectedGender,
        'country': selectedCountry!.name,
        'profileCompleted': true,
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavScreen()),
        (route) => false,
      );
    } catch (e) {
      _showError("Couldn't save: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _genderChip(String label) {
    final isSelected = selectedGender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedGender = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]) : null,
            color: isSelected ? null : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0B1E), Color(0xFF2B1055), Color(0xFF7597DE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Center(child: AppLogo(size: 70)),
                const SizedBox(height: 16),
                const Text(
                  "Complete Your Profile",
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Just a few more details — then you're ready",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 26),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Name",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.amberAccent),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.amberAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Age",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.cake_outlined, color: Colors.amberAccent),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.amberAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _genderChip("Male"),
                          const SizedBox(width: 12),
                          _genderChip("Female"),
                        ],
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _openCountryPicker,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.public, color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selectedCountry == null
                                      ? "Select Country"
                                      : "${selectedCountry!.flagEmoji}  ${selectedCountry!.name}",
                                  style: TextStyle(
                                    color: selectedCountry == null ? Colors.white38 : Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.white38),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                "Continue",
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}