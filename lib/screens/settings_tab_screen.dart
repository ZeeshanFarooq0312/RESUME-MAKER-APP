import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/download_credits_service.dart';
import '../theme/app_theme.dart';
import 'paywall_sheet.dart';

class SettingsTabScreen extends StatefulWidget {
  const SettingsTabScreen({super.key});

  @override
  State<SettingsTabScreen> createState() => _SettingsTabScreenState();
}

class _SettingsTabScreenState extends State<SettingsTabScreen> {
  int _credits = 0;

  @override
  void initState() {
    super.initState();
    _refreshCredits();
  }

  Future<void> _refreshCredits() async {
    final credits = await DownloadCreditsService.getCredits();
    if (mounted) setState(() => _credits = credits);
  }

  Future<void> _unlock() async {
    final unlocked = await showPaywallSheet(context);
    if (unlocked == true) _refreshCredits();
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
    if (mounted) {
      _refreshCredits();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7E5F3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_credits download${_credits == 1 ? '' : 's'} available',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                        const Text(
                          'Previews are always free',
                          style: TextStyle(color: AppColors.slate600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(onPressed: _unlock, child: const Text('Unlock')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('About', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7E5F3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Document Builder', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    'Build resumes, cover letters, and proposals — fully offline, no account needed.',
                    style: TextStyle(color: AppColors.slate600, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
