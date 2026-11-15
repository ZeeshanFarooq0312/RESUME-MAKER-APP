import 'package:flutter/material.dart';
import '../widgets/app_feedback.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/empty_state.dart';
import '../widgets/template_thumbnail.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';

/// Reached from three places: a locked premium template, an exhausted AI
/// daily limit, and Settings → Manage Subscription. There's a single paid
/// tier ("Pro", entitlement id [kProEntitlementId]) offered as Monthly,
/// Yearly, or Lifetime — all three grant the same entitlement, they just
/// differ in billing. Uses RevenueCat's built-in `Offering.monthly` /
/// `.annual` / `.lifetime` fields rather than custom package identifiers,
/// since the dashboard's quick-setup wizard already configured the
/// offering using those standard duration types.
///
/// Layout: tap-to-select plan cards (like most modern paywalls) + one
/// sticky CTA at the bottom, rather than a separate "Subscribe" button per
/// card — this keeps every row down to a single line of text next to a
/// small fixed-size selection indicator, so nothing has to squeeze
/// horizontally regardless of screen width or how long the store's
/// localized price string is.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

/// One selectable plan row. Deliberately decoupled from RevenueCat's
/// [Package] (kept as a nullable field) so the tile can render from plain
/// display strings — this both keeps [_PlanTile] free of SDK types and lets
/// the paywall preview itself with mock data on a build where Play Billing
/// isn't available (a sideloaded debug APK), since Play Billing only serves
/// real offerings to a Play-Store-distributed install.
class _PlanOption {
  final String label;
  final String period;
  final String? badge;
  final String priceString;
  final Package? package;
  const _PlanOption({
    required this.label,
    required this.period,
    required this.priceString,
    this.package,
    this.badge,
  });
}

class _PaywallScreenState extends State<PaywallScreen> {
  // Build-time affordance: `flutter run --dart-define=PAYWALL_PREVIEW=true`
  // feeds the paywall mock plans so its full UI (hero + tiles + CTA) renders
  // on a sideloaded debug build where real Play Billing offerings can't
  // load. Off by default, so production builds tree-shake the mock away.
  static const _preview = bool.fromEnvironment('PAYWALL_PREVIEW');

  bool _busy = false;
  bool _loading = true;
  List<_PlanOption> _options = const [];
  _PlanOption? _selected;

  @override
  void initState() {
    super.initState();
    if (_preview) {
      _options = _mockOptions;
      _selected = _options[1];
      _loading = false;
    } else if (SubscriptionRepository.isConfigured) {
      _loadOffering();
    } else {
      _loading = false;
    }
  }

  static const _mockOptions = <_PlanOption>[
    _PlanOption(label: 'Monthly', period: '/month', priceString: '\$14.99'),
    _PlanOption(label: 'Yearly', period: '/year', badge: 'Best value', priceString: '\$89.00'),
  ];

  List<_PlanOption> _optionsFrom(Offering? offering) => <_PlanOption>[
        if (offering?.monthly != null)
          _PlanOption(
              label: 'Monthly',
              period: '/month',
              priceString: offering!.monthly!.storeProduct.priceString,
              package: offering.monthly),
        if (offering?.annual != null)
          _PlanOption(
              label: 'Yearly',
              period: '/year',
              badge: 'Best value',
              priceString: offering!.annual!.storeProduct.priceString,
              package: offering.annual),
      ];

  // Plain state + setState rather than FutureBuilder: this Scaffold's
  // AppBar/bottomNavigationBar need to react to the same load, and keeping
  // the whole Scaffold's shape stable across loading/loaded/error rebuilds
  // (only the inner content swaps) is simpler to reason about than having
  // FutureBuilder rebuild the entire subtree on every snapshot transition.
  Future<void> _loadOffering() async {
    setState(() => _loading = true);
    List<_PlanOption> options = const [];
    try {
      final offerings = await SubscriptionRepository.fetchOfferings();
      options = _optionsFrom(offerings.current ?? offerings.all['default']);
    } catch (_) {
      options = const [];
    }
    if (!mounted) return;
    setState(() {
      _options = options;
      _selected = options.isEmpty ? null : options.firstWhere((o) => o.label == 'Yearly', orElse: () => options.first);
      _loading = false;
    });
  }

  void _retry() => _loadOffering();

  Future<void> _purchase() async {
    final package = _selected?.package;
    if (package == null) {
      // Preview mode (or any tile without a real RevenueCat package) has no
      // Play Billing product to charge — make that explicit rather than
      // silently doing nothing, since the real payment sheet only opens on a
      // build installed from the Play Store.
      if (_preview && mounted) {
        showToast(
            context, 'Preview only — the Google Play payment sheet opens on a build installed from the Play Store.',
            tone: ToastTone.info);
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionRepository.purchase(package);
      if (!mounted) return;
      showToast(context, "You're all set — thanks for subscribing!", tone: ToastTone.success);
      Navigator.pop(context);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      if (mounted) {
        showToast(context, "Couldn't complete the purchase. Please try again.", tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Parses a store price string like "$89.00", "Rs 1,200.00" or "1.234,56 €"
  /// into its number and the text around it (currency symbol). Returns null
  /// when it can't be read unambiguously — callers then simply hide the
  /// savings / per-month figures rather than show a wrong one.
  static ({double value, String prefix, String suffix})? _parsePrice(String s) {
    final m = RegExp(r'^([^\d]*)([\d.,\s]*\d)(.*)$').firstMatch(s.trim());
    if (m == null) return null;
    var num = m.group(2)!.replaceAll(RegExp(r'\s'), '');
    final lastDot = num.lastIndexOf('.');
    final lastComma = num.lastIndexOf(',');
    if (lastDot >= 0 && lastComma >= 0) {
      // Whichever separator comes last is the decimal one.
      num = lastDot > lastComma ? num.replaceAll(',', '') : num.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastComma >= 0) {
      final decimals = num.length - lastComma - 1;
      num = decimals == 2 ? num.replaceAll(',', '.') : num.replaceAll(',', '');
    }
    final value = double.tryParse(num);
    if (value == null || value <= 0) return null;
    return (value: value, prefix: m.group(1)!, suffix: m.group(3)!);
  }

  /// "Save 50%" for the yearly plan vs. paying monthly for 12 months.
  String? get _yearlySavings {
    final monthly = _options.where((o) => o.label == 'Monthly').firstOrNull;
    final yearly = _options.where((o) => o.label == 'Yearly').firstOrNull;
    if (monthly == null || yearly == null) return null;
    final m = _parsePrice(monthly.priceString);
    final y = _parsePrice(yearly.priceString);
    if (m == null || y == null || m.prefix != y.prefix || m.suffix != y.suffix) return null;
    final pct = ((1 - y.value / (m.value * 12)) * 100).round();
    return pct >= 5 ? 'Save $pct%' : null;
  }

  /// "$7.42/mo" equivalent for the yearly plan.
  String? _perMonth(_PlanOption o) {
    if (o.label != 'Yearly') return null;
    final y = _parsePrice(o.priceString);
    if (y == null) return null;
    return '${y.prefix}${(y.value / 12).toStringAsFixed(2)}${y.suffix}/mo';
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final options = _options;

    Widget body;
    if (!_preview && !SubscriptionRepository.isConfigured) {
      body = const EmptyState(
        icon: LucideIcons.crown,
        title: "Pro isn't available yet",
        message: "Subscriptions aren't available in this version of the app. Everything free still works.",
      );
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (options.isEmpty) {
      body = EmptyState(
        icon: LucideIcons.wifiOff,
        title: "Couldn't load plans",
        message: 'Check your internet connection and try again.',
        actionLabel: 'Try again',
        onAction: _retry,
      );
    } else {
      final selected = _selected;
      return Scaffold(
        backgroundColor: p.background,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dark header; the light panel's rounded top overlaps it.
                    ColoredBox(
                      color: AppColors.ink,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProHero(onClose: () => Navigator.maybePop(context)),
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: p.background,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: p.background,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Choose your plan',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.title)),
                              const SizedBox(height: 14),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < options.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 12),
                                      Expanded(
                                        child: _PlanCard(
                                          option: options[i],
                                          selected: selected?.label == options[i].label,
                                          savings: options[i].label == 'Yearly' ? _yearlySavings : null,
                                          perMonth: _perMonth(options[i]),
                                          onTap: _busy ? null : () => setState(() => _selected = options[i]),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: p.background,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GoldButton(
                            label: selected == null
                                ? 'Start Pro'
                                : 'Start Pro  ·  ${selected.priceString}${selected.period}',
                            loading: _busy,
                            onPressed: selected == null ? null : _purchase,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.lock, size: 13, color: p.muted),
                              const SizedBox(width: 5),
                              Text('Secure payment by Google Play', style: TextStyle(fontSize: 12.5, color: p.body)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Cancel anytime', style: TextStyle(fontSize: 12.5, color: p.body)),
                              Text('  ·  ', style: TextStyle(fontSize: 12.5, color: p.muted)),
                              TextButton(
                                onPressed: _busy ? null : _restore,
                                style: TextButton.styleFrom(
                                  foregroundColor: p.title,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  minimumSize: const Size(0, 36),
                                  textStyle:
                                      const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                                child: const Text('Restore purchases'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(tooltip: 'Close', icon: const Icon(LucideIcons.x), onPressed: () => Navigator.maybePop(context)),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

/// Dark hero: crown, headline, three benefit lines, and fanned real Pro
/// template pages as the visual.
class _ProHero extends StatelessWidget {
  final VoidCallback onClose;
  const _ProHero({required this.onClose});

  static const _benefits = [
    'Every premium template, ready to download',
    'Unlimited AI writing and job tailoring',
    'Design your own template with AI',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close',
                icon: Icon(LucideIcons.x, color: Colors.white.withValues(alpha: 0.8)),
                onPressed: onClose,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(13)),
                        child: const Icon(LucideIcons.crown, color: AppColors.ink, size: 22),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'RESUME BUILDER PRO',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.accentGold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Land the interview, faster.',
                        style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 28,
                          height: 1.15,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const _FannedPages(),
              ],
            ),
            const SizedBox(height: 22),
            for (final b in _benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 12),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.check, size: 13, color: AppColors.accentGold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(b,
                          style: TextStyle(
                              fontFamily: 'Inter', fontSize: 14.5, color: Colors.white.withValues(alpha: 0.92))),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Three real Pro template first pages, fanned like a hand of cards.
class _FannedPages extends StatelessWidget {
  const _FannedPages();

  @override
  Widget build(BuildContext context) {
    Widget page(ResumeTemplate t, double angle, Offset offset) => Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 72,
              height: 102,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TemplateThumbnail(kind: DocumentKind.resume, template: t),
              ),
            ),
          ),
        );
    return SizedBox(
      width: 122,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          page(ResumeTemplate.nova, -0.2, const Offset(-24, 8)),
          page(ResumeTemplate.vivid, 0.18, const Offset(24, 8)),
          page(ResumeTemplate.aurora, 0, const Offset(0, -2)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanOption option;
  final bool selected;
  final String? savings;
  final String? perMonth;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.option,
    required this.selected,
    required this.savings,
    required this.perMonth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final tag = savings ?? option.badge;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.accentGoldDeep : p.fieldBorder, width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.accentGold.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6)),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(option.label,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.body)),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.accentGoldDeep : Colors.transparent,
                      border: Border.all(color: selected ? AppColors.accentGoldDeep : p.fieldBorder, width: 1.6),
                    ),
                    child: selected ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(option.priceString,
                    style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: p.title)),
              ),
              const SizedBox(height: 2),
              Text(
                  perMonth ??
                      (option.label == 'Monthly' ? 'Billed monthly' : 'per ${option.period.replaceAll('/', '')}'),
                  style: TextStyle(fontSize: 12.5, color: p.body)),
              if (tag != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(999)),
                  child: Text(tag,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold primary button for the purchase moment.
class _GoldButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _GoldButton({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: loading,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentGold,
            foregroundColor: AppColors.ink,
            disabledBackgroundColor: AppColors.accentGold.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          child: loading
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ink))
              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
