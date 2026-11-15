import 'package:flutter/material.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../widgets/template_card.dart';
import '../widgets/template_picker_scaffold.dart';
import 'cover_letter_preview_screen.dart';

export '../models/template_kind.dart' show CoverLetterTemplate;

String _label(CoverLetterTemplate t) => t.name[0].toUpperCase() + t.name.substring(1);

/// Pick a template for the cover letter being edited. Tapping a card
/// previews *this* letter in that template straight away.
class CoverLetterTemplateScreen extends StatelessWidget {
  final CoverLetterData data;
  final String? documentId;
  const CoverLetterTemplateScreen({super.key, required this.data, this.documentId});

  @override
  Widget build(BuildContext context) {
    return TemplatePickerScaffold(
      title: 'Choose a template',
      subtitle: 'Tap a design to see your cover letter in it.',
      cards: [
        for (final t in CoverLetterTemplate.values)
          TemplateCard(
            kind: DocumentKind.coverLetter,
            template: t,
            title: _label(t),
            subtitle: t.isPremium ? 'Pro' : 'Free',
            badgeText: t.isPremium ? 'PRO' : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CoverLetterPreviewScreen(
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
