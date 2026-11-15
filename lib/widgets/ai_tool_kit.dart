import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';

/// Shared building blocks for the AI tool screens (tailor to a job,
/// interview prep, describe a template), so they share one layout.

/// Gold AI icon, large serif title, one-paragraph explanation.
class AiToolHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const AiToolHeader({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: AppColors.ink, size: 24),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 28,
              height: 1.15,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w600,
              color: p.title),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(fontSize: 14.5, height: 1.5, color: p.body)),
      ],
    );
  }
}

/// "1  The job" style step heading.
class StepHeading extends StatelessWidget {
  final int number;
  final String title;
  final String? trailing;
  const StepHeading({super.key, required this.number, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            child: Text('$number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.onPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.title))),
          if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 12.5, color: p.muted)),
        ],
      ),
    );
  }
}

/// Small outlined pill button (Paste, Scan a photo…).
class ToolPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const ToolPill({super.key, required this.icon, required this.label, required this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.surface,
      shape: StadiumBorder(side: BorderSide(color: p.fieldBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.title))
              else
                Icon(icon, size: 15, color: p.title),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.title)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Job-description input: Paste and Scan-a-photo shortcuts, a tall field,
/// and a live word count.
class JobDescriptionField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onScan;
  final bool scanning;
  const JobDescriptionField({super.key, required this.controller, this.onScan, this.scanning = false});

  @override
  State<JobDescriptionField> createState() => _JobDescriptionFieldState();
}

class _JobDescriptionFieldState extends State<JobDescriptionField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    final existing = widget.controller.text.trim();
    widget.controller.text = existing.isEmpty ? text : '$existing\n\n$text';
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final text = widget.controller.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ToolPill(icon: LucideIcons.clipboardPaste, label: 'Paste', onPressed: _paste),
            if (widget.onScan != null) ...[
              const SizedBox(width: 8),
              ToolPill(
                icon: LucideIcons.camera,
                label: widget.scanning ? 'Reading photo…' : 'Scan a photo',
                busy: widget.scanning,
                onPressed: widget.onScan,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AuthField(
          dense: true,
          label: 'Job description',
          hint: 'Paste the full job posting, including responsibilities and requirements.',
          controller: widget.controller,
          maxLines: 12,
          minLines: 7,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 6),
        Text(
          words == 0 ? 'The more detail, the better the result.' : '$words words',
          style: TextStyle(fontSize: 12, color: p.muted),
        ),
      ],
    );
  }
}

/// Bottom bar holding the screen's single primary action.
class AiActionBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;
  const AiActionBar({super.key, required this.label, required this.icon, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(color: p.background, border: Border(top: BorderSide(color: p.fieldBorder))),
        child: AuthPrimaryButton(label: label, trailingIcon: icon, loading: loading, onPressed: onPressed),
      ),
    );
  }
}
