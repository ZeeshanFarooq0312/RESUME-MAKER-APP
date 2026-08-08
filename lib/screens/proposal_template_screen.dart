import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../models/template_kind.dart';
import '../theme/app_theme.dart';
import '../widgets/template_card.dart';
import 'proposal_preview_screen.dart';

export '../models/template_kind.dart' show ProposalTemplate;

class ProposalTemplateScreen extends StatelessWidget {
  final ProposalData data;
  final String? documentId;
  const ProposalTemplateScreen({super.key, required this.data, this.documentId});

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
            _card(context, title: 'Classic', template: ProposalTemplate.classic),
            _card(context, title: 'Modern', template: ProposalTemplate.modern),
            _card(context, title: 'Minimal', template: ProposalTemplate.minimal),
            _card(context, title: 'Corporate', template: ProposalTemplate.corporate),
            _card(context, title: 'Executive', template: ProposalTemplate.executive),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required ProposalTemplate template,
  }) {
    return TemplateCard(
      kind: DocumentKind.proposal,
      template: template,
      title: title,
      badgeText: template.isPremium ? 'PRO' : null,
      badgeBackgroundColor: AppColors.primaryLight.withValues(alpha: 0.7),
      badgeTextColor: AppColors.slate900,
      onTap: () => _openPreview(context, template),
    );
  }

  void _openPreview(BuildContext context, ProposalTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProposalPreviewScreen(
          data: sampleProposalData(),
          template: template,
          isSample: true,
          onUseTemplate: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ProposalPreviewScreen(
                data: data,
                template: template,
                documentId: documentId,
                isPremium: template.isPremium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
