import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';

/// Colors for the pre-app screens (welcome, login, signup, onboarding),
/// resolved from the current brightness so they look deliberate in both
/// themes instead of hardcoding light-only values.
class AuthPalette {
  final Color background;
  final Color surface;
  final Color fieldFill;
  final Color fieldBorder;
  final Color focus;
  final Color focusRing;
  final Color title;
  final Color body;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color link;

  const AuthPalette._({
    required this.background,
    required this.surface,
    required this.fieldFill,
    required this.fieldBorder,
    required this.focus,
    required this.focusRing,
    required this.title,
    required this.body,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.link,
  });

  static const _light = AuthPalette._(
    background: AppColors.background,
    surface: Colors.white,
    fieldFill: Colors.white,
    fieldBorder: Color(0xFFE4E2EE),
    focus: AppColors.ink,
    focusRing: Color(0x1414121F),
    title: AppColors.ink,
    body: AppColors.slate600,
    muted: AppColors.slate400,
    primary: AppColors.ink,
    onPrimary: Colors.white,
    link: AppColors.ink,
  );

  static const _dark = AuthPalette._(
    background: AppColors.ink,
    surface: AppColors.slate900,
    fieldFill: AppColors.slate900,
    fieldBorder: AppColors.slate800,
    focus: AppColors.accentGold,
    focusRing: Color(0x29FFB454),
    title: Colors.white,
    body: Color(0xB3FFFFFF),
    muted: AppColors.slate400,
    primary: AppColors.accentGold,
    onPrimary: AppColors.ink,
    link: AppColors.accentGold,
  );

  static AuthPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

/// Labeled text input for the auth/onboarding screens: label above, leading
/// icon, filled box with an animated focus ring, inline per-field error,
/// and a built-in show/hide toggle for passwords.
class AuthField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final IconData? icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool autofocus;

  /// Shorter box and smaller label, for longer forms (profile, etc.).
  final bool dense;
  final int maxLines;
  final int? minLines;

  /// Supply when something else (e.g. Autocomplete) owns the focus node.
  final FocusNode? focusNode;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.autofocus = false,
    this.dense = false,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());
  late bool _obscured = widget.isPassword;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.danger
        : _focused
            ? p.focus
            : p.fieldBorder;
    final iconColor = hasError
        ? AppColors.danger
        : _focused
            ? p.focus
            : p.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
              fontSize: widget.dense ? 12.5 : 13, fontWeight: FontWeight.w600, color: p.title, letterSpacing: 0.1),
        ),
        SizedBox(height: widget.dense ? 6 : 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: p.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: _focused || hasError ? 1.5 : 1),
            boxShadow: [
              if (_focused)
                BoxShadow(
                  color: hasError ? AppColors.danger.withValues(alpha: 0.12) : p.focusRing,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Icon(widget.icon, size: 20, color: iconColor),
                ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  obscureText: _obscured,
                  maxLines: widget.isPassword ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  enableSuggestions: !widget.isPassword,
                  autocorrect: !widget.isPassword,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  autofillHints: widget.autofillHints,
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  cursorColor: p.focus,
                  style: TextStyle(
                      fontSize: widget.dense ? 14.5 : 15.5, height: 1.35, fontWeight: FontWeight.w500, color: p.title),
                  decoration: InputDecoration(
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                        fontSize: widget.dense ? 14.5 : 15.5, fontWeight: FontWeight.w400, color: p.muted),
                    contentPadding: EdgeInsets.fromLTRB(
                        widget.icon != null ? 12 : 14, widget.dense ? 13 : 17, 14, widget.dense ? 13 : 17),
                  ),
                ),
              ),
              if (widget.isPassword)
                IconButton(
                  tooltip: _obscured ? 'Show password' : 'Hide password',
                  splashRadius: 20,
                  icon: Icon(
                    _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 20,
                    color: p.muted,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 7, left: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(LucideIcons.circleAlert, size: 14, color: AppColors.danger),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.errorText!,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.danger, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Full-width 56px primary CTA. While [loading], it keeps its color and
/// swaps the label for a spinner (rather than greying out), so the button
/// doesn't flash to a disabled state mid-request.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? trailingIcon;

  /// Overrides the background (e.g. danger red for destructive actions).
  final Color? color;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.trailingIcon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final bg = color ?? p.primary;
    final fg = color != null ? Colors.white : p.onPrimary;
    return AbsorbPointer(
      absorbing: loading,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.4),
            disabledForegroundColor: fg.withValues(alpha: 0.8),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: loading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailingIcon, size: 18),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Outlined 56px secondary action, paired under [AuthPrimaryButton].
class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthSecondaryButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.title,
          side: BorderSide(color: p.fieldBorder, width: 1.2),
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Form-level error (e.g. "Incorrect email or password") shown as a soft
/// tinted banner instead of a loose line of red text. Animates in/out on
/// its own when [message] changes to/from null.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.circleAlert, size: 18, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message!,
                        style: const TextStyle(
                            fontSize: 13.5, height: 1.35, color: AppColors.danger, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// "Prompt? Action" footer row used to switch between login and signup.
class AuthSwitchLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const AuthSwitchLink({super.key, required this.prompt, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: TextStyle(fontSize: 14, color: p.body)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: p.link,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// App icon + wordmark, used as the top-left brand anchor on pre-app screens.
class BrandMark extends StatelessWidget {
  final double size;
  final bool showName;
  const BrandMark({super.key, this.size = 36, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.28),
            child: Image.asset('assets/icon/icon_master.png', fit: BoxFit.cover),
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 10),
          Text(
            'Resume Builder',
            style: TextStyle(fontFamily: 'Fraunces', fontSize: 17, fontWeight: FontWeight.w600, color: p.title),
          ),
        ],
      ],
    );
  }
}

/// Round back button for pre-app screens.
class AuthBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const AuthBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.surface,
      shape: CircleBorder(side: BorderSide(color: p.fieldBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: p.title),
        ),
      ),
    );
  }
}

/// One-shot fade + rise entrance for screen content.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
  });

  @override
  Widget build(BuildContext context) {
    final total = delay + duration;
    final start = total.inMilliseconds == 0 ? 0.0 : delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, child) {
        final local = start >= 1 ? 1.0 : ((t - start) / (1 - start)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(local);
        return Opacity(
          opacity: eased,
          child: Transform.translate(offset: Offset(0, 18 * (1 - eased)), child: child),
        );
      },
      child: child,
    );
  }
}

/// "STEP 1 OF 2 · Label" plus a segmented progress bar, for multi-step
/// onboarding screens.
class StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final String label;
  const StepIndicator({super.key, required this.current, required this.total, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'STEP $current OF $total',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: p.title),
              ),
              TextSpan(text: '   ·   $label', style: TextStyle(color: p.body)),
            ],
          ),
          style: const TextStyle(fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? p.primary : p.fieldBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

enum PromptTone { info, error }

/// Bottom-sheet replacement for plain AlertDialogs: icon, serif title, short
/// message, and a primary + optional secondary action. Resolves to true for
/// the primary action, false for the secondary, null if dismissed.
Future<bool?> showPromptSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String primaryLabel,
  String? secondaryLabel,
  PromptTone tone = PromptTone.info,
  bool destructive = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      final p = AuthPalette.of(context);
      final accent = tone == PromptTone.error ? AppColors.danger : AppColors.accentGoldDeep;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 18),
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
              style: TextStyle(fontSize: 14.5, height: 1.5, color: p.body),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: primaryLabel,
              color: destructive ? AppColors.danger : null,
              onPressed: () => Navigator.pop(context, true),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: p.body,
                    textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
