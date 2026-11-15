import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/profile_repository.dart';
import '../widgets/app_feedback.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/responsive_scaffold.dart';
import 'ai_guard.dart';
import 'cover_letter_preview_screen.dart';
import 'cover_letter_template_screen.dart';
import 'resume_sections.dart';

const _uuid = Uuid();

/// Cover letter editor — same section-card design as the resume editor,
/// with a strength meter, "fill from my profile", and AI letter writing.
class CoverLetterFormScreen extends StatefulWidget {
  final DocumentEntry? entry;
  final CoverLetterTemplate? initialTemplate;
  const CoverLetterFormScreen({super.key, this.entry, this.initialTemplate});

  @override
  State<CoverLetterFormScreen> createState() => _CoverLetterFormScreenState();
}

class _CoverLetterFormScreenState extends State<CoverLetterFormScreen> {
  late final String _entryId = widget.entry?.id ?? _uuid.v4();
  late final CoverLetterData data =
      widget.entry != null ? CoverLetterData.fromJson(widget.entry!.payload) : CoverLetterData();

  /// Back only saves (and says "saved") when the letter actually changed.
  late String _savedSnapshot = jsonEncode(data.toJson());
  bool get _dirty => jsonEncode(data.toJson()) != _savedSnapshot;
  bool _leaving = false;

  /// Bumped to rebuild the sender fields with fresh controllers after
  /// "Fill from my profile" changes their values in bulk.
  int _formVersion = 0;

  Future<void> _saveEntry() async {
    _savedSnapshot = jsonEncode(data.toJson());
    await DocumentsRepository.save(DocumentEntry(
      id: _entryId,
      kind: DocumentKind.coverLetter,
      title: data.jobTitle.isEmpty ? 'My Cover Letter' : data.jobTitle,
      templateId: widget.initialTemplate?.name ?? widget.entry?.templateId ?? CoverLetterTemplate.classic.name,
      updatedAt: DateTime.now(),
      completionPercent: data.completionPercent,
      payload: data.toJson(),
      isFavorite: widget.entry?.isFavorite ?? false,
      companyLabel: widget.entry?.companyLabel,
      roleLabel: widget.entry?.roleLabel,
    ));
  }

  Future<void> _onBack() async {
    if (_leaving) return;
    _leaving = true;
    if (_dirty) {
      await _saveEntry();
      if (!mounted) return;
      showToast(context, 'Cover letter saved', tone: ToastTone.success);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onExport() async {
    await _saveEntry();
    if (!mounted) return;
    final template = widget.initialTemplate;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => template != null
            ? CoverLetterPreviewScreen(
                data: data, template: template, documentId: _entryId, isPremium: template.isPremium)
            : CoverLetterTemplateScreen(data: data, documentId: _entryId),
      ),
    );
  }

  Future<void> _fillFromProfile() async {
    final profile = await ProfileRepository.load();
    if (!mounted) return;
    if (profile == null) {
      showToast(context, 'Set up your profile in Settings first.');
      return;
    }
    final info = profile.personalInfo;
    setState(() {
      if (info.fullName.isNotEmpty) data.fullName = info.fullName;
      if (info.email.isNotEmpty) data.email = info.email;
      if (info.phone.isNotEmpty) data.phone = info.phone;
      if (info.location.isNotEmpty) data.address = info.location;
      _formVersion++;
    });
    showToast(context, 'Filled in from your profile', tone: ToastTone.success);
  }

  void _refresh() => setState(() {});

  (String?, int?) get _nextStep {
    final d = data;
    if (d.jobTitle.trim().isEmpty) return ('Add the position you are applying for', 15);
    if (d.recipientName.trim().isEmpty && d.companyName.trim().isEmpty) return ('Add the company', 20);
    if (d.body.trim().isEmpty) return ('Write the letter, or let AI draft it', 45);
    if (d.body.trim().length < 200) return ('Expand the letter to a few paragraphs', 25);
    if (d.fullName.trim().isEmpty) return ('Add your name', 10);
    if (d.email.trim().isEmpty && d.phone.trim().isEmpty) return ('Add an email or phone', 10);
    return (null, null);
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final d = data;
    final next = _nextStep;
    final roleFilled = [d.jobTitle, d.companyName, d.date].where((s) => s.trim().isNotEmpty).length;
    final youFilled = [d.fullName, d.email, d.phone, d.address].where((s) => s.trim().isNotEmpty).length;
    final toFilled = [d.recipientName, d.recipientTitle, d.companyAddress].where((s) => s.trim().isNotEmpty).length;

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
          title: Text(widget.entry == null ? 'New cover letter' : 'Edit cover letter'),
        ),
        body: SafeArea(
          top: false,
          child: ResponsiveContentBound(
            maxWidth: 720,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                StrengthCard(
                  label: 'Letter strength',
                  percent: d.completionPercent,
                  nextStep: next.$1,
                  nextGain: next.$2,
                  doneMessage: 'Looking great. Your letter is ready to export.',
                ),
                const SizedBox(height: 16),
                ResumeSectionCard(
                  icon: LucideIcons.target,
                  title: 'The role',
                  subtitle: 'What you are applying for',
                  status: roleFilled == 3 ? 'Complete' : '$roleFilled of 3',
                  done: roleFilled == 3,
                  initiallyExpanded: true,
                  child: _RoleFields(data: d, onChanged: _refresh),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.user,
                  title: 'Your details',
                  subtitle: 'Shown at the top of the letter',
                  status: youFilled == 4 ? 'Complete' : '$youFilled of 4',
                  done: youFilled == 4,
                  child: _SenderFields(
                    key: ValueKey(_formVersion),
                    data: d,
                    onChanged: _refresh,
                    onFillFromProfile: _fillFromProfile,
                  ),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.building2,
                  title: 'Recipient',
                  subtitle: 'Who will read it',
                  status: toFilled == 0 ? 'Optional' : '$toFilled of 3',
                  done: toFilled == 3,
                  child: _RecipientFields(data: d, onChanged: _refresh),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.penLine,
                  title: 'Letter',
                  subtitle: 'Greeting, body and sign-off',
                  status: d.body.trim().isEmpty ? 'Empty' : 'Written',
                  done: d.body.trim().length >= 200,
                  initiallyExpanded: widget.entry != null,
                  child: _LetterFields(data: d, onChanged: _refresh),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(color: p.background, border: Border(top: BorderSide(color: p.fieldBorder))),
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

/// Builds a dense field bound to one string property.
AuthField _bound({
  required String label,
  String? hint,
  required TextEditingController controller,
  required ValueChanged<String> set,
  required VoidCallback onChanged,
  TextInputType? keyboardType,
  TextCapitalization caps = TextCapitalization.words,
  int maxLines = 1,
  int? minLines,
}) {
  return AuthField(
    dense: true,
    label: label,
    hint: hint,
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: caps,
    maxLines: maxLines,
    minLines: minLines,
    textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
    onChanged: (v) {
      set(v);
      onChanged();
    },
  );
}

class _RoleFields extends StatefulWidget {
  final CoverLetterData data;
  final VoidCallback onChanged;
  const _RoleFields({required this.data, required this.onChanged});

  @override
  State<_RoleFields> createState() => _RoleFieldsState();
}

class _RoleFieldsState extends State<_RoleFields> {
  late final _jobTitle = TextEditingController(text: widget.data.jobTitle);
  late final _company = TextEditingController(text: widget.data.companyName);
  late final _date = TextEditingController(text: widget.data.date);

  @override
  void dispose() {
    for (final c in [_jobTitle, _company, _date]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bound(
            label: 'Position',
            hint: 'Product Designer',
            controller: _jobTitle,
            set: (v) => d.jobTitle = v,
            onChanged: widget.onChanged),
        kFieldGap,
        FieldPair(
          _bound(
              label: 'Company',
              hint: 'Careem',
              controller: _company,
              set: (v) => d.companyName = v,
              onChanged: widget.onChanged),
          _bound(
              label: 'Date',
              hint: _todayLabel(),
              controller: _date,
              set: (v) => d.date = v,
              onChanged: widget.onChanged),
        ),
      ],
    );
  }
}

String _todayLabel() {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final n = DateTime.now();
  return '${n.day} ${months[n.month - 1]} ${n.year}';
}

class _SenderFields extends StatefulWidget {
  final CoverLetterData data;
  final VoidCallback onChanged;
  final VoidCallback onFillFromProfile;
  const _SenderFields({super.key, required this.data, required this.onChanged, required this.onFillFromProfile});

  @override
  State<_SenderFields> createState() => _SenderFieldsState();
}

class _SenderFieldsState extends State<_SenderFields> {
  late final _name = TextEditingController(text: widget.data.fullName);
  late final _email = TextEditingController(text: widget.data.email);
  late final _phone = TextEditingController(text: widget.data.phone);
  late final _address = TextEditingController(text: widget.data.address);

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SectionPillButton(
              label: 'Fill from my profile', icon: LucideIcons.userCheck, onPressed: widget.onFillFromProfile),
        ),
        const SizedBox(height: 16),
        FieldPair(
          _bound(
              label: 'Full name',
              hint: 'Sarah Ahmed',
              controller: _name,
              set: (v) => d.fullName = v,
              onChanged: widget.onChanged),
          _bound(
              label: 'Phone',
              hint: '+92 300 1234567',
              controller: _phone,
              keyboardType: TextInputType.phone,
              set: (v) => d.phone = v,
              onChanged: widget.onChanged),
        ),
        kFieldGap,
        _bound(
            label: 'Email',
            hint: 'you@example.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            caps: TextCapitalization.none,
            set: (v) => d.email = v,
            onChanged: widget.onChanged),
        kFieldGap,
        _bound(
            label: 'Address',
            hint: 'Lahore, Pakistan',
            controller: _address,
            set: (v) => d.address = v,
            onChanged: widget.onChanged),
      ],
    );
  }
}

class _RecipientFields extends StatefulWidget {
  final CoverLetterData data;
  final VoidCallback onChanged;
  const _RecipientFields({required this.data, required this.onChanged});

  @override
  State<_RecipientFields> createState() => _RecipientFieldsState();
}

class _RecipientFieldsState extends State<_RecipientFields> {
  late final _name = TextEditingController(text: widget.data.recipientName);
  late final _title = TextEditingController(text: widget.data.recipientTitle);
  late final _address = TextEditingController(text: widget.data.companyAddress);

  @override
  void dispose() {
    for (final c in [_name, _title, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldPair(
          _bound(
              label: 'Name',
              hint: 'Ayesha Khan',
              controller: _name,
              set: (v) => d.recipientName = v,
              onChanged: widget.onChanged),
          _bound(
              label: 'Title',
              hint: 'Hiring Manager',
              controller: _title,
              set: (v) => d.recipientTitle = v,
              onChanged: widget.onChanged),
        ),
        kFieldGap,
        _bound(
            label: 'Company address',
            hint: 'Street, city',
            controller: _address,
            set: (v) => d.companyAddress = v,
            onChanged: widget.onChanged),
      ],
    );
  }
}

class _LetterFields extends StatefulWidget {
  final CoverLetterData data;
  final VoidCallback onChanged;
  const _LetterFields({required this.data, required this.onChanged});

  @override
  State<_LetterFields> createState() => _LetterFieldsState();
}

class _LetterFieldsState extends State<_LetterFields> {
  late final _salutation = TextEditingController(text: widget.data.salutation);
  late final _body = TextEditingController(text: widget.data.body);
  late final _closing = TextEditingController(text: widget.data.closing);
  bool _aiBusy = false;

  @override
  void dispose() {
    for (final c in [_salutation, _body, _closing]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setBody(String value) {
    setState(() {
      _body.text = value;
      widget.data.body = value;
    });
    widget.onChanged();
  }

  Future<void> _generate() async {
    final d = widget.data;
    if (d.jobTitle.trim().isEmpty && d.companyName.trim().isEmpty) {
      showToast(context, 'Add the position and company first so AI knows what to write about.');
      return;
    }
    if (!await ensureAiAvailable(context)) return;
    if (!mounted) return;
    setState(() => _aiBusy = true);
    try {
      final result = await GroqService.generateCoverLetterBody(context: d);
      await AiUsageTracker.recordUsage();
      final previous = _body.text;
      _setBody(result);
      if (mounted) {
        showToast(context, 'Letter written with AI',
            tone: ToastTone.success, actionLabel: 'Undo', onAction: () => _setBody(previous));
      }
    } on AiServiceException catch (e) {
      if (mounted) showToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final d = widget.data;
    final text = _body.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bound(
            label: 'Greeting',
            hint: 'Dear Hiring Manager,',
            controller: _salutation,
            caps: TextCapitalization.sentences,
            set: (v) => d.salutation = v,
            onChanged: widget.onChanged),
        kFieldGap,
        _bound(
          label: 'Letter',
          hint: 'Why you want this role, what you bring, and a short close. 3–4 paragraphs works best.',
          controller: _body,
          caps: TextCapitalization.sentences,
          maxLines: 14,
          minLines: 8,
          set: (v) {
            d.body = v;
            setState(() {});
          },
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text('$words ${words == 1 ? 'word' : 'words'}', style: TextStyle(fontSize: 12, color: p.muted)),
            ),
            AiPillButton(label: text.isEmpty ? 'Write with AI' : 'Rewrite with AI', busy: _aiBusy, onPressed: _generate),
          ],
        ),
        kFieldGap,
        _bound(
            label: 'Sign-off',
            hint: 'Sincerely,',
            controller: _closing,
            caps: TextCapitalization.sentences,
            set: (v) => d.closing = v,
            onChanged: widget.onChanged),
      ],
    );
  }
}
