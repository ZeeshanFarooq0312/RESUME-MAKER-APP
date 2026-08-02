import 'package:flutter/material.dart';
import '../models/document_entry.dart';
import '../theme/app_theme.dart';
import 'template_thumbnail.dart';

/// Single template-picker card, replacing four near-identical private
/// `_TemplateCard` classes that used to live one per screen
/// (template_screen.dart, cover_letter_template_screen.dart,
/// proposal_template_screen.dart, templates_tab_screen.dart). Supports both
/// badge styles those screens used: a "PRO" badge (subtitle-bearing resume/
/// cover-letter/proposal picker screens) and a document-kind badge (the
/// combined Templates tab), via the same optional [badgeText] slot.
class TemplateCard extends StatelessWidget {
  final DocumentKind kind;
  final Object template;
  final String title;
  final String? subtitle;
  final String? badgeText;
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: TemplateThumbnail(kind: kind, template: template),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(color: AppColors.slate600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBackgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
