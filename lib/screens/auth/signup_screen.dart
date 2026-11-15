import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/account_repository.dart';
import '../../utils/validators.dart';
import '../../widgets/auth/auth_kit.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/password_strength_meter.dart';

/// Create a real Firebase account. On success this only flips
/// [AccountSession]'s notifiers — it never navigates directly. `AuthGate`
/// (the app's single root widget for this flow) is the one thing watching
/// those notifiers, and swaps itself to the onboarding flow in place.
class SignupScreen extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  final VoidCallback? onBack;
  const SignupScreen({super.key, required this.onSwitchToLogin, this.onBack});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitting = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    final fullName = _fullName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    final nameError = fullName.isEmpty ? 'Enter your full name.' : null;
    final emailError = email.isEmpty
        ? 'Enter your email address.'
        : !Validators.isValidEmail(email)
            ? "That doesn't look like a valid email."
            : null;
    final passwordError =
        password.isEmpty ? 'Create a password.' : Validators.passwordStrengthError(password);
    final confirmError = passwordError == null && password != _confirmPassword.text
        ? "Passwords don't match."
        : null;

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
      _formError = null;
    });
    if (nameError != null || emailError != null || passwordError != null || confirmError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await AccountRepository.signUp(fullName: fullName, email: email, password: password);
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
    AccountSession.onboardingComplete.value = false;
    AccountSession.loggedIn.value = true;
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Your first professional resume is a few minutes away.',
      onBack: widget.onBack,
      footer: AuthSwitchLink(
        prompt: 'Already have an account?',
        action: 'Log in',
        onTap: widget.onSwitchToLogin,
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthErrorBanner(message: _formError),
            AuthField(
              label: 'Full name',
              hint: 'e.g. Sarah Ahmed',
              icon: LucideIcons.user,
              controller: _fullName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 18),
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
              hint: 'At least 8 characters',
              icon: LucideIcons.lock,
              controller: _password,
              isPassword: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _passwordError,
              onChanged: (_) {
                if (_passwordError != null) setState(() => _passwordError = null);
              },
            ),
            if (_password.text.isNotEmpty && _passwordError == null) ...[
              const SizedBox(height: 10),
              PasswordStrengthMeter(password: _password.text),
            ],
            const SizedBox(height: 18),
            AuthField(
              label: 'Confirm password',
              hint: 'Re-enter your password',
              icon: LucideIcons.lock,
              controller: _confirmPassword,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _confirmError,
              onSubmitted: (_) => _onSignUp(),
              onChanged: (_) {
                if (_confirmError != null) setState(() => _confirmError = null);
              },
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              label: 'Create account',
              loading: _submitting,
              onPressed: _onSignUp,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.shieldCheck, size: 15, color: p.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Your profile and documents stay on this device.',
                    style: TextStyle(fontSize: 12.5, color: p.body),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
