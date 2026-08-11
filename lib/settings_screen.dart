import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_screen.dart';

// NOTE: Replace the [Insert ...] placeholders inside _termsAndConditionsText
// below (date, jurisdiction, support email) with your actual details before
// publishing. This text is a template, not legal advice — have a lawyer
// review it before launch.

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1930),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Do you want to sign out?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't sign out: $e")),
        );
      }
    }
  }

  // TEMPORARY ADMIN FUNCTION — recalculates followersCount/followingCount
  // for every user from the actual following/followers subcollection data,
  // fixing any counts that drifted out of sync during earlier testing.
  // Remove this button + function once counts are confirmed correct.
  Future<void> _recalculateAllCounts(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1B1930),
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                "Recalculating counts...",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    final firestore = FirebaseFirestore.instance;
    int processed = 0;
    String? errorMessage;

    try {
      final usersSnap = await firestore.collection('users').get();

      for (final userDoc in usersSnap.docs) {
        final userId = userDoc.id;

        final followingSnap = await firestore
            .collection('users')
            .doc(userId)
            .collection('following')
            .get();
        final followingCount = followingSnap.docs.length;

        final followersSnap = await firestore
            .collectionGroup('following')
            .where('targetUserId', isEqualTo: userId)
            .get();
        final followersCount = followersSnap.docs.length;

        await firestore.collection('users').doc(userId).update({
          'followingCount': followingCount,
          'followersCount': followersCount,
        });

        processed++;
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // close the progress dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage == null
              ? "Fixed counts for $processed users"
              : "Stopped after $processed users — error: $errorMessage",
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _settingsRow(
            context,
            Icons.description_outlined,
            "Terms & Conditions",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const _StaticInfoScreen(
                  title: "Terms & Conditions",
                  body: _termsAndConditionsText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _settingsRow(
            context,
            Icons.mic_external_on_outlined,
            "Host Rules",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const _StaticInfoScreen(
                  title: "Host Rules",
                  body: _hostRulesText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _settingsRow(
            context,
            Icons.dashboard_customize_outlined,
            "Agency Rules",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const _StaticInfoScreen(
                  title: "Agency Rules",
                  body: _agencyRulesText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                "Sign Out",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // TEMPORARY — remove this button once follower/following counts
          // are confirmed correct for all users. See _recalculateAllCounts.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _recalculateAllCounts(context),
              icon: const Icon(Icons.build_outlined, color: Colors.amber),
              label: const Text(
                "Fix Follower/Following Counts (Admin)",
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.amber),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StaticInfoScreen extends StatelessWidget {
  final String title;
  final String body;

  const _StaticInfoScreen({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(body, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
      ),
    );
  }
}

const String _termsAndConditionsText = '''
Last updated: 01/09/2026

1. ACCEPTANCE OF TERMS

By creating a PK Live account, you confirm that you have read, understood, and agree to be bound by these Terms & Conditions ("Terms"), along with our Privacy Policy. If you do not agree with these Terms, you may not access or use the PK Live application ("the App", "the Service").

These Terms constitute a legally binding agreement between you ("User", "you") and PK Live ("the Company", "we", "us", "our").

2. ELIGIBILITY

- You must be at least 18 years of age, or the age of majority in your jurisdiction, whichever is higher, to create an account or use the Service.
- By registering, you represent and warrant that you meet this age requirement and have the legal capacity to enter into these Terms.
- You must provide accurate, current, and complete information when creating your account. Impersonation or use of false identity information is strictly prohibited.
- We reserve the right to request age or identity verification at any time and to suspend or terminate accounts that fail to provide satisfactory verification.

3. ACCOUNT RESPONSIBILITY

- You are solely responsible for maintaining the confidentiality of your account credentials (including password and any linked sign-in methods).
- You are responsible for all activity that occurs under your account, whether or not authorized by you.
- Sharing, selling, transferring, or allowing another person to use your account is strictly prohibited.
- You must notify us immediately of any unauthorized access to or use of your account.

4. COMMUNITY GUIDELINES

The following conduct and content are strictly prohibited on PK Live:

- Nudity, sexually explicit, or sexually suggestive content
- Hate speech, discrimination, or content targeting individuals or groups based on race, religion, ethnicity, gender, sexual orientation, disability, or nationality
- Harassment, bullying, threats, or intimidation of any kind
- Violence, incitement to violence, or promotion of illegal activities
- Fake identities, impersonation, or misleading profile information
- Spam, scams, phishing, or fraudulent schemes
- Infringement of copyright, trademark, or other intellectual property rights
- Any content or conduct that violates applicable local, national, or international law

We reserve the right, at our sole discretion, to remove content, restrict features, suspend, or permanently ban any account found in violation of these guidelines, without prior notice.

5. VIRTUAL COINS & GIFTS

- PK Live Coins ("Coins") are a virtual currency usable exclusively within the App to purchase virtual items and send virtual gifts to other users.
- Coins have no cash value, are not legal tender, and cannot be exchanged, transferred, or redeemed for real money outside of the mechanisms explicitly provided by the Company (such as an approved host wallet system).
- Coins are non-transferable between user accounts except through features explicitly designed for that purpose within the App.
- Any misuse, manipulation, or fraudulent acquisition or use of Coins may result in forfeiture of Coins and suspension or termination of the associated account.

6. REFUND POLICY

- Coins and virtual gifts are non-refundable, except where required by applicable consumer protection law or as otherwise expressly stated in Company policy.
- Purchases made through third-party app stores (e.g., Google Play, Apple App Store) are subject to the refund policies of those platforms in addition to this policy.
- The Company is not obligated to issue refunds for Coins lost due to account suspension or termination resulting from a violation of these Terms.

7. SUSPENSION & TERMINATION

- The Company reserves the right to issue warnings, temporarily suspend, or permanently terminate any account, at its sole discretion, for violation of these Terms, the Host Rules, the Agency Rules, or applicable law.
- Upon termination, your right to use the Service ceases immediately. The Company is not liable for any loss of virtual items, Coins, or content resulting from suspension or termination due to a violation of these Terms.
- You may request deletion of your account and associated data at any time, subject to our data retention obligations under applicable law and our Privacy Policy.

8. PRIVACY

Your personal data is collected, processed, and stored in accordance with our Privacy Policy, which forms an integral part of these Terms. By using the App, you consent to such collection and processing.

9. THIRD-PARTY SERVICES

The App relies on third-party service providers (including, but not limited to, cloud hosting, authentication, analytics, and real-time communication providers) to operate certain features. Your use of the App may be subject to the terms and privacy practices of those providers in addition to this document. The Company is not responsible for the acts or omissions of independent third-party providers.

10. DISCLAIMER OF WARRANTIES

The Service is provided on an "as is" and "as available" basis, without warranties of any kind, whether express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, non-infringement, or uninterrupted and error-free operation. The Company does not guarantee that the Service will be free from bugs, vulnerabilities, or interruptions.

11. LIMITATION OF LIABILITY

To the maximum extent permitted by applicable law, the Company, its officers, employees, and affiliates shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, data, goodwill, or virtual items, arising out of or in connection with your use of, or inability to use, the Service.

12. INDEMNIFICATION

You agree to indemnify and hold harmless the Company, its officers, employees, and affiliates from any claims, damages, losses, liabilities, and expenses (including reasonable legal fees) arising out of your violation of these Terms, your misuse of the Service, or your infringement of any third party's rights.

13. CHANGES TO THESE TERMS

The Company may update or modify these Terms at any time. Material changes will be communicated through the App or by other reasonable means. Continued use of the Service after changes take effect constitutes your acceptance of the revised Terms.

14. GOVERNING LAW & DISPUTE RESOLUTION

These Terms shall be governed by and construed in accordance with the laws of Pakistan, without regard to its conflict of law principles. Any disputes arising under these Terms shall be subject to the exclusive jurisdiction of the courts located in Lahore, unless otherwise required by applicable consumer protection law.

15. SEVERABILITY

If any provision of these Terms is found to be invalid or unenforceable, the remaining provisions shall continue in full force and effect.

16. CONTACT US

For questions regarding these Terms, please contact us at: ahmadnazeer373@gmail.com

WALLET POLICY

- Wallet functionality is available exclusively to approved, verified hosts.
- Only earnings deemed eligible under Company policy will be credited to a host's wallet.
- Withdrawal or settlement of wallet balances is subject to identity verification and Company policy, including applicable processing timelines and minimum withdrawal thresholds.
- The Company reserves the right to review, delay, or decline any transaction it deems suspicious, fraudulent, or in violation of these Terms, pending investigation.

COIN POLICY

- PK Live Coins are a proprietary virtual currency issued and controlled by the Company.
- Coins do not constitute legal tender, currency, or any form of financial instrument, and hold no monetary value outside the PK Live ecosystem.
- Coins may be used exclusively within the App as permitted by the Company.
- The Company reserves the right to modify Coin packages, pricing, and availability at any time, without prior notice, at its sole discretion.

PRIVACY & SAFETY

- All users have access to Report and Block features to flag inappropriate content or conduct.
- The Company reserves the right to remove content, restrict accounts, or take other corrective action in response to reports or its own review.
- The Company may review live streams, messages, and reported content for moderation and safety purposes, in accordance with its Privacy Policy and applicable law.
- Users under investigation for safety concerns may have their access to certain features temporarily restricted pending review.

INTELLECTUAL PROPERTY

All intellectual property associated with PK Live, including but not limited to its logo, name and branding, app design and user interface, source code, graphics, animations and visual assets, and virtual gifts and in-app items, is the exclusive property of the Company and is protected under applicable intellectual property laws. No part of this intellectual property may be copied, reproduced, distributed, modified, or reused in any form without the Company's prior written permission.

This document is provided as a general template and does not constitute legal advice. Please consult a qualified attorney in your jurisdiction before publishing these Terms, particularly regarding age-of-majority requirements, virtual currency regulations, consumer protection law, and data protection/privacy law applicable to your user base.
''';

const String _hostRulesText = '''
1. AGENCY VERIFICATION

Every host must be affiliated with an approved agency before being granted live streaming ("Go Live") privileges on the Service.

2. PROFILE VERIFICATION

Hosts must complete their profile and submit all required verification documents (including a valid government-issued ID and address) as requested by the Company or their affiliated agency.

3. LIVE STREAMING CONDUCT

While streaming, hosts must:

- Use respectful and appropriate language at all times
- Refrain from streaming illegal, adult, or sexually explicit content
- Refrain from organizing fake giveaways, contests, or any fraudulent promotional activity
- Comply with all Community Guidelines set out in the Terms & Conditions

4. GIFTS & EARNINGS

- Gifts received during live streams count toward the host's performance target as defined by Company or agency policy.
- Eligible earnings will be transferred to the host's wallet in accordance with Company policy and applicable payment processing timelines.
- Earnings associated with fraudulent, manipulated, or suspicious activity may be held, withheld, or forfeited pending investigation.

5. MONTHLY PERFORMANCE TARGET

Hosts are required to meet a minimum monthly performance target as communicated by the Company or their agency. Failure to meet this target may result in:

- A formal warning
- Reduction of host benefits or privileges
- Temporary suspension of live streaming privileges

6. MULTIPLE ACCOUNTS

A host may not operate, control, or benefit from multiple earning accounts. Violation of this rule may result in suspension or termination of all associated accounts.

7. ACCOUNT OWNERSHIP

Host accounts are personal and non-transferable. Selling, leasing, or otherwise transferring a host account to another individual or entity is strictly prohibited.
''';

const String _agencyRulesText = '''
1. REGISTRATION

Agency owners must submit a valid government-issued ID and any other documentation required by the Company as part of the agency application and approval process.

2. HOST RECRUITMENT

Agencies are responsible for recruiting genuine, verified individuals as hosts and must not recruit fictitious, duplicate, or misrepresented accounts.

3. TRAINING & COMPLIANCE

Agencies are responsible for ensuring that their affiliated hosts understand and comply with the Terms & Conditions, the Host Rules, and all Community Guidelines.

4. MONTHLY PERFORMANCE

Agencies must maintain a minimum monthly performance standard, as defined by Company policy, based on the aggregate activity of their affiliated hosts.

5. FRAUD POLICY

Agencies found to be recruiting fake hosts, generating artificial engagement, or facilitating fraudulent gifting activity are subject to suspension or permanent termination of their agency status, in addition to any other remedies available to the Company.

6. COMMISSION

Agency commission rates are determined by Company policy and may be updated from time to time. Any changes will be communicated to affected agencies in advance where reasonably practicable.

7. RESPONSIBILITY FOR HOSTS

Agencies are responsible for the conduct of their affiliated hosts on the platform and may be held accountable, including through suspension or termination of agency status, for repeated or serious violations committed by hosts under their management.
''';