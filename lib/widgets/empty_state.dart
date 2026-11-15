import 'package:flutter/material.dart';
import 'auth/auth_kit.dart';

/// Shared "nothing here yet" treatment: icon in a soft tile, headline,
/// short explanation, and an optional call to action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.fieldBorder),
                ),
                child: Icon(icon, color: p.title, size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Fraunces', fontSize: 22, height: 1.2, fontWeight: FontWeight.w600, color: p.title),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.body, fontSize: 14.5, height: 1.5),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: AuthPrimaryButton(label: actionLabel!, onPressed: onAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
