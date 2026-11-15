import 'package:flutter/material.dart';
import '../widgets/app_feedback.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account_repository.dart';
import '../services/documents_repository.dart';
import '../services/ai_usage_tracker.dart';
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
      showToast(context, isPro ? "Purchase restored — you're on Pro." : 'No previous purchase found on this account.',
          tone: isPro ? ToastTone.success : ToastTone.info);
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

  // Live stats shown on the account card. Refreshed whenever documents or
  // AI usage change, since this tab stays alive in the app shell.
  int? _docCount;
  int? _savedCount;
  int? _aiLeft;

  @override
  void initState() {
    super.initState();
    _loadStats();
    DocumentsRepository.revision.addListener(_loadStats);
    AiUsageTracker.changes.addListener(_loadStats);
    SubscriptionSession.tier.addListener(_loadStats);
  }

  @override
  void dispose() {
    DocumentsRepository.revision.removeListener(_loadStats);
    AiUsageTracker.changes.removeListener(_loadStats);
    SubscriptionSession.tier.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final docs = await DocumentsRepository.loadAll();
    final aiLeft = await AiUsageTracker.remainingToday();
    if (!mounted) return;
    setState(() {
      _docCount = docs.length;
      _savedCount = docs.where((d) => d.isFavorite).length;
      _aiLeft = aiLeft;
    });
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
              _AccountCard(
                name: _name,
                email: _email,
                initial: _initial,
                docCount: _docCount,
                savedCount: _savedCount,
                aiLeft: _aiLeft,
              ),
              const SizedBox(height: 12),
              _PlanCard(
                onManage: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
              ),
              const _GroupLabel('Appearance'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeSession.mode,
                builder: (context, mode, _) => _ThemeSwitch(
                  mode: mode,
                  icons: _themeIcons,
                  labels: _themeLabels,
                  onChanged: ThemeRepository.setMode,
                ),
              ),
              const _GroupLabel('Account'),
              _GroupCard(children: [
                _SettingsRow(
                  icon: LucideIcons.idCard,
                  title: 'My profile',
                  subtitle: 'Details AI uses to tailor your resumes',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
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
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _logOut,
                  icon: const Icon(LucideIcons.logOut, size: 18),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.title,
                    backgroundColor: p.surface,
                    side: BorderSide(color: p.fieldBorder, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
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

/// Avatar, name and email, plus three live stats.
class _AccountCard extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  final int? docCount;
  final int? savedCount;
  final int? aiLeft;

  const _AccountCard({
    required this.name,
    required this.email,
    required this.initial,
    required this.docCount,
    required this.savedCount,
    required this.aiLeft,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    String fmt(int? n) => n == null ? '–' : '$n';
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.accentGold, shape: BoxShape.circle),
                  child: initial == '?'
                      ? const Icon(LucideIcons.user, color: AppColors.ink, size: 26)
                      : Text(initial,
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: p.title)),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.body, fontSize: 13.5)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: p.fieldBorder),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _Stat(value: fmt(docCount), label: 'Documents')),
                VerticalDivider(width: 1, thickness: 1, color: p.fieldBorder),
                Expanded(child: _Stat(value: fmt(savedCount), label: 'Saved')),
                VerticalDivider(width: 1, thickness: 1, color: p.fieldBorder),
                Expanded(
                  child: _Stat(
                    value: aiLeft == null ? '–' : (aiLeft! < 0 ? '∞' : '$aiLeft'),
                    label: 'AI left today',
                    highlight: aiLeft == 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;
  const _Stat({required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: highlight ? AppColors.danger : p.title)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: p.body)),
        ],
      ),
    );
  }
}

/// Slim plan card: a gold-outlined upsell on Free, a quiet "Active" row on Pro.
class _PlanCard extends StatelessWidget {
  final VoidCallback onManage;
  const _PlanCard({required this.onManage});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return ValueListenableBuilder<SubscriptionTier>(
      valueListenable: SubscriptionSession.tier,
      builder: (context, tier, _) {
        final isPro = tier == SubscriptionTier.pro;
        return Material(
          color: isPro ? p.surface : AppColors.accentGold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onManage,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isPro ? p.fieldBorder : AppColors.accentGold.withValues(alpha: 0.7),
                  width: isPro ? 1 : 1.4,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.crown, color: AppColors.ink, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(isPro ? 'Pro plan' : 'Upgrade to Pro',
                                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.title)),
                            if (isPro) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('Active',
                                    style:
                                        TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPro ? 'Unlimited AI and every template' : 'Unlimited AI and every premium template',
                          style: TextStyle(fontSize: 13, color: p.body),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isPro)
                    Text('Manage', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.title))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
                      child: Text('See plans',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.onPrimary)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Inline Light / Dark / System segmented switch.
class _ThemeSwitch extends StatelessWidget {
  final ThemeMode mode;
  final Map<ThemeMode, IconData> icons;
  final Map<ThemeMode, String> labels;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSwitch({required this.mode, required this.icons, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Row(
        children: [
          for (final m in [ThemeMode.light, ThemeMode.dark, ThemeMode.system])
            Expanded(
              child: Semantics(
                selected: m == mode,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: m == mode ? p.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icons[m], size: 16, color: m == mode ? p.onPrimary : p.body),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            m == ThemeMode.system ? 'System' : labels[m]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: m == mode ? p.onPrimary : p.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
  final IconData? trailingIcon;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.danger = false,
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
              if (onTap != null) ...[
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
