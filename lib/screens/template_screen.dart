import 'package:flutter/material.dart';
import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../models/template_kind.dart';
import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/template_card.dart';
import 'paywall_screen.dart';
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
            _card(context, title: 'Classic', subtitle: 'ATS-friendly', isPremium: false, template: ResumeTemplate.classic),
            _card(context, title: 'Modern', subtitle: 'Color sidebar + photo', isPremium: true, template: ResumeTemplate.modern),
            _card(context, title: 'Minimal', subtitle: 'ATS-friendly', isPremium: false, template: ResumeTemplate.minimal),
            _card(context, title: 'Professional', subtitle: 'ATS-friendly', isPremium: true, template: ResumeTemplate.professional),
            _card(context, title: 'Compact', subtitle: 'ATS-friendly', isPremium: true, template: ResumeTemplate.compact),
            _card(context, title: 'Executive', subtitle: 'ATS-friendly', isPremium: true, template: ResumeTemplate.executive),
            _card(context, title: 'Technical', subtitle: 'ATS-friendly', isPremium: true, template: ResumeTemplate.technical),
            _card(context, title: 'Simple Bold', subtitle: 'ATS-friendly', isPremium: true, template: ResumeTemplate.simpleBold),
            _card(context, title: 'Harvard', subtitle: 'ATS-friendly', isPremium: true, template: ResumeTemplate.harvard),
            _card(context, title: 'Creative', subtitle: 'Bold color banner', isPremium: true, template: ResumeTemplate.creative),
            _card(context, title: 'Elegant', subtitle: 'Editorial style', isPremium: true, template: ResumeTemplate.elegant),
            _card(context, title: 'Timeline', subtitle: 'Visual work history', isPremium: true, template: ResumeTemplate.timeline),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isPremium,
    required ResumeTemplate template,
  }) {
    return TemplateCard(
      kind: DocumentKind.resume,
      template: template,
      title: title,
      subtitle: subtitle,
      badgeText: isPremium ? 'PRO' : null,
      badgeBackgroundColor: AppColors.primaryLight.withValues(alpha: 0.7),
      badgeTextColor: AppColors.slate900,
      onTap: () => _openPreview(context, template, isPremium),
    );
  }

  void _openPreview(BuildContext context, ResumeTemplate template, bool isPremium) {
    if (isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic) {
      _showUpgradeDialog(context);
      return;
    }
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
