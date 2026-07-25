import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/resume_data.dart';
import '../theme/app_theme.dart';
import 'preview_screen.dart';

enum ResumeTemplate {
  classic,
  modern,
  minimal,
  professional,
  compact,
  executive,
  technical,
  simpleBold,
  harvard,
}

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
              accentColor: AppColors.slate600,
              onTap: () => _openPreview(context, ResumeTemplate.classic),
            ),
            _TemplateCard(
              title: 'Modern',
              subtitle: 'Color sidebar + photo',
              isPremium: true,
              accentColor: AppColors.gold,
              onTap: () => _openPreview(context, ResumeTemplate.modern),
            ),
            _TemplateCard(
              title: 'Minimal',
              subtitle: 'ATS-friendly',
              isPremium: false,
              accentColor: AppColors.slate400,
              onTap: () => _openPreview(context, ResumeTemplate.minimal),
            ),
            _TemplateCard(
              title: 'Professional',
              subtitle: 'ATS-friendly',
              isPremium: false,
              accentColor: const Color(0xFF2C5C8A),
              onTap: () => _openPreview(context, ResumeTemplate.professional),
            ),
            _TemplateCard(
              title: 'Compact',
              subtitle: 'ATS-friendly',
              isPremium: false,
              accentColor: AppColors.slate800,
              onTap: () => _openPreview(context, ResumeTemplate.compact),
            ),
            _TemplateCard(
              title: 'Executive',
              subtitle: 'ATS-friendly',
              isPremium: false,
              accentColor: const Color(0xFF3A3A3A),
              onTap: () => _openPreview(context, ResumeTemplate.executive),
            ),
            _TemplateCard(
              title: 'Technical',
              subtitle: 'ATS-friendly',
              isPremium: false,
              accentColor: const Color(0xFF1F6F54),
              onTap: () => _openPreview(context, ResumeTemplate.technical),
            ),
            _TemplateCard(
              title: 'Simple Bold',
              subtitle: 'ATS-friendly',
              isPremium: false,
              accentColor: const Color(0xFFB0413E),
              onTap: () => _openPreview(context, ResumeTemplate.simpleBold),
            ),
            _TemplateCard(
              title: 'Harvard',
              subtitle: 'ATS-friendly',
              isPremium: false,
              accentColor: AppColors.slate900,
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
  final Color accentColor;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.isPremium,
    required this.accentColor,
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
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 6, width: 60, color: AppColors.slate400),
                            const SizedBox(height: 8),
                            Container(height: 3, width: 40, color: const Color(0xFFD8DCE0)),
                            const SizedBox(height: 12),
                            Container(height: 3, width: double.infinity, color: const Color(0xFFE1E4E8)),
                            const SizedBox(height: 4),
                            Container(height: 3, width: double.infinity, color: const Color(0xFFE1E4E8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
