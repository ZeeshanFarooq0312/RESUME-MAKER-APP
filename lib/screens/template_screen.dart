import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../models/template_kind.dart';
import '../theme/app_theme.dart';
import '../widgets/template_thumbnail.dart';
import 'preview_screen.dart';

export '../models/template_kind.dart' show ResumeTemplate;

class TemplateScreen extends StatelessWidget {
  final ResumeData resumeData;
  final String? documentId;
  const TemplateScreen({super.key, required this.resumeData, this.documentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Template')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
          children: [
            _TemplateCard(
              title: 'Classic',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.classic,
              onTap: () => _openPreview(context, ResumeTemplate.classic),
            ),
            _TemplateCard(
              title: 'Modern',
              subtitle: 'Color sidebar + photo',
              isPremium: true,
              template: ResumeTemplate.modern,
              onTap: () => _openPreview(context, ResumeTemplate.modern),
            ),
            _TemplateCard(
              title: 'Minimal',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.minimal,
              onTap: () => _openPreview(context, ResumeTemplate.minimal),
            ),
            _TemplateCard(
              title: 'Professional',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.professional,
              onTap: () => _openPreview(context, ResumeTemplate.professional),
            ),
            _TemplateCard(
              title: 'Compact',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.compact,
              onTap: () => _openPreview(context, ResumeTemplate.compact),
            ),
            _TemplateCard(
              title: 'Executive',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.executive,
              onTap: () => _openPreview(context, ResumeTemplate.executive),
            ),
            _TemplateCard(
              title: 'Technical',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.technical,
              onTap: () => _openPreview(context, ResumeTemplate.technical),
            ),
            _TemplateCard(
              title: 'Simple Bold',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.simpleBold,
              onTap: () => _openPreview(context, ResumeTemplate.simpleBold),
            ),
            _TemplateCard(
              title: 'Harvard',
              subtitle: 'ATS-friendly',
              isPremium: false,
              template: ResumeTemplate.harvard,
              onTap: () => _openPreview(context, ResumeTemplate.harvard),
            ),
          ],
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, ResumeTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          resumeData: sampleResumeData(),
          template: template,
          isSample: true,
          onUseTemplate: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PreviewScreen(resumeData: resumeData, template: template, documentId: documentId),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isPremium;
  final ResumeTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.isPremium,
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E4E8)),
        ),
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
                child: TemplateThumbnail(kind: DocumentKind.resume, template: template),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
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
                        Text(
                          subtitle,
                          style: const TextStyle(color: AppColors.slate600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isPremium) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.goldLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('PRO',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate900)),
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
