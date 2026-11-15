import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'auth/auth_kit.dart';
import 'responsive_scaffold.dart';
import 'template_card.dart';

/// Shared layout for the "choose a template for this document" pickers:
/// title, short hint, optional lead card, and a grid of [TemplateCard]s.
class TemplatePickerScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading;
  final List<Widget> cards;

  const TemplatePickerScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cards,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContentBound(
          maxWidth: 1040,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 28,
                          height: 1.15,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w600,
                          color: p.title,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 14.5, height: 1.4, color: p.body)),
                      if (leading != null) ...[const SizedBox(height: 16), leading!],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) => SliverGrid(
                    gridDelegate: templateGridDelegate(constraints.crossAxisExtent),
                    delegate: SliverChildListDelegate(cards),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
