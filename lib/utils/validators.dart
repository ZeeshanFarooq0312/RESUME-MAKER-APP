/// Shared input validation for the auth flow (signup, login, password
/// reset) — kept in one place so "valid email" and "strong password" mean
/// the same thing everywhere they're checked.
class Validators {
  const Validators._();

  static final _emailPattern = RegExp(r'^[\w.+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$');

  static bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

  /// User-facing description of the bar new passwords must clear, shown as
  /// helper text under the field.
  static const passwordRequirements =
      'At least 8 characters, with uppercase, lowercase, a number, and a symbol.';

  static final _upper = RegExp(r'[A-Z]');
  static final _lower = RegExp(r'[a-z]');
  static final _digit = RegExp(r'[0-9]');
  static final _symbol = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]/\\+=~`]');

  /// Returns null when [password] clears the strength bar, otherwise a
  /// message naming the first unmet requirement — checked in order so the
  /// user fixes one thing at a time rather than seeing every rule at once.
  static String? passwordStrengthError(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!_upper.hasMatch(password)) return 'Password must include an uppercase letter.';
    if (!_lower.hasMatch(password)) return 'Password must include a lowercase letter.';
    if (!_digit.hasMatch(password)) return 'Password must include a number.';
    if (!_symbol.hasMatch(password)) return r'Password must include a symbol (e.g. ! @ # $).';
    return null;
  }
}
