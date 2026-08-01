import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../theme/app_theme.dart';
import '../widgets/accordion_section.dart';
import '../widgets/ai_action_button.dart';
import 'proposal_preview_screen.dart';
import 'proposal_template_screen.dart';

const _uuid = Uuid();

void _showAiNotConfiguredDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('AI features not set up'),
      content: const Text("AI features aren't set up on this build. Ask the developer to configure a Groq API key."),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );
}

void _showAiErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class ProposalFormScreen extends StatefulWidget {
  final DocumentEntry? entry;
  final ProposalTemplate? initialTemplate;
  const ProposalFormScreen({super.key, this.entry, this.initialTemplate});

  @override
  State<ProposalFormScreen> createState() => _ProposalFormScreenState();
}

class _ProposalFormScreenState extends State<ProposalFormScreen> {
  late final String _entryId = widget.entry?.id ?? _uuid.v4();
  late final ProposalData data =
      widget.entry != null ? ProposalData.fromJson(widget.entry!.payload) : ProposalData();

  Future<void> _saveEntry() async {
    await DocumentsRepository.save(DocumentEntry(
      id: _entryId,
      kind: DocumentKind.proposal,
      title: data.title.isEmpty ? 'My Proposal' : data.title,
      templateId: widget.initialTemplate?.name ??
          widget.entry?.templateId ??
          ProposalTemplate.classic.name,
      updatedAt: DateTime.now(),
      completionPercent: data.completionPercent,
      payload: data.toJson(),
    ));
  }

  Future<void> _onBack() async {
    await _saveEntry();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onExport() async {
    await _saveEntry();
    if (!mounted) return;
    final template = widget.initialTemplate;
    if (template != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProposalPreviewScreen(data: data, template: template, documentId: _entryId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProposalTemplateScreen(data: data, documentId: _entryId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        title: Text(widget.entry == null ? 'New Proposal' : 'Edit Proposal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AccordionSection(
              title: 'Parties & Date',
              initiallyExpanded: true,
              child: _PartiesFields(data: data),
            ),
            AccordionSection(title: 'Overview & Scope', child: _OverviewScopeFields(data: data)),
            AccordionSection(title: 'Timeline & Pricing', child: _TimelinePricingFields(data: data)),
            AccordionSection(title: 'Terms', child: _TermsFields(data: data)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _onExport, child: const Text('Preview & Export')),
          ),
        ),
      ),
    );
  }
}

class _PartiesFields extends StatefulWidget {
  final ProposalData data;
  const _PartiesFields({required this.data});

  @override
  State<_PartiesFields> createState() => _PartiesFieldsState();
}

class _PartiesFieldsState extends State<_PartiesFields> {
  late final Map<String, TextEditingController> _c = {
    'title': TextEditingController(text: widget.data.title),
    'senderName': TextEditingController(text: widget.data.senderName),
    'senderCompany': TextEditingController(text: widget.data.senderCompany),
    'senderEmail': TextEditingController(text: widget.data.senderEmail),
    'senderPhone': TextEditingController(text: widget.data.senderPhone),
    'clientName': TextEditingController(text: widget.data.clientName),
    'clientCompany': TextEditingController(text: widget.data.clientCompany),
    'date': TextEditingController(text: widget.data.date),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        _field('Proposal Title', _c['title']!, (v) => d.title = v),
        const _SectionLabel('From'),
        _field('Your Name', _c['senderName']!, (v) => d.senderName = v),
        _field('Your Company', _c['senderCompany']!, (v) => d.senderCompany = v),
        _field('Email', _c['senderEmail']!, (v) => d.senderEmail = v),
        _field('Phone', _c['senderPhone']!, (v) => d.senderPhone = v),
        const SizedBox(height: 8),
        const _SectionLabel('To'),
        _field('Client Name', _c['clientName']!, (v) => d.clientName = v),
        _field('Client Company', _c['clientCompany']!, (v) => d.clientCompany = v),
        _field('Date', _c['date']!, (v) => d.date = v, isLast: true),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, Function(String) onSave,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        onChanged: onSave,
      ),
    );
  }
}

class _OverviewScopeFields extends StatefulWidget {
  final ProposalData data;
  const _OverviewScopeFields({required this.data});

  @override
  State<_OverviewScopeFields> createState() => _OverviewScopeFieldsState();
}

class _OverviewScopeFieldsState extends State<_OverviewScopeFields> {
  late final _overview = TextEditingController(text: widget.data.overview);
  late final _scope = TextEditingController(text: widget.data.scopeOfWork);
  // Tracks which field is generating, if any — only one AI call runs at a time.
  String? _busyField;

  @override
  void dispose() {
    _overview.dispose();
    _scope.dispose();
    super.dispose();
  }

  bool get _titleMissing => widget.data.title.trim().isEmpty;

  Future<void> _onGenerateOverview() async {
    if (!GroqService.isConfigured) {
      _showAiNotConfiguredDialog(context);
      return;
    }
    if (_titleMissing) {
      _showAiErrorSnackBar(context, 'Fill in the Proposal Title first so AI has something to write about.');
      return;
    }
    setState(() => _busyField = 'overview');
    try {
      final result = await GroqService.generateProposalOverview(context: widget.data);
      final previous = _overview.text;
      setState(() {
        _overview.text = result;
        widget.data.overview = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Overview generated with AI'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() {
              _overview.text = previous;
              widget.data.overview = previous;
            }),
          ),
        ));
      }
    } on AiServiceException catch (e) {
      if (mounted) _showAiErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _busyField = null);
    }
  }

  Future<void> _onGenerateScope() async {
    if (!GroqService.isConfigured) {
      _showAiNotConfiguredDialog(context);
      return;
    }
    if (_titleMissing) {
      _showAiErrorSnackBar(context, 'Fill in the Proposal Title first so AI has something to write about.');
      return;
    }
    setState(() => _busyField = 'scope');
    try {
      final result = await GroqService.generateProposalScope(context: widget.data);
      final previous = _scope.text;
      setState(() {
        _scope.text = result;
        widget.data.scopeOfWork = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Scope of work generated with AI'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() {
              _scope.text = previous;
              widget.data.scopeOfWork = previous;
            }),
          ),
        ));
      }
    } on AiServiceException catch (e) {
      if (mounted) _showAiErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _busyField = null);
    }
  }

  Widget _aiButton(String label, String field, VoidCallback onPressed) {
    final busy = _busyField == field;
    return Align(
      alignment: Alignment.centerRight,
      child: AiActionButton(
        label: label,
        busy: busy,
        onPressed: _busyField == null ? onPressed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TextFormField(
            controller: _overview,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Overview / Executive Summary',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => d.overview = v,
          ),
        ),
        _aiButton('Generate with AI', 'overview', _onGenerateOverview),
        const SizedBox(height: 10),
        TextFormField(
          controller: _scope,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Scope of Work (one item per line)',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => d.scopeOfWork = v,
        ),
        _aiButton('Generate with AI', 'scope', _onGenerateScope),
      ],
    );
  }
}

class _TimelinePricingFields extends StatefulWidget {
  final ProposalData data;
  const _TimelinePricingFields({required this.data});

  @override
  State<_TimelinePricingFields> createState() => _TimelinePricingFieldsState();
}

class _TimelinePricingFieldsState extends State<_TimelinePricingFields> {
  late final _timeline = TextEditingController(text: widget.data.timeline);
  late final _pricing = TextEditingController(text: widget.data.pricing);

  @override
  void dispose() {
    _timeline.dispose();
    _pricing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _timeline,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Timeline / Milestones',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => d.timeline = v,
          ),
        ),
        TextFormField(
          controller: _pricing,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Pricing (one line item per line)',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => d.pricing = v,
        ),
      ],
    );
  }
}

class _TermsFields extends StatefulWidget {
  final ProposalData data;
  const _TermsFields({required this.data});

  @override
  State<_TermsFields> createState() => _TermsFieldsState();
}

class _TermsFieldsState extends State<_TermsFields> {
  late final _terms = TextEditingController(text: widget.data.termsAndConditions);

  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _terms,
      maxLines: 10,
      decoration: const InputDecoration(
        labelText: 'Terms & Conditions',
        alignLabelWithHint: true,
      ),
      onChanged: (v) => widget.data.termsAndConditions = v,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.slate600, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}
