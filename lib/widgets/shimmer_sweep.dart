import 'package:flutter/material.dart';

/// Loops a diagonal light-sweep across [child] — the "premium card" shine
/// effect used by the subscription plan card. Owns its own ticker so it can
/// just be wrapped around any child without the caller managing animation
/// state.
class ShimmerSweep extends StatefulWidget {
  final Widget child;
  final Duration period;
  /// Must match [child]'s own corner radius, or the sweep overlay (drawn as
  /// a sibling on top, not clipped by the child's own decoration) will
  /// visibly poke past the child's rounded corners.
  final BorderRadius borderRadius;
  const ShimmerSweep({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 4500),
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Sweeps from just off the left edge to just off the
                      // right edge, matching the mockup's translateX(-120%)
                      // -> translateX(220%) keyframe range.
                      final width = constraints.maxWidth;
                      final dx = -0.6 * width + _controller.value * 2.2 * width;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Transform.rotate(
                          angle: 0.14,
                          child: Container(
                            width: width * 0.18,
                            height: constraints.maxHeight * 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.14),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft blurred-looking radial glow, meant to sit partly off the edge of a
/// dark hero container — adds depth behind the content without a real image
/// asset. Shared by every dark "ink" hero section (Paywall, onboarding).
class GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const GlowBlob({super.key, required this.color, required this.size, this.opacity = 0.35});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Loops a small vertical bob on [child] — used for the floating badge icon
/// on the subscription plan card.
class FloatBob extends StatefulWidget {
  final Widget child;
  final Duration period;
  const FloatBob({super.key, required this.child, this.period = const Duration(milliseconds: 3200)});

  @override
  State<FloatBob> createState() => _FloatBobState();
}

class _FloatBobState extends State<FloatBob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  late final Animation<double> _offset = Tween<double>(begin: 0, end: -4)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(offset: Offset(0, _offset.value), child: child),
      child: widget.child,
    );
  }
}
