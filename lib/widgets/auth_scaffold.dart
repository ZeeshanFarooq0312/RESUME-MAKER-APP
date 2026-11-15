import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';
import 'shimmer_sweep.dart';

/// Shared layout for Login and Signup: a calm, light page with a brand
/// anchor (or back button) at the top, a large editorial headline, the form,
/// and a footer pinned to the bottom. Content is width-capped so it doesn't
/// stretch on tablets, and fades in on entry.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  /// When set, shows a back button and routes the system back gesture to
  /// it. AuthGate swaps screens in place instead of pushing routes, so
  /// without this the back gesture would close the app.
  final VoidCallback? onBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);

    Widget page = Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          // A single warm glow in the corner gives the page depth without
          // competing with the form.
          const Positioned(
            top: -140,
            right: -110,
            child: GlowBlob(color: AppColors.accentGold, size: 320, opacity: 0.16),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (onBack != null) ...[
                                  AuthBackButton(onPressed: onBack!),
                                  const Spacer(),
                                  const BrandMark(size: 32, showName: false),
                                ] else
                                  const BrandMark(size: 36),
                              ],
                            ),
                            const SizedBox(height: 40),
                            FadeSlideIn(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Fraunces',
                                      fontSize: 32,
                                      height: 1.12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.4,
                                      color: p.title,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    subtitle,
                                    style: TextStyle(fontSize: 15, height: 1.45, color: p.body),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 90),
                              child: child,
                            ),
                            const Spacer(),
                            if (footer != null) ...[
                              const SizedBox(height: 24),
                              footer!,
                            ],
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onBack != null) {
      page = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onBack!();
        },
        child: page,
      );
    }
    return page;
  }
}
