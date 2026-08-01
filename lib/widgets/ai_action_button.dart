import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pill-shaped button used for every AI-assisted action (rewrite/generate
/// buttons in the resume, cover letter, and proposal forms) so AI actions
/// read as one consistent, distinct affordance rather than a plain text
/// button that blends into the rest of the form.
class AiActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const AiActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : const LinearGradient(
                    colors: [AppColors.primaryLight, Color(0xFFE3DDFB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: disabled ? AppColors.slate100 : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: disabled ? const Color(0xFFE7E5F3) : AppColors.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                Icon(Icons.auto_awesome, size: 15, color: disabled ? AppColors.slate400 : AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: disabled ? AppColors.slate400 : AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
