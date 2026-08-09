import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// The app's two subscription tiers. [basic] is the default for every user
/// who hasn't purchased anything — never persisted locally, always derived
/// fresh from RevenueCat's [CustomerInfo] at runtime. [pro] covers any
/// duration (monthly, yearly, or lifetime) — they all grant the same single
/// entitlement in RevenueCat.
enum SubscriptionTier { basic, pro }

/// The RevenueCat entitlement identifier that grants [SubscriptionTier.pro].
/// Must match the "Entitlement identifier" configured in the RevenueCat
/// dashboard exactly — if it drifts, every purchase silently leaves the app
/// on Basic (RevenueCat has no way to warn us that the string didn't match).
/// In the dashboard: create an entitlement with identifier `pro` and attach
/// both the `pro:monthly` and `yearly:yearly` products to it.
const kProEntitlementId = 'pro';

/// Reactive current-tier state, read by every gating check in the app
/// (template_screen.dart, the AI call sites, settings_tab_screen.dart).
/// Mirrors the [AccountSession]/[AiUsageLimits] convention of a small
/// static holder class next to its repository.
class SubscriptionSession {
  const SubscriptionSession._();
  static final ValueNotifier<SubscriptionTier> tier =
      ValueNotifier(SubscriptionTier.basic);
}

/// Wraps the RevenueCat SDK, which itself wraps Google Play Billing. This
/// app has no backend of its own (see PRIVACY_POLICY.md), so entitlement
/// state is whatever RevenueCat's SDK reports locally from the last synced
/// [CustomerInfo] — same trust model as everything else in this app.
///
/// Uses RevenueCat's anonymous app-user-id rather than tying it to the
/// app's local account: Play Store purchases are already tied to the
/// device's Google account, and "Restore Purchases" re-syncs from that, so
/// there's nothing to gain from bridging it to the unrelated local login.
class SubscriptionRepository {
  const SubscriptionRepository._();

  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static bool get isConfigured => _apiKey.isNotEmpty;

  static bool _initialized = false;

  /// Called once from main() before runApp. A no-op if no
  /// `--dart-define=REVENUECAT_API_KEY=...` was passed — the app still
  /// runs, just permanently on the Basic tier, same as GroqService's
  /// isConfigured guard pattern for AI features.
  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    _initialized = true;
    await Purchases.configure(PurchasesConfiguration(_apiKey));
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    // Fetch the first CustomerInfo in the background rather than awaiting it:
    // initialize() runs in main() before runApp, so awaiting this network
    // round-trip would keep the whole app on a blank screen until it returns.
    // The listener above flips the tier to Pro the moment it lands; until
    // then the Basic default is correct for almost every launch anyway.
    unawaited(_refreshCustomerInfo());
  }

  static Future<void> _refreshCustomerInfo() async {
    try {
      _onCustomerInfoUpdated(await Purchases.getCustomerInfo());
    } catch (_) {
      // Leave tier at the default Basic if the fetch fails (e.g. offline) —
      // the update listener will still correct it once a sync succeeds.
    }
  }

  static Future<Offerings> fetchOfferings() => Purchases.getOfferings();

  static Future<CustomerInfo> purchase(Package package) async {
    // purchases_flutter 10 replaced purchasePackage(package) -> CustomerInfo
    // with purchase(PurchaseParams) -> PurchaseResult; the CustomerInfo we
    // gate on is now nested under .customerInfo.
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  static Future<CustomerInfo> restore() => Purchases.restorePurchases();

  static Future<void> _onCustomerInfoUpdated(CustomerInfo info) async {
    SubscriptionSession.tier.value = info.entitlements.active.containsKey(kProEntitlementId)
        ? SubscriptionTier.pro
        : SubscriptionTier.basic;
  }
}
