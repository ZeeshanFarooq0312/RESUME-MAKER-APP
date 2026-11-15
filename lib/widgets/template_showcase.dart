import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../screens/template_screen.dart' show resumeTemplateLabel, resumeTemplateTaglines;
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';
import 'filter_chip_row.dart';
import 'template_thumbnail.dart';

enum _Collection { fresh, popular, ats, creative }

const _collections = {
  _Collection.fresh: [
    ResumeTemplate.aurora,
    ResumeTemplate.meridian,
    ResumeTemplate.vivid,
    ResumeTemplate.heritage,
    ResumeTemplate.nova,
    ResumeTemplate.graphite,
  ],
  _Collection.popular: [
    ResumeTemplate.modern,
    ResumeTemplate.aurora,
    ResumeTemplate.classic,
    ResumeTemplate.sterling,
    ResumeTemplate.professional,
    ResumeTemplate.horizon,
  ],
  _Collection.ats: [
    ResumeTemplate.classic,
    ResumeTemplate.sterling,
    ResumeTemplate.minimal,
    ResumeTemplate.ivy,
    ResumeTemplate.harvard,
    ResumeTemplate.meridian,
  ],
  _Collection.creative: [
    ResumeTemplate.nova,
    ResumeTemplate.creative,
    ResumeTemplate.ember,
    ResumeTemplate.vivid,
    ResumeTemplate.timeline,
    ResumeTemplate.quartz,
  ],
};

const _collectionLabels = {
  _Collection.fresh: 'New',
  _Collection.popular: 'Popular',
  _Collection.ats: 'ATS-friendly',
  _Collection.creative: 'Creative',
};

/// Home's "Templates for you": curated collections of resume templates shown
/// as real, page-proportioned previews in a horizontal carousel, ending in a
/// "browse all" card.
class TemplateShowcase extends StatefulWidget {
  final ValueChanged<ResumeTemplate> onOpen;
  final VoidCallback? onSeeAll;
  final int totalTemplates;

  const TemplateShowcase({super.key, required this.onOpen, required this.totalTemplates, this.onSeeAll});

  @override
  State<TemplateShowcase> createState() => _TemplateShowcaseState();
}

class _TemplateShowcaseState extends State<TemplateShowcase> {
  _Collection _collection = _Collection.fresh;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(_Collection c) {
    if (c == _collection) return;
    setState(() => _collection = c);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final templates = _collections[_collection]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Templates for you',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.title)),
                  const SizedBox(height: 2),
                  Text('Pick a look. Your details fill it in.', style: TextStyle(fontSize: 13, color: p.body)),
                ],
              ),
            ),
            if (widget.onSeeAll != null)
              TextButton(
                onPressed: widget.onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: p.link,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        FilterChipRow<_Collection>(
          options: _Collection.values,
          selected: _collection,
          labelFor: (c) => _collectionLabels[c]!,
          onSelected: _select,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // ~2.3 cards per row on a phone, so the next one peeks in and
            // invites a swipe; capped so tablets don't get giant pages.
            final cardWidth = (constraints.maxWidth / 2.3).clamp(132.0, 190.0);
            final pageHeight = cardWidth * 1.414; // A4
            return SizedBox(
              height: pageHeight + 58,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: ListView.separated(
                  key: ValueKey(_collection),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: templates.length + (widget.onSeeAll != null ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    if (i == templates.length) {
                      return _BrowseAllCard(
                        width: cardWidth,
                        pageHeight: pageHeight,
                        total: widget.totalTemplates,
                        onTap: widget.onSeeAll!,
                      );
                    }
                    final t = templates[i];
                    return _ShowcaseCard(
                      template: t,
                      width: cardWidth,
                      pageHeight: pageHeight,
                      onTap: () => widget.onOpen(t),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Scales down slightly while pressed.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  const _Pressable({required this.child, required this.onTap, required this.semanticLabel});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  final ResumeTemplate template;
  final double width;
  final double pageHeight;
  final VoidCallback onTap;

  const _ShowcaseCard({required this.template, required this.width, required this.pageHeight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final name = resumeTemplateLabel(template);
    return _Pressable(
      onTap: onTap,
      semanticLabel: '$name template${template.isPremium ? ', Pro' : ''}',
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: pageHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.fieldBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TemplateThumbnail(kind: DocumentKind.resume, template: template),
                    if (template.isPremium)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: _ProBadge(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.title),
            ),
            const SizedBox(height: 2),
            Text(
              resumeTemplateTaglines[template] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: p.body),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentGold,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.crown, size: 10, color: AppColors.ink),
          SizedBox(width: 3),
          Text('PRO', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _BrowseAllCard extends StatelessWidget {
  final double width;
  final double pageHeight;
  final int total;
  final VoidCallback onTap;

  const _BrowseAllCard({required this.width, required this.pageHeight, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    Widget miniPage() => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: p.fieldBorder),
          ),
        );
    return _Pressable(
      onTap: onTap,
      semanticLabel: 'Browse all $total templates',
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: pageHeight,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.fieldBorder),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.707,
                      children: List.generate(4, (_) => miniPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                    child: Icon(LucideIcons.arrowRight, size: 20, color: p.onPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('Browse all',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.title)),
            const SizedBox(height: 2),
            Text('$total templates', style: TextStyle(fontSize: 12.5, color: p.body)),
          ],
        ),
      ),
    );
  }
}
