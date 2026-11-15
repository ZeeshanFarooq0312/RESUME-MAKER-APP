/// Named spacing scale — the values already used (inconsistently, inline)
/// throughout the app's screens. Introduced so new/touched widgets stop
/// hardcoding magic numbers; existing untouched call sites are left as-is
/// rather than mass-replaced.
class AppSpacing {
  const AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const xxxl = 40.0;
}

/// Named corner radii, matching the values already used by
/// [AppDecorations]/button/input theming in app_theme.dart.
class AppRadius {
  const AppRadius._();
  static const card = 14.0;
  static const dialog = 24.0;
  static const pill = 999.0;
}
