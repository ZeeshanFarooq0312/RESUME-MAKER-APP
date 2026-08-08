import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/subscription_repository.dart';
import 'services/theme_repository.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The UI fonts (Inter/Fraunces) are now bundled as assets (see pubspec),
  // so there's no runtime font fetching to configure or wait on — text
  // renders instantly and offline.
  // Only the theme mode is read before the first frame — it's a fast local
  // SharedPreferences read and reading it here avoids a light→dark flash.
  // The slow initializers (Firebase, RevenueCat) are deliberately NOT awaited
  // here: awaiting them kept the app on a blank white screen for seconds
  // before the first frame. They now run behind a splash inside [_Bootstrap].
  await ThemeRepository.load();
  runApp(const ResumeBuilderApp());
}

class ResumeBuilderApp extends StatelessWidget {
  const ResumeBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeSession.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Resume Builder',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const _Bootstrap(),
        );
      },
    );
  }
}

/// Runs the app's slow, one-time initializers (Firebase, RevenueCat) after
/// the first frame — showing a branded splash instead of the blank white
/// window while they complete. Only Firebase is awaited before revealing
/// [AuthGate], since [AuthGate] uses FirebaseAuth immediately; RevenueCat is
/// fired off in the background because nothing on the first screens needs it
/// (the tier defaults to Basic and its listener upgrades it when ready).
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<void> _ready = _initialize();

  Future<void> _initialize() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    unawaited(SubscriptionRepository.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        return const AuthGate();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accentGold, AppColors.accentGoldDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              child: const Icon(Icons.description_rounded, color: AppColors.ink, size: 40),
            ),
            const SizedBox(height: 22),
            const Text(
              'Resume Builder',
              style: TextStyle(
                fontFamily: 'Fraunces',
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.accentGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
