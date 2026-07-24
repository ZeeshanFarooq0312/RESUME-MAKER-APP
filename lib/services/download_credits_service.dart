import 'package:shared_preferences/shared_preferences.dart';

/// Tracks how many resume downloads the user has left. Downloads are sold
/// in packs (see [PaymentService]) — preview is always free, but consuming
/// a PDF (download/share/print) spends one credit.
class DownloadCreditsService {
  static const _key = 'download_credits';

  static Future<int> getCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  static Future<bool> hasCredits() async => (await getCredits()) > 0;

  static Future<void> addCredits(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 0;
    await prefs.setInt(_key, current + amount);
  }

  /// Spends one credit if available. Returns whether a credit was spent.
  static Future<bool> consumeCredit() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 0;
    if (current <= 0) return false;
    await prefs.setInt(_key, current - 1);
    return true;
  }
}
