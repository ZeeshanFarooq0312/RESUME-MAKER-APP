import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';
import 'template_thumbnail.dart';

/// Height of the caption (name + tagline) under a template page.
const _captionHeight = 52.0;

/// Grid layout for [TemplateCard]s: 2 columns on phones, more on wider
/// screens, each cell tall enough for an A4 page plus its caption.
SliverGridDelegate templateGridDelegate(double width) {
  final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
  const spacing = 14.0;
  final itemWidth = (width - spacing * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: 18,
    mainAxisExtent: itemWidth * 1.414 + _captionHeight,
  );
}

/// A template shown as a real page: the rendered first page fills an
/// A4-shaped card edge to edge, with the name and tagline underneath.
/// A badge reading "PRO" is drawn as the gold premium tag; any other badge
/// text (e.g. a document kind) is a neutral tag.
class TemplateCard extends StatefulWidget {
  final DocumentKind kind;
  final Object template;
  final String title;
  final String? subtitle;
  final String? badgeText;

  /// Kept for call-site compatibility; badge colors follow the theme.
  final Color badgeBackgroundColor;
  final Color badgeTextColor;
  final VoidCallback onTap;

  const TemplateCard({
    super.key,
    required this.kind,
    required this.template,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badgeText,
    this.badgeBackgroundColor = AppColors.primaryLight,
    this.badgeTextColor = AppColors.primary,
  });

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final badge = widget.badgeText;
    final isPro = badge?.toUpperCase() == 'PRO';
    return Semantics(
      button: true,
      label: '${widget.title} template${isPro ? ', Pro' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.fieldBorder),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TemplateThumbnail(kind: widget.kind, template: widget.template),
                        if (badge != null)
                          Positioned(top: 8, right: 8, child: _Badge(text: badge, pro: isPro)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: _captionHeight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.title),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.body, fontSize: 12.5),
                        ),
                      ],
                    ],
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

class _Badge extends StatelessWidget {
  final String text;
  final bool pro;
  const _Badge({required this.text, required this.pro});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: pro ? AppColors.accentGold : AppColors.ink.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pro) ...[
            const Icon(LucideIcons.crown, size: 10, color: AppColors.ink),
            const SizedBox(width: 3),
          ],
          Text(
            pro ? 'PRO' : text,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: pro ? AppColors.ink : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
