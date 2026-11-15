import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A 4-segment strength bar for the signup password field. Segment count
/// mirrors the rule order in [Validators.passwordStrengthError] (length,
/// case mix, digit, symbol) so the bar and the error message never
/// disagree about what "strong" means.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({super.key, required this.password});

  int get _score {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]/\\+=~`]').hasMatch(password)) score++;
    return score;
  }

  Color get _color {
    switch (_score) {
      case 4:
      case 3:
        return AppColors.success;
      case 2:
        return AppColors.accentGoldDeep;
      case 1:
        return AppColors.danger;
      default:
        return AppColors.cardBorder;
    }
  }

  String get _label {
    switch (_score) {
      case 4:
        return 'Strong password';
      case 3:
        return 'Good password';
      case 2:
        return 'Weak password';
      case 1:
        return 'Very weak password';
      default:
        return 'At least 8 characters, with uppercase, lowercase, a number, and a symbol.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < _score ? _color : AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(_label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
        ],
      ),
    );
  }
}
