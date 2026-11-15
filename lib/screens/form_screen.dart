import 'dart:convert';

import 'package:flutter/material.dart';
import '../widgets/app_feedback.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../models/template_kind.dart';
import '../models/template_style_spec.dart';
import '../services/documents_repository.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/responsive_scaffold.dart';
import 'dynamic_preview_screen.dart';
import 'preview_screen.dart';
import 'resume_sections.dart';
import 'template_screen.dart';

const _uuid = Uuid();

/// Resume editor. Shares every section with the Profile form (see
/// resume_sections.dart) and adds the photo picker, AI writing tools and a
/// live "resume strength" card that points at the next most valuable thing
/// to add.
class FormScreen extends StatefulWidget {
  final DocumentEntry? entry;
  final ResumeTemplate? initialTemplate;

  /// Pre-fills a brand-new (non-[entry]) form with already-known data, e.g.
  /// the user's saved Profile when they chose "Use My Profile" instead of
  /// starting blank. Ignored when [entry] is set, since that already has
  /// its own saved data.
  final ResumeData? initialData;
  const FormScreen({super.key, this.entry, this.initialTemplate, this.initialData});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late final String _entryId = widget.entry?.id ?? _uuid.v4();
  late final ResumeData data = widget.entry != null
      ? ResumeData.fromJson(widget.entry!.payload)
      : (widget.initialData ?? ResumeData());
  bool _leaving = false;

  /// What's on disk (or the starting state, for a new resume). Back only
  /// saves — and only says "saved" — when the data differs from this, so
  /// just opening and closing a resume doesn't resave it, bump it to the top
  /// of Recent, or create an empty document.
  late String _savedSnapshot = jsonEncode(data.toJson());
  bool get _dirty => jsonEncode(data.toJson()) != _savedSnapshot;

  Future<void> _saveEntry() async {
    _savedSnapshot = jsonEncode(data.toJson());
    await DocumentsRepository.save(DocumentEntry(
      id: _entryId,
      kind: DocumentKind.resume,
      title: data.personalInfo.fullName.isEmpty ? 'My Resume' : data.personalInfo.fullName,
      templateId: widget.initialTemplate?.name ?? widget.entry?.templateId ?? ResumeTemplate.classic.name,
      updatedAt: DateTime.now(),
      completionPercent: data.completionPercent,
      payload: data.toJson(),
      // Keep fields the editor doesn't touch, so saving never drops them.
      isFavorite: widget.entry?.isFavorite ?? false,
      companyLabel: widget.entry?.companyLabel,
      roleLabel: widget.entry?.roleLabel,
      customStyleSpec: widget.entry?.customStyleSpec,
    ));
  }

  Future<void> _onBack() async {
    if (_leaving) return;
    _leaving = true;
    if (_dirty) {
      await _saveEntry();
      if (!mounted) return;
      showToast(context, 'Resume saved', tone: ToastTone.success);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onExport() async {
    await _saveEntry();
    if (!mounted) return;
    final template = widget.initialTemplate;
    final customSpec = widget.entry?.customStyleSpec;
    if (template != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            resumeData: data,
            template: template,
            documentId: _entryId,
            isPremium: template.isPremium,
          ),
        ),
      );
    } else if (widget.entry?.templateId == 'custom' && customSpec != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DynamicPreviewScreen(
            resumeData: data,
            styleSpec: TemplateStyleSpec.fromJson(customSpec),
            documentId: _entryId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TemplateScreen(resumeData: data, documentId: _entryId)),
      );
    }
  }

  void _refresh() => setState(() {});

  /// Weights mirror [ResumeData.completionPercent].
  Widget _strengthCard() {
    final info = data.personalInfo;
    final (String?, int?) next = info.fullName.trim().isEmpty
        ? ('Add your name', 15)
        : data.experience.isEmpty
            ? ('Add your work experience', 25)
            : data.education.isEmpty
                ? ('Add your education', 20)
                : info.summary.trim().isEmpty
                    ? ('Write a short summary', 15)
                    : data.skills.length < 3
                        ? ('Add at least 3 skills', 15)
                        : (info.email.trim().isEmpty && info.phone.trim().isEmpty)
                            ? ('Add an email or phone', 10)
                            : (null, null);
    return StrengthCard(
      label: 'Resume strength',
      percent: data.completionPercent,
      nextStep: next.$1,
      nextGain: next.$2,
      doneMessage: 'Looking great. Your resume is ready to export.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final info = data.personalInfo;
    final basics = filledBasics(info);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.background,
          leading: IconButton(tooltip: 'Back', icon: const Icon(LucideIcons.arrowLeft), onPressed: _onBack),
          title: Text(widget.entry == null ? 'New resume' : 'Edit resume'),
        ),
        body: SafeArea(
          top: false,
          child: ResponsiveContentBound(
            maxWidth: 720,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _strengthCard(),
                const SizedBox(height: 16),
                ResumeSectionCard(
                  icon: LucideIcons.idCard,
                  title: 'Personal details',
                  subtitle: 'Photo, name, title, contact',
                  status: basics == 5 ? 'Complete' : '$basics of 5',
                  done: basics == 5,
                  initiallyExpanded: true,
                  child: PersonalDetailsFields(data: data, onChanged: _refresh, showPhoto: true),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.alignLeft,
                  title: 'Summary',
                  subtitle: 'Your short intro',
                  status: info.summary.trim().isEmpty ? 'Empty' : 'Added',
                  done: info.summary.trim().isNotEmpty,
                  child: SummaryEditor(data: data, onChanged: _refresh, enableAi: true),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.briefcase,
                  title: 'Work experience',
                  subtitle: 'Most recent first',
                  status: countLabel(data.experience.length, 'role'),
                  done: data.experience.isNotEmpty,
                  child: ExperienceEditor(data: data, onChanged: _refresh, enableAi: true),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.graduationCap,
                  title: 'Education',
                  subtitle: 'Degrees and courses',
                  status: countLabel(data.education.length, 'entry', plural: 'entries'),
                  done: data.education.isNotEmpty,
                  child: EducationEditor(data: data, onChanged: _refresh),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.zap,
                  title: 'Skills',
                  subtitle: 'Tools and strengths',
                  status: countLabel(data.skills.length, 'skill'),
                  done: data.skills.length >= 3,
                  child: SkillsEditor(data: data, onChanged: _refresh),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: p.background,
              border: Border(top: BorderSide(color: p.fieldBorder)),
            ),
            child: AuthPrimaryButton(
              label: 'Preview and export',
              trailingIcon: LucideIcons.arrowRight,
              onPressed: _onExport,
            ),
          ),
        ),
      ),
    );
  }
}
