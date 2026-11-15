import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether this device has already seen the intro carousel, so
/// returning (logged-out) users land straight on Log In instead of being
/// walked through the intro again. Loaded once in `main()` before the first
/// frame, so `AuthGate` can read [seen] synchronously.
class WelcomeRepository {
  const WelcomeRepository._();
  static const _key = 'welcome_seen_v1';

  static bool seen = false;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    seen = prefs.getBool(_key) ?? false;
  }

  static Future<void> markSeen() async {
    if (seen) return;
    seen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
