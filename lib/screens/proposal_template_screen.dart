import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../models/template_kind.dart';
import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/template_card.dart';
import 'paywall_screen.dart';
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
            _card(context, title: 'Classic', isPremium: false, template: ProposalTemplate.classic),
            _card(context, title: 'Modern', isPremium: true, template: ProposalTemplate.modern),
            _card(context, title: 'Minimal', isPremium: true, template: ProposalTemplate.minimal),
            _card(context, title: 'Corporate', isPremium: true, template: ProposalTemplate.corporate),
            _card(context, title: 'Executive', isPremium: true, template: ProposalTemplate.executive),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required bool isPremium,
    required ProposalTemplate template,
  }) {
    return TemplateCard(
      kind: DocumentKind.proposal,
      template: template,
      title: title,
      badgeText: isPremium ? 'PRO' : null,
      badgeBackgroundColor: AppColors.primaryLight.withValues(alpha: 0.7),
      badgeTextColor: AppColors.slate900,
      onTap: () => _openPreview(context, template, isPremium),
    );
  }

  void _openPreview(BuildContext context, ProposalTemplate template, bool isPremium) {
    if (isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic) {
      _showUpgradeDialog(context);
      return;
    }
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
              builder: (_) =>
                  ProposalPreviewScreen(data: data, template: template, documentId: documentId),
            ),
          ),
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Premium template'),
        content: const Text('This template is available on Pro. Upgrade to unlock it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }
}
