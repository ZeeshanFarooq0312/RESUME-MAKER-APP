import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/account_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_kit.dart';
import '../../widgets/auth_scaffold.dart';

/// Log in with Firebase Authentication. On success this only flips
/// [AccountSession]'s notifiers — it never navigates directly. `AuthGate`
/// (the app's single root widget for this flow) is the one thing watching
/// those notifiers, and swaps itself to the right next screen in place.
class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitchToSignup;
  final VoidCallback? onBack;
  const LoginScreen({super.key, required this.onSwitchToSignup, this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onLogIn() async {
    final email = _email.text.trim();
    final password = _password.text;

    String? emailError;
    String? passwordError;
    if (email.isEmpty) {
      emailError = 'Enter your email address.';
    } else if (!Validators.isValidEmail(email)) {
      emailError = "That doesn't look like a valid email.";
    }
    if (password.isEmpty) passwordError = 'Enter your password.';

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _formError = null;
    });
    if (emailError != null || passwordError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await AccountRepository.login(email: email, password: password);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _formError = e.message;
        });
      }
      return;
    }
    if (!mounted) return;

    final onboarded = await AccountRepository.isOnboardingComplete();
    AccountSession.onboardingComplete.value = onboarded;
    AccountSession.loggedIn.value = true;
  }

  void _showForgotPassword() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ForgotPasswordSheet(initialEmail: _email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to pick up where you left off.',
      onBack: widget.onBack,
      footer: AuthSwitchLink(
        prompt: 'New here?',
        action: 'Create an account',
        onTap: widget.onSwitchToSignup,
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthErrorBanner(message: _formError),
            AuthField(
              label: 'Email',
              hint: 'you@example.com',
              icon: LucideIcons.mail,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: _emailError,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),
            const SizedBox(height: 18),
            AuthField(
              label: 'Password',
              hint: 'Your password',
              icon: LucideIcons.lock,
              controller: _password,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              errorText: _passwordError,
              onSubmitted: (_) => _onLogIn(),
              onChanged: (_) {
                if (_passwordError != null) setState(() => _passwordError = null);
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: p.body,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 12),
            AuthPrimaryButton(
              label: 'Log in',
              loading: _submitting,
              onPressed: _onLogIn,
            ),
          ],
        ),
      ),
    );
  }
}

/// Password reset via Firebase (a working email link). Shown as a bottom
/// sheet with its own "check your inbox" confirmation state, rather than a
/// dialog that closes into a snackbar.
class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  bool _sent = false;
  String? _fieldError;
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _fieldError = 'Enter your email address.');
      return;
    }
    if (!Validators.isValidEmail(email)) {
      setState(() => _fieldError = "That doesn't look like a valid email.");
      return;
    }
    setState(() {
      _fieldError = null;
      _formError = null;
      _sending = true;
    });
    try {
      await AccountRepository.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _formError = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + bottomInset),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _sent ? _buildSent(p) : _buildForm(p),
      ),
    );
  }

  Widget _buildForm(AuthPalette p) {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset your password',
          style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, fontWeight: FontWeight.w600, color: p.title),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the email you signed up with and we'll send you a link to set a new password.",
          style: TextStyle(fontSize: 14, height: 1.45, color: p.body),
        ),
        const SizedBox(height: 24),
        AuthErrorBanner(message: _formError),
        AuthField(
          label: 'Email',
          hint: 'you@example.com',
          icon: LucideIcons.mail,
          controller: _email,
          autofocus: widget.initialEmail.isEmpty,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          errorText: _fieldError,
          onSubmitted: (_) => _send(),
          onChanged: (_) {
            if (_fieldError != null) setState(() => _fieldError = null);
          },
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Send reset link', loading: _sending, onPressed: _send),
      ],
    );
  }

  Widget _buildSent(AuthPalette p) {
    return Column(
      key: const ValueKey('sent'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.mailCheck, color: AppColors.accentGoldDeep, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          'Check your inbox',
          style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, fontWeight: FontWeight.w600, color: p.title),
        ),
        const SizedBox(height: 8),
        Text(
          'If an account exists for ${_email.text.trim()}, a reset link is on its way. '
          "It can take a minute — check your spam folder too.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: p.body),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(label: 'Back to log in', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
