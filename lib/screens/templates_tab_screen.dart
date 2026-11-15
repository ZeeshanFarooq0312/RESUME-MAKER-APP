import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../services/resume_profile_prefill.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/pill_search_field.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/template_card.dart';
import 'cover_letter_form_screen.dart';
import 'cover_letter_preview_screen.dart';
import 'form_screen.dart';
import 'preview_screen.dart';
import 'template_screen.dart' show resumeTemplateTaglines;
import '../pdf/resume_design_presets.dart';
import 'proposal_form_screen.dart';
import 'proposal_preview_screen.dart';

class _TemplateOption {
  final DocumentKind kind;
  final String title;
  final Enum template; // ResumeTemplate | CoverLetterTemplate | ProposalTemplate
  final bool premium;
  const _TemplateOption(this.kind, this.title, this.template, this.premium);
}

/// "simpleBold" -> "Simple Bold".
String _labelFor(Enum e) {
  final spaced = e.name.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Built from the enums, so a newly added template shows up here
/// automatically instead of needing a hand-maintained list.
final _allOptions = <_TemplateOption>[
  for (final t in ResumeTemplate.values) _TemplateOption(DocumentKind.resume, _labelFor(t), t, t.isPremium),
  for (final t in CoverLetterTemplate.values)
    _TemplateOption(DocumentKind.coverLetter, _labelFor(t), t, t.isPremium),
  for (final t in ProposalTemplate.values) _TemplateOption(DocumentKind.proposal, _labelFor(t), t, t.isPremium),
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
          onUseTemplate: () => _useResumeTemplate(template),
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

  Future<void> _useResumeTemplate(ResumeTemplate template) async {
    final starting = await promptResumeStartingData(context);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => FormScreen(initialTemplate: template, initialData: starting)),
    );
  }

  bool _matchesQuery(_TemplateOption o) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return o.title.toLowerCase().contains(q) || o.kind.label.toLowerCase().contains(q);
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = null;
    });
  }

  String? _subtitleFor(_TemplateOption o) {
    if (o.template is ResumeTemplate) return resumeTemplateTaglines[o.template];
    final design = designFor(o.template);
    if (design != null) return design.tagline;
    return o.premium ? 'Pro' : 'Free';
  }

  Widget _card(_TemplateOption o) => TemplateCard(
        key: ValueKey('${o.kind.name}_${o.template.name}'),
        kind: o.kind,
        template: o.template,
        title: o.title,
        subtitle: _subtitleFor(o),
        badgeText: o.premium ? 'PRO' : null,
        onTap: () => _openTemplate(o),
      );

  /// A grid of cards as a sliver, sized for the available width.
  Widget _grid(List<_TemplateOption> options) => SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid(
          gridDelegate: templateGridDelegate(constraints.crossAxisExtent),
          delegate: SliverChildBuilderDelegate((_, i) => _card(options[i]), childCount: options.length),
        ),
      );

  static const _sectionTitles = {
    DocumentKind.resume: 'Resumes',
    DocumentKind.coverLetter: 'Cover letters',
    DocumentKind.proposal: 'Proposals',
  };

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final searched = _allOptions.where(_matchesQuery).toList();
    final options = searched.where((o) => _filter == null || o.kind == _filter).toList();
    // With no search or filter, browse by section; otherwise show one
    // flat grid of matches.
    final browsing = _query.isEmpty && _filter == null;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Templates',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 28,
                  height: 1.15,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w600,
                  color: p.title,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_allOptions.length} professional designs. Tap one to preview it.',
                style: TextStyle(fontSize: 14.5, color: p.body),
              ),
              const SizedBox(height: 16),
              PillSearchField(
                controller: _searchController,
                hintText: 'Search templates',
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 12),
              FilterChipRow<DocumentKind?>(
                options: const [null, DocumentKind.resume, DocumentKind.coverLetter, DocumentKind.proposal],
                selected: _filter,
                labelFor: (k) => k == null ? 'All' : k.label,
                countFor: (k) => searched.where((o) => k == null || o.kind == k).length,
                onSelected: (k) => setState(() => _filter = k),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ];

    if (options.isEmpty) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: LucideIcons.searchX,
          title: 'No templates found',
          message: 'Try a different name, or clear the search to see all templates.',
          actionLabel: 'Clear search',
          onAction: _resetFilters,
        ),
      ));
    } else if (browsing) {
      for (final kind in DocumentKind.values) {
        final inKind = options.where((o) => o.kind == kind).toList();
        slivers.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: _sectionTitles[kind]!),
                TextSpan(
                  text: '  ${inKind.length}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.muted),
                ),
              ]),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.title),
            ),
          ),
        ));
        slivers.add(_grid(inKind));
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));
      }
    } else {
      slivers.add(_grid(options));
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
    }

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: ResponsiveContentBound(
          maxWidth: 1040,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: slivers,
            ),
          ),
        ),
      ),
    );
  }
}
