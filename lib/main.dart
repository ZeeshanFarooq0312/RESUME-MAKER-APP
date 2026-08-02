import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'services/subscription_repository.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only the PDF-export path (PdfFonts/pw.Font) uses the bundled Lato
  // assets — the on-screen UI theme (Inter/Playfair Display, set in
  // app_theme.dart) is not bundled locally, so runtime fetching must stay
  // enabled or a fresh install (nothing cached yet) throws instead of
  // rendering text. google_fonts caches after the first fetch, so this is
  // a one-time cost per device, same as any other app using this package.
  GoogleFonts.config.allowRuntimeFetching = true;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SubscriptionRepository.initialize();
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
      home: const AuthGate(),
    );
  }
}
