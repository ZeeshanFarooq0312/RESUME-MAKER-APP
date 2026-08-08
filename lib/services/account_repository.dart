import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Observable auth state so `AuthGate` (an ancestor) can react when
/// `SettingsTabScreen`'s Log Out button (a descendant, nested inside
/// `AppShell`'s IndexedStack) changes it — the smallest mechanism that does
/// that without a state-management package or prop-drilling a callback
/// through AppShell's screen list. `null` means "still reading storage".
class AccountSession {
  const AccountSession._();
  static final ValueNotifier<bool?> loggedIn = ValueNotifier<bool?>(null);
  static final ValueNotifier<bool?> onboardingComplete = ValueNotifier<bool?>(null);
}

/// Friendly, user-facing error for any auth failure. Every public
/// [AccountRepository] method only ever throws this, so callers only need
/// to catch one type — mirrors [AiServiceException] in groq_service.dart.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Wraps Firebase Authentication for real sign-up/login/password-reset.
/// Firebase owns the account (email + credential) and its own session
/// persistence — there's no local password hash or "logged in" flag to
/// maintain anymore. What stays local and per-device, unrelated to
/// identity, is the onboarding-complete flag below (and, elsewhere, the
/// user's Profile/documents via ProfileRepository/DocumentsRepository).
class AccountRepository {
  static const _onboardingKey = 'onboarding_complete_v1';

  static AuthException _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthException('An account with this email already exists.');
      case 'weak-password':
        return AuthException('Password must be at least 6 characters.');
      case 'invalid-email':
        return AuthException('Enter a valid email address.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException('Incorrect email or password.');
      case 'network-request-failed':
        return AuthException("Couldn't reach the server — check your internet connection.");
      case 'too-many-requests':
        return AuthException('Too many attempts — please wait a moment and try again.');
      case 'operation-not-allowed':
        return AuthException(
            'Email/password sign-in is not enabled for this app yet. Contact support.');
      default:
        return AuthException('Something went wrong. Please try again.');
    }
  }

  static Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(fullName);
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
    // A fresh signup always needs onboarding again, even if a previous
    // account on this device had already completed it.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, false);
  }

  static Future<void> login({required String email, required String password}) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Deliberately not distinguishing "user-not-found" here — surfacing
      // it would let a caller enumerate which emails have accounts.
      if (e.code == 'user-not-found' || e.code == 'invalid-email') return;
      throw _mapError(e);
    }
  }

  static Future<void> logOut() => FirebaseAuth.instance.signOut();

  /// Permanently deletes the signed-in account from Firebase and wipes every
  /// trace of it from this device. Required by Google Play for any app that
  /// offers account creation. Firebase blocks deletion unless the user has
  /// authenticated recently, so we re-authenticate with the password first —
  /// which also doubles as a confirmation that it's really the account owner.
  static Future<void> deleteAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw AuthException('No account is signed in.');
    final email = user.email;
    if (email == null) {
      throw AuthException("This account can't be deleted automatically — contact support.");
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
    // Remove all local data (profile, documents, onboarding flag, AI counts)
    // so nothing of the deleted account survives on the device.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Returns `{fullName, email}` for display, or null if no one is signed in.
  static Map<String, String>? currentAccount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return {
      'fullName': user.displayName ?? '',
      'email': user.email ?? '',
    };
  }
}
