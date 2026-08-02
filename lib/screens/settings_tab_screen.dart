import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/account_repository.dart';
import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';
import 'profile_screen.dart';

class SettingsTabScreen extends StatefulWidget {
  const SettingsTabScreen({super.key});

  @override
  State<SettingsTabScreen> createState() => _SettingsTabScreenState();
}

class _SettingsTabScreenState extends State<SettingsTabScreen> {
  late final Map<String, String>? _account = AccountRepository.currentAccount();

  Future<void> _logOut() async {
    await AccountRepository.logOut();
    AccountSession.loggedIn.value = false;
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every saved resume, cover letter, and proposal on this '
          'device. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Firebase persists its own session independently of SharedPreferences,
    // so clearing local storage alone would leave the account signed in —
    // sign out explicitly so "Clear Everything" actually starts fresh.
    await AccountRepository.logOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared.')),
      );
    }
    AccountSession.loggedIn.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final sectionLabel = Theme.of(context).textTheme.labelLarge;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ValueListenableBuilder<SubscriptionTier>(
              valueListenable: SubscriptionSession.tier,
              builder: (context, tier, _) {
                final label = switch (tier) {
                  SubscriptionTier.pro => "You're on Pro",
                  SubscriptionTier.basic => "You're on the free Basic plan",
                };
                final subtitle = switch (tier) {
                  SubscriptionTier.pro => 'All templates unlocked, unlimited AI generations',
                  SubscriptionTier.basic => 'Upgrade for premium templates and unlimited AI generations',
                };
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                            Text(subtitle, style: const TextStyle(color: AppColors.slate600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Subscription', style: sectionLabel),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card(),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.card_membership_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Manage Subscription', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          Text(
                            'View plans, upgrade, or restore a purchase',
                            style: TextStyle(color: AppColors.slate600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Account', style: sectionLabel),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_circle_outlined, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _account?['fullName']?.isNotEmpty == true
                                  ? _account!['fullName']!
                                  : 'Signed in',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                            ),
                            Text(
                              _account?['email'] ?? '',
                              style: const TextStyle(color: AppColors.slate600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logOut,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Log Out'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('AI & Profile', style: sectionLabel),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card(),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_outline, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          Text(
                            'Manage the profile used for AI resume tailoring',
                            style: TextStyle(color: AppColors.slate600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('About', style: sectionLabel),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resume Builder', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    'Create resumes, cover letters, and business proposals with built-in '
                    'templates, then export them as ready-to-send PDFs.',
                    style: TextStyle(color: AppColors.slate600, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Danger Zone', style: sectionLabel),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearAllData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear All Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
