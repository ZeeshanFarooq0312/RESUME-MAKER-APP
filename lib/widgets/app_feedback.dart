import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';

/// App-wide feedback: toasts, blocking progress, and input sheets. Every
/// screen goes through these (plus [showPromptSheet] in auth_kit.dart for
/// confirmations) so feedback looks and behaves the same everywhere.

enum ToastTone { info, success, error }

/// Floating toast with a tone icon. Success/error get a distinct icon and
/// color so a failure never looks like a confirmation.
void showToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final (IconData icon, Color color) = switch (tone) {
    ToastTone.success => (LucideIcons.circleCheck, const Color(0xFF4ADE80)),
    ToastTone.error => (LucideIcons.circleAlert, const Color(0xFFFF7A8A)),
    ToastTone.info => (LucideIcons.info, AppColors.accentGold),
  };
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: duration ?? Duration(milliseconds: tone == ToastTone.error ? 5000 : 3200),
      content: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction, textColor: AppColors.accentGold)
          : null,
    ));
}

/// Blocking "working…" card. Close it with
/// `Navigator.of(context, rootNavigator: true).pop()`, as before.
void showProgressOverlay(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) {
      final p = AuthPalette.of(context);
      return PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.accentGoldDeep),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: p.title),
                    ),
                    const SizedBox(height: 4),
                    Text('This can take a few seconds.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.body)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// One field in [showInputSheet].
class SheetField {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final IconData? icon;
  final bool required;
  const SheetField({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.required = false,
  });
}

/// Bottom sheet with a title, short message and labeled fields. The primary
/// button enables live once every `required` field has text. Resolves to
/// true when submitted.
Future<bool> showInputSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? message,
  required List<SheetField> fields,
  required String primaryLabel,
  IconData? primaryIcon,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _InputSheet(
      icon: icon,
      title: title,
      message: message,
      fields: fields,
      primaryLabel: primaryLabel,
      primaryIcon: primaryIcon,
    ),
  );
  return result == true;
}

class _InputSheet extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? message;
  final List<SheetField> fields;
  final String primaryLabel;
  final IconData? primaryIcon;
  const _InputSheet({
    required this.icon,
    required this.title,
    required this.message,
    required this.fields,
    required this.primaryLabel,
    required this.primaryIcon,
  });

  @override
  State<_InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<_InputSheet> {
  bool get _valid => widget.fields.every((f) => !f.required || f.controller.text.trim().isNotEmpty);

  void _submit() {
    if (_valid) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(12)),
                  child: Icon(widget.icon, size: 21, color: p.title),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                        fontFamily: 'Fraunces', fontSize: 22, height: 1.2, fontWeight: FontWeight.w600, color: p.title),
                  ),
                ),
              ],
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 10),
              Text(widget.message!, style: TextStyle(fontSize: 14, height: 1.45, color: p.body)),
            ],
            const SizedBox(height: 20),
            for (var i = 0; i < widget.fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              AuthField(
                dense: true,
                label: widget.fields[i].required ? '${widget.fields[i].label} *' : widget.fields[i].label,
                hint: widget.fields[i].hint,
                icon: widget.fields[i].icon,
                controller: widget.fields[i].controller,
                autofocus: i == 0,
                textCapitalization: TextCapitalization.words,
                textInputAction: i == widget.fields.length - 1 ? TextInputAction.done : TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onSubmitted: i == widget.fields.length - 1 ? (_) => _submit() : null,
              ),
            ],
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: widget.primaryLabel,
              trailingIcon: widget.primaryIcon,
              onPressed: _valid ? _submit : null,
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: p.body),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
