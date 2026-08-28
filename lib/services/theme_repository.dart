import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Observable app-wide theme mode so `ResumeBuilderApp`'s root `MaterialApp`
/// (an ancestor) reacts when the Home screen's theme selector (nested deep
/// inside `AppShell`'s IndexedStack) changes it — same
/// ValueNotifier-at-the-top pattern as `AccountSession`/`SubscriptionSession`.
class ThemeSession {
  const ThemeSession._();
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
}

/// Persists the user's light/dark/system choice across launches.
class ThemeRepository {
  const ThemeRepository._();
  static const _key = 'theme_mode_v1';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    ThemeSession.mode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      // No saved preference yet (first launch) -> the app's own default is
      // Light, not the device's system setting, so it looks consistent
      // regardless of what the user's phone theme happens to be.
      _ => ThemeMode.light,
    };
  }

  static Future<void> setMode(ThemeMode mode) async {
    ThemeSession.mode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
