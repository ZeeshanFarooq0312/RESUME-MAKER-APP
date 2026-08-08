import 'package:flutter/material.dart';

/// Token names are kept stable across palette generations — every existing
/// screen that references AppColors picks up the new look without being
/// touched individually. This generation repoints `primary`/`primaryDark`/
/// `primaryLight` from the old violet palette to the "ink" palette that's
/// already used by the Paywall/Settings/Onboarding hero sections and the
/// Home dashboard, so the entire app (including the signup/login gradient
/// header in `AuthScaffold`) now shares one identity: near-black ink as the
/// everyday UI color, with `accentGold` reserved as the one warm highlight
/// for premium/AI moments (badges, CTAs on dark surfaces) — it would stop
/// reading as special if it were used everywhere instead.
class AppColors {
  static const primary = Color(0xFF14121F);
  static const primaryDark = Color(0xFF221F35);
  static const primaryLight = Color(0xFFF1EFFA);
  static const background = Color(0xFFF7F7FB);
  static const danger = Color(0xFFE0455F);

  static const slate900 = Color(0xFF221F35);
  static const slate800 = Color(0xFF352F52);
  static const slate600 = Color(0xFF6B6584);
  static const slate400 = Color(0xFFA6A1BE);
  static const slate100 = Color(0xFFF1EFFA);

  /// True gold aliases (unlike `primary` above, these are NOT the ink
  /// palette) — kept for any older call site still written as `gold`/
  /// `goldLight` instead of `accentGold`/the tint below.
  static const gold = accentGold;
  static const goldLight = Color(0xFFFCEEDA);
  static const cream = background;

  /// The thin border color used under every card decoration below — kept
  /// as a named token since it's referenced directly in a few older spots
  /// that haven't been migrated to [AppDecorations.card] yet.
  static const cardBorder = Color(0xFFEDEBF5);

  /// Dark "hero" background — same value as [primary] now that the whole
  /// app shares the ink identity, kept as its own name for call sites that
  /// specifically mean "the dark hero surface" rather than "the UI accent".
  static const ink = Color(0xFF14121F);

  /// Warm secondary accent (badges, CTAs, plan cards) — the one color in
  /// the app that isn't part of the ink/slate family, so it keeps standing
  /// out for AI/premium moments.
  static const accentGold = Color(0xFFFFB454);
  static const accentGoldDeep = Color(0xFFE8963A);
}

/// Shared container decorations, so "card" doesn't mean something
/// different on every screen. The soft shadow (rather than a border alone)
/// is what reads as an actual depth system instead of flat Material
/// defaults — every white bordered box in the app should use this instead
/// of hand-rolling its own BoxDecoration.
class AppDecorations {
  const AppDecorations._();

  static BoxDecoration card({double radius = 14, bool highlighted = false}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: highlighted ? AppColors.primary : AppColors.cardBorder,
        width: highlighted ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: (highlighted ? AppColors.primary : const Color(0xFF1A1030))
              .withValues(alpha: highlighted ? 0.14 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: Colors.white,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Inter').copyWith(
        headlineMedium: const TextStyle(fontFamily: 'Fraunces',
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.slate900,
        ),
        titleLarge: const TextStyle(fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.slate900,
        ),
        // The small "section header" style repeated ad hoc across screens
        // (Settings, Home) as a literal TextStyle — named here so it can be
        // referenced instead of copy-pasted.
        labelLarge: const TextStyle(fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.slate800,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(fontFamily: 'Fraunces',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.slate900,
        ),
        iconTheme: IconThemeData(color: AppColors.slate900),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7E5F3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7E5F3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.slate600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      // Popups are themed centrally so every AlertDialog / bottom sheet /
      // SnackBar in the app picks up the rounded, serif-titled, ink/gold
      // look without each call site being restyled by hand.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0xFF1A1030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontFamily: 'Fraunces',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.slate900,
        ),
        contentTextStyle: const TextStyle(fontFamily: 'Inter',
          fontSize: 14,
          height: 1.45,
          color: AppColors.slate600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.slate400,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(fontFamily: 'Inter',color: Colors.white, fontSize: 13.5),
        actionTextColor: AppColors.accentGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
      ),
    );
  }

  /// Mirrors [light]'s structure token-for-token, swapped to the dark "ink"
  /// palette already used by the Paywall/Settings hero sections — this
  /// makes the whole app read as that same design instead of introducing a
  /// second, unrelated dark palette. `AppDecorations.card()` intentionally
  /// stays white in both themes (a deliberate "white paper card on a dark
  /// canvas" look, same pairing already used by the dark plan card sitting
  /// on Settings' light page) rather than every card also going dark.
  static ThemeData dark() {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accentGold,
        secondary: AppColors.accentGold,
        surface: AppColors.slate900,
        onSurface: Colors.white,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Inter').copyWith(
        headlineMedium: const TextStyle(fontFamily: 'Fraunces',
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: const TextStyle(fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        labelLarge: const TextStyle(fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(fontFamily: 'Fraunces',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          elevation: 2,
          shadowColor: AppColors.accentGold.withValues(alpha: 0.35),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate900,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.slate800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.slate800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.slate900,
        selectedItemColor: AppColors.accentGold,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.slate900,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontFamily: 'Fraunces',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        contentTextStyle: const TextStyle(fontFamily: 'Inter',
          fontSize: 14,
          height: 1.45,
          color: Colors.white70,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.slate900,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.slate400,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.slate800,
        contentTextStyle: const TextStyle(fontFamily: 'Inter',color: Colors.white, fontSize: 13.5),
        actionTextColor: AppColors.accentGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
