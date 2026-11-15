import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../models/template_kind.dart';
import '../models/template_style_spec.dart';
import '../pdf/resume_design_presets.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/profile_repository.dart';
import '../widgets/app_feedback.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/responsive_scaffold.dart';
import 'ai_guard.dart';
import 'proposal_preview_screen.dart';
import 'proposal_template_screen.dart';
import 'resume_sections.dart';

const _uuid = Uuid();

/// Proposal editor — same section-card design as the resume editor, with a
/// strength meter, "fill from my profile", and AI overview/scope writing.
class ProposalFormScreen extends StatefulWidget {
  final DocumentEntry? entry;
  final ProposalTemplate? initialTemplate;
  const ProposalFormScreen({super.key, this.entry, this.initialTemplate});

  @override
  State<ProposalFormScreen> createState() => _ProposalFormScreenState();
}

class _ProposalFormScreenState extends State<ProposalFormScreen> {
  late final String _entryId = widget.entry?.id ?? _uuid.v4();
  late final ProposalData data = widget.entry != null ? ProposalData.fromJson(widget.entry!.payload) : ProposalData();

  /// Back only saves (and says "saved") when the proposal actually changed.
  late String _savedSnapshot = jsonEncode(data.toJson());
  bool get _dirty => jsonEncode(data.toJson()) != _savedSnapshot;
  bool _leaving = false;

  /// Bumped to rebuild the sender fields after "Fill from my profile".
  int _senderVersion = 0;

  /// Only one AI request at a time across the whole editor.
  String? _aiBusy;

  Future<void> _saveEntry() async {
    _savedSnapshot = jsonEncode(data.toJson());
    final stored = await DocumentsRepository.find(_entryId);
    await DocumentsRepository.save(DocumentEntry(
      id: _entryId,
      kind: DocumentKind.proposal,
      title: data.title.isEmpty ? 'My Proposal' : data.title,
      templateId: stored?.templateId ?? widget.initialTemplate?.name ?? widget.entry?.templateId ?? ProposalTemplate.classic.name,
      updatedAt: DateTime.now(),
      completionPercent: data.completionPercent,
      payload: data.toJson(),
      isFavorite: stored?.isFavorite ?? widget.entry?.isFavorite ?? false,
      companyLabel: stored?.companyLabel ?? widget.entry?.companyLabel,
      roleLabel: stored?.roleLabel ?? widget.entry?.roleLabel,
    ));
  }

  Future<void> _onBack() async {
    if (_leaving) return;
    _leaving = true;
    if (_dirty) {
      await _saveEntry();
      if (!mounted) return;
      showToast(context, 'Proposal saved', tone: ToastTone.success);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onExport() async {
    await _saveEntry();
    if (!mounted) return;
    final stored = await DocumentsRepository.find(_entryId);
    if (!mounted) return;
    final customSpec = stored?.customStyleSpec ?? widget.entry?.customStyleSpec;
    final storedTemplate = ProposalTemplate.values.where((t) => t.name == stored?.templateId).firstOrNull;
    if (storedTemplate != null && customSpec != null && designFor(storedTemplate) != null) {
      // A customized design reopens straight into that design.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProposalPreviewScreen(
            data: data,
            template: storedTemplate,
            documentId: _entryId,
            isPremium: storedTemplate.isPremium,
            styleOverride: TemplateStyleSpec.fromJson(customSpec),
          ),
        ),
      );
      return;
    }
    final template = widget.initialTemplate;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => template != null
            ? ProposalPreviewScreen(data: data, template: template, documentId: _entryId, isPremium: template.isPremium)
            : ProposalTemplateScreen(data: data, documentId: _entryId),
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
      if (info.fullName.isNotEmpty) data.senderName = info.fullName;
      if (info.email.isNotEmpty) data.senderEmail = info.email;
      if (info.phone.isNotEmpty) data.senderPhone = info.phone;
      _senderVersion++;
    });
    showToast(context, 'Filled in from your profile', tone: ToastTone.success);
  }

  /// Runs one AI writer; [apply] receives the result and returns the
  /// previous value so Undo can restore it.
  Future<void> _runAi(String key, Future<String> Function() request, String Function(String) apply,
      void Function(String) undo, String doneMessage) async {
    if (data.title.trim().isEmpty) {
      showToast(context, 'Add the proposal title first so AI knows what to write about.');
      return;
    }
    if (_aiBusy != null) return;
    if (!await ensureAiAvailable(context)) return;
    if (!mounted) return;
    setState(() => _aiBusy = key);
    try {
      final result = await request();
      await AiUsageTracker.recordUsage();
      final previous = apply(result);
      setState(() {});
      if (mounted) {
        showToast(context, doneMessage, tone: ToastTone.success, actionLabel: 'Undo', onAction: () {
          undo(previous);
          setState(() {});
        });
      }
    } on AiServiceException catch (e) {
      if (mounted) showToast(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _aiBusy = null);
    }
  }

  void _refresh() => setState(() {});

  (String?, int?) get _nextStep {
    final d = data;
    if (d.title.trim().isEmpty) return ('Give the proposal a title', 10);
    if (d.clientName.trim().isEmpty && d.clientCompany.trim().isEmpty) return ('Add the client', 15);
    if (d.overview.trim().isEmpty) return ('Write an overview, or let AI draft it', 20);
    if (d.scopeOfWork.trim().isEmpty) return ('Describe the scope of work', 20);
    if (d.senderName.trim().isEmpty && d.senderCompany.trim().isEmpty) return ('Add your name or company', 10);
    if (d.timeline.trim().isEmpty) return ('Add a timeline', 10);
    if (d.pricing.trim().isEmpty) return ('Add pricing', 10);
    if (d.termsAndConditions.trim().isEmpty) return ('Add terms and conditions', 5);
    return (null, null);
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final d = data;
    final next = _nextStep;
    final fromFilled = [d.senderName, d.senderCompany, d.senderEmail, d.senderPhone].where((s) => s.trim().isNotEmpty).length;
    final clientFilled = [d.clientName, d.clientCompany].where((s) => s.trim().isNotEmpty).length;
    final tpFilled = [d.timeline, d.pricing].where((s) => s.trim().isNotEmpty).length;

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
          title: Text(widget.entry == null ? 'New proposal' : 'Edit proposal'),
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
                  label: 'Proposal strength',
                  percent: d.completionPercent,
                  nextStep: next.$1,
                  nextGain: next.$2,
                  doneMessage: 'Looking great. Your proposal is ready to export.',
                ),
                const SizedBox(height: 16),
                ResumeSectionCard(
                  icon: LucideIcons.fileText,
                  title: 'Proposal',
                  subtitle: 'Title and date',
                  status: d.title.trim().isEmpty ? 'Needs title' : 'Added',
                  done: d.title.trim().isNotEmpty,
                  initiallyExpanded: true,
                  child: _TwoTextFields(
                    first: _FieldSpec('Title', 'Website redesign for Northwind', d.title, (v) => d.title = v),
                    second: _FieldSpec('Date', _todayLabel(), d.date, (v) => d.date = v),
                    stacked: true,
                    onChanged: _refresh,
                  ),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.user,
                  title: 'From you',
                  subtitle: 'Your name and contact',
                  status: fromFilled == 4 ? 'Complete' : '$fromFilled of 4',
                  done: fromFilled == 4,
                  child: _SenderFields(
                    key: ValueKey(_senderVersion),
                    data: d,
                    onChanged: _refresh,
                    onFillFromProfile: _fillFromProfile,
                  ),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.building2,
                  title: 'Client',
                  subtitle: 'Who the proposal is for',
                  status: clientFilled == 2 ? 'Complete' : '$clientFilled of 2',
                  done: clientFilled == 2,
                  child: _TwoTextFields(
                    first: _FieldSpec('Client name', 'Ayesha Khan', d.clientName, (v) => d.clientName = v),
                    second: _FieldSpec('Company', 'Northwind', d.clientCompany, (v) => d.clientCompany = v),
                    onChanged: _refresh,
                  ),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.alignLeft,
                  title: 'Overview',
                  subtitle: 'The problem and your approach',
                  status: d.overview.trim().isEmpty ? 'Empty' : 'Written',
                  done: d.overview.trim().isNotEmpty,
                  child: _LongTextField(
                    label: 'Overview',
                    hint: 'What the client needs and how you will deliver it.',
                    initial: d.overview,
                    set: (v) => d.overview = v,
                    onChanged: _refresh,
                    aiLabel: 'Write with AI',
                    aiBusy: _aiBusy == 'overview',
                    onAi: (controller) => _runAi(
                      'overview',
                      () => GroqService.generateProposalOverview(context: d),
                      (r) {
                        final prev = d.overview;
                        d.overview = r;
                        controller.text = r;
                        return prev;
                      },
                      (prev) {
                        d.overview = prev;
                        controller.text = prev;
                      },
                      'Overview written with AI',
                    ),
                  ),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.listChecks,
                  title: 'Scope of work',
                  subtitle: 'Deliverables, one per line',
                  status: d.scopeOfWork.trim().isEmpty ? 'Empty' : 'Written',
                  done: d.scopeOfWork.trim().isNotEmpty,
                  child: _LongTextField(
                    label: 'Scope of work',
                    hint: 'One deliverable per line, e.g.\nDiscovery workshop\nHigh-fidelity designs',
                    initial: d.scopeOfWork,
                    set: (v) => d.scopeOfWork = v,
                    onChanged: _refresh,
                    aiLabel: 'Write with AI',
                    aiBusy: _aiBusy == 'scope',
                    onAi: (controller) => _runAi(
                      'scope',
                      () => GroqService.generateProposalScope(context: d),
                      (r) {
                        final prev = d.scopeOfWork;
                        d.scopeOfWork = r;
                        controller.text = r;
                        return prev;
                      },
                      (prev) {
                        d.scopeOfWork = prev;
                        controller.text = prev;
                      },
                      'Scope written with AI',
                    ),
                  ),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.calendar,
                  title: 'Timeline and pricing',
                  subtitle: 'Milestones and costs',
                  status: tpFilled == 2 ? 'Complete' : '$tpFilled of 2',
                  done: tpFilled == 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LongTextField(
                        label: 'Timeline',
                        hint: 'Week 1–2: Discovery\nWeek 3–5: Design',
                        initial: d.timeline,
                        set: (v) => d.timeline = v,
                        onChanged: _refresh,
                        minLines: 4,
                      ),
                      kFieldGap,
                      _LongTextField(
                        label: 'Pricing',
                        hint: 'One line item per line, e.g.\nDesign: \$2,000',
                        initial: d.pricing,
                        set: (v) => d.pricing = v,
                        onChanged: _refresh,
                        minLines: 4,
                      ),
                    ],
                  ),
                ),
                ResumeSectionCard(
                  icon: LucideIcons.scrollText,
                  title: 'Terms',
                  subtitle: 'Payment, revisions, ownership',
                  status: d.termsAndConditions.trim().isEmpty ? 'Optional' : 'Added',
                  done: d.termsAndConditions.trim().isNotEmpty,
                  child: _LongTextField(
                    label: 'Terms and conditions',
                    hint: 'e.g. 50% upfront, 50% on delivery. Two rounds of revisions included.',
                    initial: d.termsAndConditions,
                    set: (v) => d.termsAndConditions = v,
                    onChanged: _refresh,
                    minLines: 5,
                  ),
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

String _todayLabel() {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final n = DateTime.now();
  return '${n.day} ${months[n.month - 1]} ${n.year}';
}

class _FieldSpec {
  final String label;
  final String hint;
  final String initial;
  final ValueChanged<String> set;
  const _FieldSpec(this.label, this.hint, this.initial, this.set);
}

/// Two single-line fields, side by side (or stacked when [stacked]).
class _TwoTextFields extends StatefulWidget {
  final _FieldSpec first;
  final _FieldSpec second;
  final VoidCallback onChanged;
  final bool stacked;
  const _TwoTextFields({required this.first, required this.second, required this.onChanged, this.stacked = false});

  @override
  State<_TwoTextFields> createState() => _TwoTextFieldsState();
}

class _TwoTextFieldsState extends State<_TwoTextFields> {
  late final _a = TextEditingController(text: widget.first.initial);
  late final _b = TextEditingController(text: widget.second.initial);

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Widget _field(_FieldSpec spec, TextEditingController c) => AuthField(
        dense: true,
        label: spec.label,
        hint: spec.hint,
        controller: c,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onChanged: (v) {
          spec.set(v);
          widget.onChanged();
        },
      );

  @override
  Widget build(BuildContext context) {
    final a = _field(widget.first, _a);
    final b = _field(widget.second, _b);
    if (widget.stacked) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, kFieldGap, b]);
    }
    return FieldPair(a, b);
  }
}

/// Multi-line field with a word count and an optional AI button.
class _LongTextField extends StatefulWidget {
  final String label;
  final String hint;
  final String initial;
  final ValueChanged<String> set;
  final VoidCallback onChanged;
  final int minLines;
  final String? aiLabel;
  final bool aiBusy;
  final void Function(TextEditingController controller)? onAi;

  const _LongTextField({
    required this.label,
    required this.hint,
    required this.initial,
    required this.set,
    required this.onChanged,
    this.minLines = 6,
    this.aiLabel,
    this.aiBusy = false,
    this.onAi,
  });

  @override
  State<_LongTextField> createState() => _LongTextFieldState();
}

class _LongTextFieldState extends State<_LongTextField> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final text = _c.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          dense: true,
          label: widget.label,
          hint: widget.hint,
          controller: _c,
          maxLines: widget.minLines + 6,
          minLines: widget.minLines,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          onChanged: (v) {
            widget.set(v);
            setState(() {});
            widget.onChanged();
          },
        ),
        if (widget.onAi != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('$words ${words == 1 ? 'word' : 'words'}', style: TextStyle(fontSize: 12, color: p.muted)),
              ),
              AiPillButton(
                label: text.isEmpty ? widget.aiLabel! : 'Rewrite with AI',
                busy: widget.aiBusy,
                onPressed: () => widget.onAi!(_c),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SenderFields extends StatefulWidget {
  final ProposalData data;
  final VoidCallback onChanged;
  final VoidCallback onFillFromProfile;
  const _SenderFields({super.key, required this.data, required this.onChanged, required this.onFillFromProfile});

  @override
  State<_SenderFields> createState() => _SenderFieldsState();
}

class _SenderFieldsState extends State<_SenderFields> {
  late final _name = TextEditingController(text: widget.data.senderName);
  late final _company = TextEditingController(text: widget.data.senderCompany);
  late final _email = TextEditingController(text: widget.data.senderEmail);
  late final _phone = TextEditingController(text: widget.data.senderPhone);

  @override
  void dispose() {
    for (final c in [_name, _company, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  AuthField _f(String label, String hint, TextEditingController c, ValueChanged<String> set,
          {TextInputType? type, TextCapitalization caps = TextCapitalization.words}) =>
      AuthField(
        dense: true,
        label: label,
        hint: hint,
        controller: c,
        keyboardType: type,
        textCapitalization: caps,
        textInputAction: TextInputAction.next,
        onChanged: (v) {
          set(v);
          widget.onChanged();
        },
      );

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
          _f('Your name', 'Sarah Ahmed', _name, (v) => d.senderName = v),
          _f('Phone', '+92 300 1234567', _phone, (v) => d.senderPhone = v, type: TextInputType.phone),
        ),
        kFieldGap,
        _f('Company', 'Studio Sarah', _company, (v) => d.senderCompany = v),
        kFieldGap,
        _f('Email', 'you@example.com', _email, (v) => d.senderEmail = v,
            type: TextInputType.emailAddress, caps: TextCapitalization.none),
      ],
    );
  }
}
