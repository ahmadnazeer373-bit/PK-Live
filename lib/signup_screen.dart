import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'main_nav_screen.dart';
import 'complete_profile_screen.dart';
import 'widgets/app_logo.dart';

enum _SignupMode { email, phone }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  _SignupMode mode = _SignupMode.email;
  bool isLoading = false;
  bool obscurePassword = true;

  bool otpSent = false;
  String? _verificationId;
  String _fullPhoneNumber = "";

  // ---------------- Shared helpers ----------------

  /// Firestore transaction-based counter — thread-safe hai, agar do users
  /// ek sath signup karein to bhi clash nahi hoga. Starts at 1123456.
  Future<String> _getNextUserId() async {
    final counterRef = FirebaseFirestore.instance.collection('meta').doc('userIdCounter');

    final nextId = await FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int newId;
      if (!snapshot.exists) {
        newId = 1123456;
      } else {
        final lastId = (snapshot.data()?['lastId'] as num).toInt();
        newId = lastId + 1;
      }

      transaction.set(counterRef, {'lastId': newId});
      return newId;
    });

    return nextId.toString();
  }

  /// Agar is UID ka user doc pehle se nahi hai to naya bana deta hai
  /// (sequential userID ke sath) aur `true` (naya user) return karta hai.
  /// Agar pehle se exist karta hai (returning user, e.g. dobara Google se
  /// sign-in), to kuch nahi karta aur `false` return karta hai.
  Future<bool> _ensureUserDoc(User user, {String? name, String? phone}) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (existing.exists) return false;

    final userID = await _getNextUserId();
    await docRef.set({
      'uid': user.uid,
      'userID': userID,
      'name': name ?? user.displayName ?? '',
      'email': user.email ?? '',
      if (phone != null) 'phone': phone,
      'profileCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  void _goToApp({required bool isNewUser, String? name}) {
    if (!mounted) return;
    if (isNewUser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CompleteProfileScreen(initialName: name)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavScreen()),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- Email signup ----------------

  Future<void> _createAccountWithEmail() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showError("Fill in all fields");
      return;
    }

    setState(() => isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final isNewUser = await _ensureUserDoc(credential.user!, name: nameController.text.trim());
      _goToApp(isNewUser: isNewUser, name: nameController.text.trim());
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Couldn't create account");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- Google signup ----------------

  Future<void> _continueWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // user ne cancel kar diya
        setState(() => isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final isNewUser = await _ensureUserDoc(userCredential.user!);
      _goToApp(isNewUser: isNewUser, name: userCredential.user!.displayName);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Google sign-in failed");
    } catch (e) {
      _showError("Google sign-in failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- Phone signup ----------------

  Future<void> _sendOtp() async {
    if (nameController.text.trim().isEmpty || _fullPhoneNumber.trim().isEmpty) {
      _showError("Fill in both name and phone number");
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (phoneCredential) async {
          // Android par kabhi kabhi auto-verify ho jata hai
          final userCredential = await FirebaseAuth.instance.signInWithCredential(phoneCredential);
          final isNewUser = await _ensureUserDoc(
            userCredential.user!,
            name: nameController.text.trim(),
            phone: _fullPhoneNumber,
          );
          _goToApp(isNewUser: isNewUser, name: nameController.text.trim());
        },
        verificationFailed: (e) {
          _showError(e.message ?? "Verification failed");
          if (mounted) setState(() => isLoading = false);
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            otpSent = true;
            isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _showError("Something went wrong while sending the OTP: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _verifyOtpAndCreateAccount() async {
    if (_verificationId == null || otpController.text.trim().isEmpty) {
      _showError("Enter the OTP code");
      return;
    }

    setState(() => isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpController.text.trim(),
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final isNewUser = await _ensureUserDoc(
        userCredential.user!,
        name: nameController.text.trim(),
        phone: _fullPhoneNumber,
      );
      _goToApp(isNewUser: isNewUser, name: nameController.text.trim());
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Couldn't verify OTP");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

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
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.15)),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withOpacity(0.12)),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const AppLogo(size: 78),
                    const SizedBox(height: 16),
                    const Text(
                      "Create Account",
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Join PK Live and start streaming",
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 28),

                    // ---------- Mode switch: Email / Phone ----------
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _modeTab("Email", _SignupMode.email)),
                          Expanded(child: _modeTab("Phone Number", _SignupMode.phone)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ---------- Form card ----------
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: mode == _SignupMode.email ? _emailForm() : _phoneForm(),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _primaryAction(),
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
                                : Text(
                                    _primaryLabel(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text("OR", style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ---------- Google button ----------
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _continueWithGoogle,
                        icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                        label: const Text(
                          "Continue with Gmail",
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          backgroundColor: Colors.white.withOpacity(0.04),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback _primaryAction() {
    if (mode == _SignupMode.email) return _createAccountWithEmail;
    return otpSent ? _verifyOtpAndCreateAccount : _sendOtp;
  }

  String _primaryLabel() {
    if (mode == _SignupMode.email) return "Sign Up";
    return otpSent ? "Verify & Create Account" : "Send OTP";
  }

  Widget _modeTab(String label, _SignupMode value) {
    final isSelected = mode == value;
    return GestureDetector(
      onTap: () => setState(() {
        mode = value;
        otpSent = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _emailForm() {
    return Column(
      children: [
        _textField(controller: nameController, hint: "Name", icon: Icons.person_outline),
        const SizedBox(height: 18),
        _textField(controller: emailController, hint: "Email", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 18),
        _textField(
          controller: passwordController,
          hint: "Password",
          icon: Icons.lock_outline,
          obscure: obscurePassword,
          suffix: IconButton(
            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
            onPressed: () => setState(() => obscurePassword = !obscurePassword),
          ),
        ),
      ],
    );
  }

  Widget _phoneForm() {
    return Column(
      children: [
        _textField(controller: nameController, hint: "Name", icon: Icons.person_outline, enabled: !otpSent),
        const SizedBox(height: 18),
        IgnorePointer(
          ignoring: otpSent,
          child: Opacity(
            opacity: otpSent ? 0.5 : 1,
            child: IntlPhoneField(
              initialCountryCode: 'PK',
              style: const TextStyle(color: Colors.white),
              dropdownTextStyle: const TextStyle(color: Colors.white),
              dropdownIconPosition: IconPosition.trailing,
              flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: InputDecoration(
                hintText: "Phone Number",
                hintStyle: const TextStyle(color: Colors.white38),
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
              onChanged: (phone) {
                _fullPhoneNumber = phone.completeNumber;
              },
            ),
          ),
        ),
        if (otpSent) ...[
          const SizedBox(height: 18),
          _textField(controller: otpController, hint: "Enter OTP Code", icon: Icons.sms_outlined, keyboardType: TextInputType.number),
        ],
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    bool enabled = true,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.amberAccent),
        suffixIcon: suffix,
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
    );
  }
}