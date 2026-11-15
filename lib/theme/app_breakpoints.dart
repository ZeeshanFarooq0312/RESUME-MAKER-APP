/// Material-aligned width breakpoints (roughly 600/900/1200), used by the
/// responsive widgets in widgets/responsive_scaffold.dart. The app has no
/// adaptive layout logic today — every screen is a fixed single-column
/// phone layout that stretches rather than reflows on wider screens — these
/// breakpoints are the shared reference point for fixing that.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Phones.
  static const compact = 600.0;

  /// Large phones, small/folded tablets.
  static const medium = 900.0;

  /// Tablets in landscape, desktop.
  static const expanded = 1200.0;

  /// Grid column count for a given available width. 2 at compact matches
  /// every grid's hardcoded default today, so this is a non-breaking
  /// starting point when swapped in.
  static int columnsFor(double width) {
    if (width >= expanded) return 4;
    if (width >= medium) return 3;
    return 2;
  }
}
