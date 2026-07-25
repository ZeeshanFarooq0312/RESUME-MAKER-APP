import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/pill_search_field.dart';
import '../widgets/template_thumbnail.dart';
import 'cover_letter_form_screen.dart';
import 'cover_letter_preview_screen.dart';
import 'cover_letter_template_screen.dart';
import 'form_screen.dart';
import 'preview_screen.dart';
import 'proposal_form_screen.dart';
import 'proposal_preview_screen.dart';
import 'proposal_template_screen.dart';
import 'template_screen.dart';

class _TemplateOption {
  final DocumentKind kind;
  final String title;
  final dynamic template; // ResumeTemplate | CoverLetterTemplate | ProposalTemplate
  const _TemplateOption(this.kind, this.title, this.template);
}

const _allOptions = <_TemplateOption>[
  _TemplateOption(DocumentKind.resume, 'Classic', ResumeTemplate.classic),
  _TemplateOption(DocumentKind.resume, 'Modern', ResumeTemplate.modern),
  _TemplateOption(DocumentKind.resume, 'Minimal', ResumeTemplate.minimal),
  _TemplateOption(DocumentKind.resume, 'Professional', ResumeTemplate.professional),
  _TemplateOption(DocumentKind.resume, 'Compact', ResumeTemplate.compact),
  _TemplateOption(DocumentKind.resume, 'Executive', ResumeTemplate.executive),
  _TemplateOption(DocumentKind.resume, 'Technical', ResumeTemplate.technical),
  _TemplateOption(DocumentKind.resume, 'Simple Bold', ResumeTemplate.simpleBold),
  _TemplateOption(DocumentKind.resume, 'Harvard', ResumeTemplate.harvard),
  _TemplateOption(DocumentKind.coverLetter, 'Classic', CoverLetterTemplate.classic),
  _TemplateOption(DocumentKind.coverLetter, 'Modern', CoverLetterTemplate.modern),
  _TemplateOption(DocumentKind.coverLetter, 'Minimal', CoverLetterTemplate.minimal),
  _TemplateOption(DocumentKind.proposal, 'Classic', ProposalTemplate.classic),
  _TemplateOption(DocumentKind.proposal, 'Modern', ProposalTemplate.modern),
  _TemplateOption(DocumentKind.proposal, 'Minimal', ProposalTemplate.minimal),
];

class TemplatesTabScreen extends StatefulWidget {
  const TemplatesTabScreen({super.key});

  @override
  State<TemplatesTabScreen> createState() => _TemplatesTabScreenState();
}

class _TemplatesTabScreenState extends State<TemplatesTabScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  DocumentKind? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTemplate(_TemplateOption option) {
    Widget sample;
    switch (option.kind) {
      case DocumentKind.resume:
        final template = option.template as ResumeTemplate;
        sample = PreviewScreen(
          resumeData: sampleResumeData(),
          template: template,
          isSample: true,
          onUseTemplate: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => FormScreen(initialTemplate: template)),
          ),
        );
        break;
      case DocumentKind.coverLetter:
        final template = option.template as CoverLetterTemplate;
        sample = CoverLetterPreviewScreen(
          data: sampleCoverLetterData(),
          template: template,
          isSample: true,
          onUseTemplate: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => CoverLetterFormScreen(initialTemplate: template)),
          ),
        );
        break;
      case DocumentKind.proposal:
        final template = option.template as ProposalTemplate;
        sample = ProposalPreviewScreen(
          data: sampleProposalData(),
          template: template,
          isSample: true,
          onUseTemplate: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ProposalFormScreen(initialTemplate: template)),
          ),
        );
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => sample));
  }

  @override
  Widget build(BuildContext context) {
    final options = _allOptions.where((o) {
      final matchesFilter = _filter == null || o.kind == _filter;
      final matchesQuery = _query.isEmpty || o.title.toLowerCase().contains(_query.toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              PillSearchField(
                controller: _searchController,
                hintText: 'Search your template',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              FilterChipRow<DocumentKind?>(
                options: const [null, DocumentKind.resume, DocumentKind.coverLetter, DocumentKind.proposal],
                selected: _filter,
                labelFor: (k) => k == null ? 'All' : k.label,
                onSelected: (k) => setState(() => _filter = k),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, i) {
                    final option = options[i];
                    return _TemplateCard(option: option, onTap: () => _openTemplate(option));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final _TemplateOption option;
  final VoidCallback onTap;
  const _TemplateCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E5F3)),
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
                child: TemplateThumbnail(kind: option.kind, template: option.template),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      option.kind.label,
                      style: const TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
