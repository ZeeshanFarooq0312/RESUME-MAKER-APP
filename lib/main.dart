import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/document_home_screen.dart';

void main() {
  // This app has no INTERNET permission and works fully offline, so
  // GoogleFonts should never attempt a network fetch — it will only ever
  // fall back anyway. Disabling it up front keeps startup deterministic.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ResumeBuilderApp());
}

class ResumeBuilderApp extends StatelessWidget {
  const ResumeBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Resume Builder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const DocumentHomeScreen(),
    );
  }
}
