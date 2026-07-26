import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/app_shell.dart';

void main() {
  // Fonts are bundled as assets and rendered via PdfFonts/pw.Font, not
  // GoogleFonts network fetching, so this should never attempt a network
  // fetch — it would only ever fall back anyway. Disabling it up front keeps
  // startup deterministic.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ResumeBuilderApp());
}

class ResumeBuilderApp extends StatelessWidget {
  const ResumeBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resume Builder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
