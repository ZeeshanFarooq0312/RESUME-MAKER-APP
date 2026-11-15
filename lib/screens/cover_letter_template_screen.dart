import 'package:flutter/material.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../pdf/resume_design_presets.dart';
import '../services/matching_designs.dart';
import '../widgets/template_card.dart';
import '../widgets/template_picker_scaffold.dart';
import 'cover_letter_preview_screen.dart';

export '../models/template_kind.dart' show CoverLetterTemplate;

String _label(CoverLetterTemplate t) => t.name[0].toUpperCase() + t.name.substring(1);

String _subtitle(CoverLetterTemplate t, List<String> inUse) {
  if (inUse.contains(t.name)) return 'Matches your resume';
  return designFor(t)?.tagline ?? (t.isPremium ? 'Pro' : 'Free');
}

/// Pick a template for the cover letter being edited. Tapping a card
/// previews *this* letter in that template straight away.
class CoverLetterTemplateScreen extends StatelessWidget {
  final CoverLetterData data;
  final String? documentId;
  const CoverLetterTemplateScreen({super.key, required this.data, this.documentId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: resumeDesignsInUse(),
      builder: (context, snap) => _picker(context, snap.data ?? const []),
    );
  }

  Widget _picker(BuildContext context, List<String> inUse) {
    return TemplatePickerScaffold(
      title: 'Choose a template',
      subtitle: 'Tap a design to see your cover letter in it.',
      cards: [
        for (final t in matchingFirst(CoverLetterTemplate.values, inUse))
          TemplateCard(
            kind: DocumentKind.coverLetter,
            template: t,
            title: _label(t),
            subtitle: _subtitle(t, inUse),
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
