import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/account_repository.dart';
import '../app_shell.dart';
import '../onboarding/onboarding_flow.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// App root: decides between Login/Signup, the mandatory onboarding
/// ProfileScreen, or AppShell — purely by listening to [AccountSession]'s
/// notifiers and swapping its own child in place. Deliberately never uses
/// Navigator.push/pushReplacement for these top-level transitions: doing so
/// would stack a new route on top of this one, leaving this widget (and
/// whatever it's listening to) alive but hidden underneath — which is
/// exactly what caused Log Out to silently do nothing before this fix,
/// since AuthGate reacted to the logged-out state but was no longer the
/// visible route. AppShell itself still uses Navigator normally for
/// everything inside it (forms, previews, etc.) — this only applies to the
/// account/onboarding gate above it.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSignup = false;
  late final StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    // authStateChanges() (rather than a one-shot check) is the idiomatic
    // FlutterFire pattern, and reacts immediately to sign-in/sign-out/token
    // invalidation instead of only reflecting whatever was true at launch.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      AccountSession.onboardingComplete.value = null;
      AccountSession.loggedIn.value = false;
      return;
    }
    AccountSession.onboardingComplete.value = await AccountRepository.isOnboardingComplete();
    AccountSession.loggedIn.value = true;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  static const _loading = Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: AccountSession.loggedIn,
      builder: (context, loggedIn, _) {
        if (loggedIn == null) return _loading;
        if (!loggedIn) {
          return _showSignup
              ? SignupScreen(onSwitchToLogin: () => setState(() => _showSignup = false))
              : LoginScreen(onSwitchToSignup: () => setState(() => _showSignup = true));
        }
        return ValueListenableBuilder<bool?>(
          valueListenable: AccountSession.onboardingComplete,
          builder: (context, complete, __) {
            if (complete == null) return _loading;
            return complete ? const AppShell() : const OnboardingFlow();
          },
        );
      },
    );
  }
}
