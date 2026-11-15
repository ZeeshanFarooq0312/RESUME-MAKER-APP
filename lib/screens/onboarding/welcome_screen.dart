import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_kit.dart';
import '../../widgets/shimmer_sweep.dart';

/// First-launch intro: three slides that show (not just tell) what the app
/// does, then hand off to Sign Up or Log In. All artwork is built from
/// widgets rather than image assets, so it stays sharp, themeable and tiny.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogIn;

  const WelcomeScreen({super.key, required this.onGetStarted, required this.onLogIn});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _SlideData {
  final String title;
  final String body;
  final Widget Function(bool active) art;
  const _SlideData(this.title, this.body, this.art);
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  int _page = 0;

  static final _slides = <_SlideData>[
    _SlideData(
      'A resume that looks the part',
      'Choose a professionally designed template and fill in your details once. '
          'Layout, spacing and typography are handled for you.',
      (active) => _TemplatesArt(active: active),
    ),
    _SlideData(
      'Write with AI, not from scratch',
      'Turn rough notes into sharp bullet points, tailor your resume to each job, '
          'and draft cover letters in seconds.',
      (active) => _AiWriteArt(active: active),
    ),
    _SlideData(
      'Get past the screening software',
      'Check your ATS score before you apply and see exactly what to fix, '
          'so a real person actually reads your resume.',
      (active) => _AtsArt(active: active),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    _controller.animateToPage(
      _slides.length - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const BrandMark(size: 32),
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: isLast ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: IgnorePointer(
                            ignoring: isLast,
                            child: TextButton(
                              onPressed: _skip,
                              style: TextButton.styleFrom(
                                foregroundColor: p.body,
                                textStyle: const TextStyle(
                                    fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              child: const Text('Skip'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _Slide(data: _slides[i], active: i == _page),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    children: [
                      _PageDots(count: _slides.length, index: _page),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(
                        label: 'Get started',
                        trailingIcon: LucideIcons.arrowRight,
                        onPressed: widget.onGetStarted,
                      ),
                      const SizedBox(height: 12),
                      AuthSecondaryButton(label: 'I already have an account', onPressed: widget.onLogIn),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final _SlideData data;
  final bool active;
  const _Slide({required this.data, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Expanded(child: _ArtPanel(child: data.art(active))),
          const SizedBox(height: 28),
          Text(
            data.title,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 28,
              height: 1.15,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w600,
              color: p.title,
            ),
          ),
          const SizedBox(height: 10),
          Text(data.body, style: TextStyle(fontSize: 15, height: 1.5, color: p.body)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// The dark "ink" stage each illustration sits on — same hero language as
/// the paywall and settings plan card.
class _ArtPanel extends StatelessWidget {
  final Widget child;
  const _ArtPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.ink, AppColors.slate900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Stack(
          children: [
            const Positioned(top: -70, right: -50, child: GlowBlob(color: AppColors.accentGold, size: 220, opacity: 0.22)),
            const Positioned(bottom: -90, left: -60, child: GlowBlob(color: Color(0xFF7B6CF6), size: 240, opacity: 0.18)),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: child)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int index;
  const _PageDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? p.primary : p.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Illustrations
// ---------------------------------------------------------------------------

Widget _bar(double width, Color color, {double height = 6}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
    );

/// A miniature resume page, used as the "paper" in the first two slides.
class _MiniResume extends StatelessWidget {
  final double width;
  final Color accent;
  final bool shadow;
  const _MiniResume({this.width = 168, this.accent = AppColors.ink, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    const line = Color(0xFFE9E7F2);
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (shadow)
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep]),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width * 0.42, accent, height: 7),
                  const SizedBox(height: 5),
                  _bar(width * 0.28, AppColors.slate400.withValues(alpha: 0.6), height: 5),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _bar(width * 0.26, accent.withValues(alpha: 0.75), height: 5),
          const SizedBox(height: 7),
          _bar(width * 0.82, line),
          const SizedBox(height: 5),
          _bar(width * 0.74, line),
          const SizedBox(height: 5),
          _bar(width * 0.55, line),
          const SizedBox(height: 12),
          _bar(width * 0.3, accent.withValues(alpha: 0.75), height: 5),
          const SizedBox(height: 7),
          _bar(width * 0.8, line),
          const SizedBox(height: 5),
          _bar(width * 0.66, line),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final w in [0.2, 0.24, 0.16]) ...[
                Container(
                  width: width * w,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool gold;
  const _Chip({required this.icon, required this.label, this.gold = false});

  @override
  Widget build(BuildContext context) {
    const fg = AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: gold ? const LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep]) : null,
        color: gold ? null : Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: gold ? fg : AppColors.success),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Slide 1: three resume pages fanning out, with an "ATS-friendly" tag.
class _TemplatesArt extends StatelessWidget {
  final bool active;
  const _TemplatesArt({required this.active});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, _) {
        return SizedBox(
          width: 300,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(-62 * t, 14 * t),
                child: Transform.rotate(
                  angle: -0.16 * t,
                  child: const Opacity(opacity: 0.55, child: _MiniResume(width: 150, accent: Color(0xFF3D6FD8), shadow: false)),
                ),
              ),
              Transform.translate(
                offset: Offset(62 * t, 14 * t),
                child: Transform.rotate(
                  angle: 0.16 * t,
                  child: const Opacity(opacity: 0.75, child: _MiniResume(width: 150, accent: Color(0xFF2E9E6C), shadow: false)),
                ),
              ),
              const _MiniResume(width: 172),
              Positioned(
                top: 6,
                right: 4,
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: const FloatBob(child: _Chip(icon: LucideIcons.circleCheck, label: 'ATS-friendly')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Slide 2: an experience entry with one bullet being rewritten by AI.
class _AiWriteArt extends StatelessWidget {
  final bool active;
  const _AiWriteArt({required this.active});

  @override
  Widget build(BuildContext context) {
    const line = Color(0xFFE9E7F2);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        return SizedBox(
          width: 300,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 240,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 14)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.briefcase, size: 15, color: AppColors.slate600),
                        SizedBox(width: 6),
                        Text('EXPERIENCE',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Product Designer',
                        style: TextStyle(
                            fontFamily: 'Fraunces', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    const Text('Northwind  ·  2022 – Present',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.slate400)),
                    const SizedBox(height: 14),
                    _bulletRow(child: _bar(170, line)),
                    const SizedBox(height: 9),
                    // The line being "written": a gold highlight sweeping in.
                    _bulletRow(
                      gold: true,
                      child: Stack(
                        children: [
                          _bar(180, AppColors.accentGold.withValues(alpha: 0.18), height: 8),
                          Container(
                            width: 180 * t,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(
                                colors: [AppColors.accentGold, AppColors.accentGoldDeep],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    _bulletRow(child: _bar(140, line)),
                  ],
                ),
              ),
              const Positioned(
                top: 18,
                right: 0,
                child: FloatBob(
                  child: _Chip(icon: LucideIcons.sparkles, label: 'Improve with AI', gold: true),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 6,
                child: Opacity(
                  opacity: Curves.easeIn.transform(t),
                  child: const _Chip(icon: LucideIcons.circleCheck, label: 'Tailored to the job'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _bulletRow({required Widget child, bool gold = false}) => Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold ? AppColors.accentGoldDeep : AppColors.slate400,
            ),
          ),
          const SizedBox(width: 8),
          child,
        ],
      );
}

/// Slide 3: an ATS score gauge counting up, with what it checks.
class _AtsArt extends StatelessWidget {
  final bool active;
  const _AtsArt({required this.active});

  static const _target = 92;
  static const _checks = ['Keywords matched', 'Clean formatting', 'Clear sections'];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: const Duration(milliseconds: 1300),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return SizedBox(
          width: 300,
          height: 280,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _GaugePainter(progress: t * _target / 100),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(t * _target).round()}',
                          style: const TextStyle(
                            fontFamily: 'Fraunces',
                            fontSize: 48,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ATS SCORE',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _checks.length; i++)
                    Opacity(
                      opacity: ((t - i * 0.2) / 0.4).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.check, size: 14, color: AppColors.accentGold),
                            const SizedBox(width: 5),
                            Text(
                              _checks[i],
                              style: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  _GaugePainter({required this.progress});

  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, track);

    if (progress <= 0) return;
    final value = Paint()
      ..color = AppColors.accentGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep * progress.clamp(0.0, 1.0), false, value);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}
