import 'package:flutter/material.dart';
import '../widgets/app_feedback.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account_repository.dart';
import '../services/subscription_repository.dart';
import '../services/theme_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/responsive_scaffold.dart';
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

  static const _themeIcons = {
    ThemeMode.light: LucideIcons.sun,
    ThemeMode.dark: LucideIcons.moon,
    ThemeMode.system: LucideIcons.sunMoon,
  };

  static const _themeLabels = {
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
    ThemeMode.system: 'Match system',
  };

  Future<void> _pickTheme(ThemeMode current) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final p = AuthPalette.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Appearance',
                  style: TextStyle(
                      fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: p.title)),
              const SizedBox(height: 14),
              for (final mode in ThemeMode.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(_themeIcons[mode], color: mode == current ? p.title : p.muted),
                  title: Text(_themeLabels[mode]!,
                      style: TextStyle(
                          fontWeight: mode == current ? FontWeight.w700 : FontWeight.w500, color: p.title)),
                  trailing: mode == current ? Icon(LucideIcons.check, color: p.title) : null,
                  onTap: () {
                    ThemeRepository.setMode(mode);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logOut() async {
    final confirmed = await showPromptSheet(
      context,
      icon: LucideIcons.logOut,
      title: 'Log out?',
      message: 'Your documents stay saved on this device. Log back in anytime to pick up where you left off.',
      primaryLabel: 'Log out',
      secondaryLabel: 'Cancel',
    );
    if (confirmed != true) return;
    await AccountRepository.logOut();
    AccountSession.loggedIn.value = false;
  }

  Future<void> _restore() async {
    showToast(context, 'Restoring purchases…', tone: ToastTone.info);
    try {
      await SubscriptionRepository.restore();
      if (!mounted) return;
      final isPro = SubscriptionSession.tier.value == SubscriptionTier.pro;
      showToast(context, isPro
            ? "Purchase restored — you're on Pro."
            : 'No previous purchase found on this account.', tone: isPro ? ToastTone.success : ToastTone.info);
    } catch (_) {
      if (mounted) {
        showToast(context, "Couldn't restore purchases. Please try again.", tone: ToastTone.error);
      }
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_privacyPolicyUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showToast(context, "Couldn't open the privacy policy.", tone: ToastTone.error);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showPromptSheet(
      context,
      tone: PromptTone.error,
      destructive: true,
      icon: LucideIcons.trash2,
      title: 'Clear all data?',
      message: 'This permanently deletes every resume, cover letter and proposal on this device, '
          "and signs you out. This can't be undone.",
      primaryLabel: 'Clear everything',
      secondaryLabel: 'Cancel',
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Firebase persists its own session independently of SharedPreferences,
    // so clearing local storage alone would leave the account signed in —
    // sign out explicitly so "Clear Everything" actually starts fresh.
    await AccountRepository.logOut();
    if (mounted) {
      showToast(context, 'All data cleared.', tone: ToastTone.success);
    }
    AccountSession.loggedIn.value = false;
  }

  Future<void> _deleteAccount() async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (deleted == true) {
      // The Firebase user (and all local data) is gone — return to login.
      AccountSession.loggedIn.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: ResponsiveContentBound(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 28,
                  height: 1.15,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w600,
                  color: p.title,
                ),
              ),
              const SizedBox(height: 20),
              _ProfileHeader(name: _name, email: _email, initial: _initial),
              const SizedBox(height: 14),
              _PlanCard(
                onManage: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
              ),
              const _GroupLabel('Account'),
              _GroupCard(children: [
                _SettingsRow(
                  icon: LucideIcons.idCard,
                  title: 'My profile',
                  subtitle: 'Details AI uses to tailor your resumes',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeSession.mode,
                  builder: (context, mode, _) => _SettingsRow(
                    icon: _themeIcons[mode]!,
                    title: 'Appearance',
                    value: _themeLabels[mode]!,
                    onTap: () => _pickTheme(mode),
                  ),
                ),
                if (SubscriptionRepository.isConfigured)
                  _SettingsRow(
                    icon: LucideIcons.rotateCcw,
                    title: 'Restore purchases',
                    subtitle: 'Bought Pro before? Get it back here',
                    onTap: _restore,
                  ),
              ]),
              const _GroupLabel('About'),
              _GroupCard(children: [
                _SettingsRow(
                  icon: LucideIcons.shield,
                  title: 'Privacy policy',
                  subtitle: 'How your data is handled',
                  trailingIcon: LucideIcons.externalLink,
                  onTap: _openPrivacyPolicy,
                ),
                const _SettingsRow(icon: LucideIcons.info, title: 'Version', value: '1.0.1'),
              ]),
              const SizedBox(height: 14),
              _GroupCard(children: [
                _SettingsRow(icon: LucideIcons.logOut, title: 'Log out', onTap: _logOut, showChevron: false),
              ]),
              const _GroupLabel('Danger zone'),
              _GroupCard(children: [
                _SettingsRow(
                  icon: LucideIcons.trash2,
                  title: 'Clear all data',
                  subtitle: 'Delete every document on this device',
                  danger: true,
                  onTap: _clearAllData,
                ),
                _SettingsRow(
                  icon: LucideIcons.userX,
                  title: 'Delete account',
                  subtitle: 'Permanently remove your account',
                  danger: true,
                  onTap: _deleteAccount,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  const _ProfileHeader({required this.name, required this.email, required this.initial});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accentGold, shape: BoxShape.circle),
            child: initial == '?'
                ? const Icon(LucideIcons.user, color: AppColors.ink, size: 24)
                : Text(initial,
                    style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 21)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, color: p.title)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.body, fontSize: 13.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat dark plan card (same surface as Home's hero), reacting to the tier.
class _PlanCard extends StatelessWidget {
  final VoidCallback onManage;
  const _PlanCard({required this.onManage});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<SubscriptionTier>(
      valueListenable: SubscriptionSession.tier,
      builder: (context, tier, _) {
        final isPro = tier == SubscriptionTier.pro;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: dark ? AppColors.slate900 : AppColors.ink,
            borderRadius: BorderRadius.circular(18),
            border: dark ? Border.all(color: AppColors.slate800) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.crown, color: AppColors.ink, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isPro ? 'Pro plan' : 'Free plan',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          isPro ? 'Unlimited AI and every template' : 'Limited daily AI and free templates',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: isPro
                    ? OutlinedButton(
                        onPressed: onManage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Manage plan'),
                      )
                    : FilledButton(
                        onPressed: onManage,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: AppColors.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Text('Upgrade to Pro'), SizedBox(width: 6), Icon(LucideIcons.arrowRight, size: 16)],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: p.muted),
      ),
    );
  }
}

/// Rounded group of rows with hairline dividers.
class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 64, color: p.fieldBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Confirms and performs permanent account deletion. Collects the password
/// because Firebase requires a recent re-authentication before it will delete
/// an account — which also makes this a genuine "are you the owner" gate.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _password = TextEditingController();
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
    final p = AuthPalette.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.userX, color: AppColors.danger, size: 28),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Delete your account?',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: p.title),
            ),
            const SizedBox(height: 8),
            Text(
              'This permanently deletes your account and every resume, cover letter and proposal '
              "tied to it. This can't be undone.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.5, color: p.body),
            ),
            const SizedBox(height: 22),
            AuthField(
              label: 'Confirm with your password',
              hint: 'Your password',
              icon: LucideIcons.lock,
              controller: _password,
              isPassword: true,
              autofocus: true,
              textInputAction: TextInputAction.done,
              errorText: _error,
              onSubmitted: (_) => _confirm(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(
              label: 'Delete account',
              color: AppColors.danger,
              loading: _busy,
              onPressed: _confirm,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 46,
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: p.body),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;
  final IconData? trailingIcon;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final fg = danger ? AppColors.danger : p.title;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: danger ? AppColors.danger.withValues(alpha: 0.10) : p.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: fg, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: fg)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(color: p.body, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(value!, style: TextStyle(color: p.body, fontSize: 14)),
              ],
              if (onTap != null && showChevron) ...[
                const SizedBox(width: 6),
                Icon(trailingIcon ?? LucideIcons.chevronRight, size: 18, color: p.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
