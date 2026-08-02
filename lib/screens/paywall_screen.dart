import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';

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

class _PlanOption {
  final String label;
  final String period;
  final String? badge;
  final Package package;
  const _PlanOption({required this.label, required this.period, required this.package, this.badge});
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;
  Package? _selected;
  late Future<Offering?> _offeringFuture;

  @override
  void initState() {
    super.initState();
    _offeringFuture = SubscriptionRepository.isConfigured
        ? _loadOffering()
        : Future.value(null);
  }

  Future<Offering?> _loadOffering() async {
    final offerings = await SubscriptionRepository.fetchOfferings();
    final offering = offerings.current ?? offerings.all['default'];
    _selected = offering?.annual ?? offering?.monthly ?? offering?.lifetime;
    return offering;
  }

  void _retry() => setState(() => _offeringFuture = _loadOffering());

  Future<void> _purchase() async {
    final package = _selected;
    if (package == null) return;
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
    if (!SubscriptionRepository.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upgrade to Pro')),
        body: const _StatusNotice(
          icon: Icons.workspace_premium_outlined,
          message: "Subscriptions aren't set up on this build. Ask the developer to configure a RevenueCat API key.",
        ),
      );
    }
    return FutureBuilder<Offering?>(
      future: _offeringFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final offering = snapshot.data;

        final options = <_PlanOption>[
          if (offering?.monthly != null)
            _PlanOption(label: 'Monthly', period: '/month', package: offering!.monthly!),
          if (offering?.annual != null)
            _PlanOption(
                label: 'Yearly', period: '/year', badge: 'Best value', package: offering!.annual!),
          if (offering?.lifetime != null)
            _PlanOption(
                label: 'Lifetime', period: 'one-time', badge: 'Pay once', package: offering!.lifetime!),
        ];

        return Scaffold(
          appBar: AppBar(title: const Text('Upgrade to Pro')),
          body: SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (offering == null || options.isEmpty)
                    ? _StatusNotice(
                        icon: Icons.wifi_off_rounded,
                        message: "Couldn't load plans right now — check your internet connection and try again.",
                        onRetry: _retry,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
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
                                        selected: _selected?.identifier == option.package.identifier,
                                        onTap: _busy
                                            ? null
                                            : () => setState(() => _selected = option.package),
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
                          );
                        },
                      ),
          ),
          bottomNavigationBar: (loading || offering == null || options.isEmpty)
              ? null
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A1030).withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
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
                                        : 'Continue — ${_selected!.storeProduct.priceString}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 14),
          const Text(
            'Upgrade to Pro',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Unlock every premium template and get unlimited AI generations.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          const _FeatureLine(text: 'All premium templates unlocked'),
          const SizedBox(height: 6),
          const _FeatureLine(text: 'Unlimited AI generations'),
        ],
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
        const Icon(Icons.check_circle, color: Colors.white, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
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
        color: selected ? AppColors.primaryLight : Colors.white,
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
                color: selected ? AppColors.primary : AppColors.slate400,
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
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              option.badge!,
                              style: const TextStyle(
                                  fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${option.package.storeProduct.priceString} ${option.period}',
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
