import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account_repository.dart';
import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_sweep.dart';
import 'paywall_screen.dart';
import 'profile_screen.dart';

/// Public URL of the hosted privacy policy (GitHub Pages, docs/ folder).
/// Same page Google Play links to for the Privacy Policy and account-deletion
/// requirements, kept in one place so the in-app link can't drift from it.
const _privacyPolicyUrl = 'https://zeeshanfarooq0312.github.io/RESUME-MAKER-APP/';

class SettingsTabScreen extends StatefulWidget {
  const SettingsTabScreen({super.key});

  @override
  State<SettingsTabScreen> createState() => _SettingsTabScreenState();
}

class _SettingsTabScreenState extends State<SettingsTabScreen> {
  late final Map<String, String>? _account = AccountRepository.currentAccount();

  String get _name {
    final n = _account?['fullName'];
    return (n != null && n.isNotEmpty) ? n : 'Signed in';
  }

  String get _email => _account?['email'] ?? '';

  String get _initial {
    final n = _account?['fullName'];
    if (n != null && n.trim().isNotEmpty) return n.trim()[0].toUpperCase();
    final e = _email;
    return e.isNotEmpty ? e[0].toUpperCase() : '?';
  }

  Future<void> _logOut() async {
    await AccountRepository.logOut();
    AccountSession.loggedIn.value = false;
  }

  Future<void> _restore() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restoring purchases…')),
    );
    try {
      await SubscriptionRepository.restore();
      if (!mounted) return;
      final isPro = SubscriptionSession.tier.value == SubscriptionTier.pro;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isPro
            ? "Purchase restored — you're on Pro."
            : 'No previous purchase found on this account.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't restore purchases. Please try again.")),
        );
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_privacyPolicyUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the privacy policy.")),
      );
    }
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

  Future<void> _deleteAccount() async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted == true) {
      // The Firebase user (and all local data) is gone — return to login.
      AccountSession.loggedIn.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _ProfileHeader(name: _name, email: _email, initial: _initial),
            const SizedBox(height: 22),
            _PlanCard(onManage: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const PaywallScreen()))),
            const SizedBox(height: 22),
            _GroupCard(children: [
              _SettingsRow(
                icon: Icons.person_outline,
                title: 'My Profile',
                subtitle: 'Details used for AI resume tailoring',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              if (SubscriptionRepository.isConfigured) ...[
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.restore_rounded,
                  title: 'Restore purchases',
                  subtitle: 'Recover a subscription bought before',
                  onTap: _restore,
                ),
              ],
              const _RowDivider(),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How your data is handled',
                onTap: _openPrivacyPolicy,
              ),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _clearAllData,
                  style: TextButton.styleFrom(foregroundColor: AppColors.slate600),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear all data'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _deleteAccount,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('Delete account'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Resume Builder · v1.0.0',
                style: TextStyle(color: AppColors.slate400, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name/email at the top — reads as an actual account screen
/// instead of a labelled "Account" card in a stack of cards.
class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  const _ProfileHeader({required this.name, required this.email, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accentGold, AppColors.accentGoldDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 24),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.slate600, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The dark ink/gold subscription card, reacting to the current tier.
class _PlanCard extends StatelessWidget {
  final VoidCallback onManage;
  const _PlanCard({required this.onManage});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubscriptionTier>(
      valueListenable: SubscriptionSession.tier,
      builder: (context, tier, _) {
        final isPro = tier == SubscriptionTier.pro;
        final title = isPro ? 'Pro plan' : 'Basic plan';
        final description = isPro
            ? 'Unlimited AI and every template unlocked to download.'
            : 'Upgrade to download premium templates and get unlimited AI.';
        return ShimmerSweep(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.ink, AppColors.slate900, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FloatBob(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.accentGold, AppColors.accentGoldDeep],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPro ? 'PRO' : 'FREE',
                              style: const TextStyle(
                                color: AppColors.accentGold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      if (!isPro)
                        InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: onManage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [AppColors.accentGold, AppColors.accentGoldDeep]),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Upgrade to Pro',
                                  style: TextStyle(
                                      color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.ink),
                              ],
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: onManage,
                          child: Text(
                            'Manage plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A white rounded container that groups tappable rows, with hairline
/// dividers between them — one card instead of several labelled sections.
class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.card(),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, indent: 68, color: AppColors.cardBorder);
  }
}

/// Confirms and performs permanent account deletion. Collects the password
/// because Firebase requires a recent re-authentication before it will delete
/// an account — which also makes this a genuine "are you the owner" gate.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await AccountRepository.deleteAccount(password: _password.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account and every resume, cover letter, and '
            'proposal tied to it. This cannot be undone.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Confirm your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _busy ? null : _confirm,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.slate600, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}
