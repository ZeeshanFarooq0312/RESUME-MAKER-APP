import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../models/template_kind.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/template_card.dart';
import '../widgets/template_picker_scaffold.dart';
import 'describe_template_screen.dart';
import 'preview_screen.dart';
import '../pdf/resume_design_presets.dart';

export '../models/template_kind.dart' show ResumeTemplate;

/// One-line description of each resume template, shown under its name.
final resumeTemplateTaglines = <ResumeTemplate, String>{
  ResumeTemplate.classic: 'ATS-friendly',
  ResumeTemplate.modern: 'Color sidebar and photo',
  ResumeTemplate.minimal: 'ATS-friendly',
  ResumeTemplate.professional: 'ATS-friendly',
  ResumeTemplate.compact: 'Fits more on one page',
  ResumeTemplate.executive: 'For senior roles',
  ResumeTemplate.technical: 'Skills up front',
  ResumeTemplate.simpleBold: 'Strong headings',
  ResumeTemplate.harvard: 'Academic classic',
  ResumeTemplate.creative: 'Bold color banner',
  ResumeTemplate.elegant: 'Editorial style',
  ResumeTemplate.timeline: 'Visual work history',
  for (final e in resumeDesignPresets.entries) e.key: e.value.tagline,
};

/// "simpleBold" -> "Simple Bold".
String resumeTemplateLabel(Enum t) {
  final s = t.name.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  return s[0].toUpperCase() + s.substring(1);
}

/// Pick a template for the resume being edited. Tapping a card previews
/// *this* resume in that template straight away (not sample data), so the
/// choice is made by seeing your own content.
class TemplateScreen extends StatelessWidget {
  final ResumeData resumeData;
  final String? documentId;
  const TemplateScreen({super.key, required this.resumeData, this.documentId});

  @override
  Widget build(BuildContext context) {
    return TemplatePickerScaffold(
      title: 'Choose a template',
      subtitle: 'Tap a design to see your resume in it.',
      leading: _DescribeOwnCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DescribeTemplateScreen(resumeData: resumeData, documentId: documentId)),
        ),
      ),
      cards: [
        for (final t in ResumeTemplate.values)
          TemplateCard(
            kind: DocumentKind.resume,
            template: t,
            title: resumeTemplateLabel(t),
            subtitle: resumeTemplateTaglines[t],
            badgeText: t.isPremium ? 'PRO' : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PreviewScreen(
                  resumeData: resumeData,
                  template: t,
                  documentId: documentId,
                  isPremium: t.isPremium,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DescribeOwnCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DescribeOwnCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.6), width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.wandSparkles, color: AppColors.ink, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('Design your own with AI',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.title)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration:
                              BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(999)),
                          child: const Text('PRO',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('Describe the look you want and AI builds it.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: p.body)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
