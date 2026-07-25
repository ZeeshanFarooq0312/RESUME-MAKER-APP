import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token names are kept stable from the previous slate/gold palette even
/// though the hex values are now violet — every existing screen that
/// references AppColors picks up the new look without being touched
/// individually. `gold`/`goldLight`/`cream` are kept as aliases for the
/// same reason; new code should prefer `primary`/`primaryLight`/`background`.
class AppColors {
  static const primary = Color(0xFF6C5DD3);
  static const primaryDark = Color(0xFF4A3FA8);
  static const primaryLight = Color(0xFFEDEAFB);
  static const background = Color(0xFFF7F7FB);
  static const danger = Color(0xFFE0455F);

  static const slate900 = Color(0xFF221F35);
  static const slate800 = Color(0xFF352F52);
  static const slate600 = Color(0xFF6B6584);
  static const slate400 = Color(0xFFA6A1BE);
  static const slate100 = Color(0xFFF1EFFA);

  static const gold = primary;
  static const goldLight = primaryLight;
  static const cream = background;
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
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.slate900,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.slate900,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.slate900,
        ),
        iconTheme: const IconThemeData(color: AppColors.slate900),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
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
    );
  }
}
