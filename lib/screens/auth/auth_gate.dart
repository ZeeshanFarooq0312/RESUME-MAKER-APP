import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/account_repository.dart';
import '../../services/welcome_repository.dart';
import '../app_shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/welcome_screen.dart';
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

enum _AuthView { welcome, login, signup }

class _AuthGateState extends State<AuthGate> {
  // First launch shows the intro carousel; after that, logged-out users
  // land straight on Log In.
  _AuthView _view = WelcomeRepository.seen ? _AuthView.login : _AuthView.welcome;
  late final StreamSubscription<User?> _authSub;

  void _go(_AuthView view) {
    if (view != _AuthView.welcome) WelcomeRepository.markSeen();
    setState(() => _view = view);
  }

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
          final Widget screen = switch (_view) {
            _AuthView.welcome => WelcomeScreen(
                onGetStarted: () => _go(_AuthView.signup),
                onLogIn: () => _go(_AuthView.login),
              ),
            _AuthView.login => LoginScreen(
                onSwitchToSignup: () => _go(_AuthView.signup),
                onBack: () => _go(_AuthView.welcome),
              ),
            _AuthView.signup => SignupScreen(
                onSwitchToLogin: () => _go(_AuthView.login),
                onBack: () => _go(_AuthView.welcome),
              ),
          };
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(key: ValueKey(_view), child: screen),
          );
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
