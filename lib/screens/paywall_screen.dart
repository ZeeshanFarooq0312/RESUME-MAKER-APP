import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_sweep.dart';

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
      _selected = options.isEmpty
          ? null
          : options.firstWhere((o) => o.label == 'Yearly', orElse: () => options.first);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Preview only — the Google Play payment sheet opens on a build installed from the Play Store.'),
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await SubscriptionRepository.purchase(package);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're all set — thanks for subscribing!")),
      );
      Navigator.pop(context);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't complete the purchase. Please try again.")),
        );
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_preview && !SubscriptionRepository.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upgrade to Pro')),
        body: const _StatusNotice(
          icon: Icons.workspace_premium_outlined,
          message: "Subscriptions aren't set up on this build. Ask the developer to configure a RevenueCat API key.",
        ),
      );
    }
    final options = _options;
    final hasPlans = options.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Pro')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !hasPlans
                ? _StatusNotice(
                    icon: Icons.wifi_off_rounded,
                    message: "Couldn't load plans right now — check your internet connection and try again.",
                    onRetry: _retry,
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      // Sticky CTA lives inside the body (Expanded list +
                      // fixed footer) rather than in the Scaffold's
                      // bottomNavigationBar slot — the bottomNavigationBar
                      // form rendered a blank body on this screen, and a plain
                      // Column is both the fix and a simpler structure.
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                              children: [
                                const _HeroBanner(),
                                const SizedBox(height: 24),
                                for (final option in options)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _PlanTile(
                                      option: option,
                                      selected: _selected?.label == option.label,
                                      onTap: _busy
                                          ? null
                                          : () => setState(() => _selected = option),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Center(
                                  child: TextButton(
                                    onPressed: _busy ? null : _restore,
                                    child: const Text('Restore Purchases'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A1030).withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, -6),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_busy || _selected == null) ? null : _purchase,
                                child: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        _selected == null
                                            ? 'Continue'
                                            : 'Continue — ${_selected!.priceString}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.ink, AppColors.slate900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Stack(
          children: [
            const Positioned(top: -50, right: -60, child: GlowBlob(color: AppColors.primary, size: 160)),
            const Positioned(
                bottom: -70, left: -40, child: GlowBlob(color: AppColors.accentGold, size: 140, opacity: 0.28)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep]),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 24),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Upgrade to Pro',
                  style: TextStyle(
                      fontFamily: 'Fraunces', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock every premium template and get unlimited AI generations.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                const _FeatureLine(text: 'All premium templates unlocked'),
                const SizedBox(height: 6),
                const _FeatureLine(text: 'Unlimited AI generations'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final String text;
  const _FeatureLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.accentGold, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  final _PlanOption option;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanTile({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: AppDecorations.card(highlighted: selected).copyWith(
        color: selected ? AppColors.accentGold.withValues(alpha: 0.08) : Colors.white,
        border: selected ? Border.all(color: AppColors.accentGold, width: 1.5) : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.accentGoldDeep : AppColors.slate400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          option.label,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                        if (option.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              option.badge!,
                              style: const TextStyle(
                                  fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${option.priceString} ${option.period}',
                      style: const TextStyle(color: AppColors.slate600, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _StatusNotice({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.slate400, size: 40),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ],
        ),
      ),
    );
  }
}
