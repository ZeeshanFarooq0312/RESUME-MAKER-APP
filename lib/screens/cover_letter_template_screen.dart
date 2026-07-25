import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../theme/app_theme.dart';
import '../widgets/template_thumbnail.dart';
import 'cover_letter_preview_screen.dart';

export '../models/template_kind.dart' show CoverLetterTemplate;

class CoverLetterTemplateScreen extends StatelessWidget {
  final CoverLetterData data;
  final String? documentId;
  const CoverLetterTemplateScreen({super.key, required this.data, this.documentId});

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
              template: CoverLetterTemplate.classic,
              onTap: () => _openPreview(context, CoverLetterTemplate.classic),
            ),
            _TemplateCard(
              title: 'Modern',
              template: CoverLetterTemplate.modern,
              onTap: () => _openPreview(context, CoverLetterTemplate.modern),
            ),
            _TemplateCard(
              title: 'Minimal',
              template: CoverLetterTemplate.minimal,
              onTap: () => _openPreview(context, CoverLetterTemplate.minimal),
            ),
          ],
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, CoverLetterTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoverLetterPreviewScreen(
          data: sampleCoverLetterData(),
          template: template,
          isSample: true,
          onUseTemplate: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CoverLetterPreviewScreen(
                  data: data, template: template, documentId: documentId),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String title;
  final CoverLetterTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.title, required this.template, required this.onTap});

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
                child: TemplateThumbnail(kind: DocumentKind.coverLetter, template: template),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
