import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_repository.dart';

/// Per-tier daily AI-generation cap. `-1` means unlimited. AI is free to use
/// for everyone (the paywall is at document download, not at AI usage) — free
/// (basic) users get a generous daily cap purely to control API cost, Pro
/// users are unlimited. Kept as constants in one place so
/// [AiUsageTracker.canUseAi] is the single gate every AI call site funnels
/// through, and the cap is trivial to retune here.
class AiUsageLimits {
  const AiUsageLimits._();
  static const Map<SubscriptionTier, int> dailyLimit = {
    SubscriptionTier.basic: 10,
    SubscriptionTier.pro: -1,
  };
}

/// Local, client-side-only rate limiter for the Groq-backed AI features.
/// Same "not a real security boundary" trust model as the rest of this
/// app's local storage (see account_repository.dart) — a determined user
/// could reset it by clearing app data, at the cost of also losing their
/// account/profile/documents. This exists to control AI API cost per tier,
/// not to be tamper-proof.
class AiUsageTracker {
  const AiUsageTracker._();

  static const _dateKey = 'ai_usage_date_v1';
  static const _countKey = 'ai_usage_count_v1';

  static String _today() => DateTime.now().toIso8601String().split('T').first;

  static Future<int> _currentCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dateKey);
    if (storedDate != _today()) return 0;
    return prefs.getInt(_countKey) ?? 0;
  }

  /// Whether another AI call is allowed right now for the current tier.
  static Future<bool> canUseAi() async {
    final limit = AiUsageLimits.dailyLimit[SubscriptionSession.tier.value]!;
    if (limit < 0) return true;
    return await _currentCount() < limit;
  }

  /// Call after a successful AI generation to count it against today's cap.
  static Future<void> recordUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final count = await _currentCount();
    await prefs.setString(_dateKey, _today());
    await prefs.setInt(_countKey, count + 1);
  }

  /// For UI messaging (e.g. "3 of 5 used today").
  static Future<int> remainingToday() async {
    final limit = AiUsageLimits.dailyLimit[SubscriptionSession.tier.value]!;
    if (limit < 0) return -1;
    final used = await _currentCount();
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }
}
