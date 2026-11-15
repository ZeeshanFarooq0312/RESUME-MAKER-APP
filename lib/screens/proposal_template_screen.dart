import 'package:flutter/material.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../models/template_kind.dart';
import '../widgets/template_card.dart';
import '../widgets/template_picker_scaffold.dart';
import 'proposal_preview_screen.dart';

export '../models/template_kind.dart' show ProposalTemplate;

String _label(ProposalTemplate t) => t.name[0].toUpperCase() + t.name.substring(1);

/// Pick a template for the proposal being edited. Tapping a card previews
/// *this* proposal in that template straight away.
class ProposalTemplateScreen extends StatelessWidget {
  final ProposalData data;
  final String? documentId;
  const ProposalTemplateScreen({super.key, required this.data, this.documentId});

  @override
  Widget build(BuildContext context) {
    return TemplatePickerScaffold(
      title: 'Choose a template',
      subtitle: 'Tap a design to see your proposal in it.',
      cards: [
        for (final t in ProposalTemplate.values)
          TemplateCard(
            kind: DocumentKind.proposal,
            template: t,
            title: _label(t),
            subtitle: t.isPremium ? 'Pro' : 'Free',
            badgeText: t.isPremium ? 'PRO' : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProposalPreviewScreen(
                  data: data,
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
