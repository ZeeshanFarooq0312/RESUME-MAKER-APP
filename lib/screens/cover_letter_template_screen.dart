import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/template_card.dart';
import 'cover_letter_preview_screen.dart';
import 'paywall_screen.dart';

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
            _card(context, title: 'Classic', isPremium: false, template: CoverLetterTemplate.classic),
            _card(context, title: 'Modern', isPremium: true, template: CoverLetterTemplate.modern),
            _card(context, title: 'Minimal', isPremium: true, template: CoverLetterTemplate.minimal),
            _card(context, title: 'Bold', isPremium: true, template: CoverLetterTemplate.bold),
            _card(context, title: 'Formal', isPremium: true, template: CoverLetterTemplate.formal),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required bool isPremium,
    required CoverLetterTemplate template,
  }) {
    return TemplateCard(
      kind: DocumentKind.coverLetter,
      template: template,
      title: title,
      badgeText: isPremium ? 'PRO' : null,
      badgeBackgroundColor: AppColors.primaryLight.withValues(alpha: 0.7),
      badgeTextColor: AppColors.slate900,
      onTap: () => _openPreview(context, template, isPremium),
    );
  }

  void _openPreview(BuildContext context, CoverLetterTemplate template, bool isPremium) {
    if (isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic) {
      _showUpgradeDialog(context);
      return;
    }
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
