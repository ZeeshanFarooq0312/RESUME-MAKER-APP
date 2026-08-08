import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../widgets/accordion_section.dart';
import '../widgets/ai_action_button.dart';
import 'cover_letter_preview_screen.dart';
import 'cover_letter_template_screen.dart';
import 'paywall_screen.dart';

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

void _showAiLimitReachedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Daily AI limit reached'),
      content: const Text(
          "You've used today's free AI generations. Upgrade to Pro for unlimited AI-powered "
          'summaries, rewrites, cover letters, and resume generation.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
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

void _showAiErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

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

  Future<void> _saveEntry() async {
    await DocumentsRepository.save(DocumentEntry(
      id: _entryId,
      kind: DocumentKind.coverLetter,
      title: data.jobTitle.isEmpty ? 'My Cover Letter' : data.jobTitle,
      templateId: widget.initialTemplate?.name ??
          widget.entry?.templateId ??
          CoverLetterTemplate.classic.name,
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
          builder: (_) => CoverLetterPreviewScreen(
            data: data,
            template: template,
            documentId: _entryId,
            isPremium: template.isPremium,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CoverLetterTemplateScreen(data: data, documentId: _entryId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        title: Text(widget.entry == null ? 'New Cover Letter' : 'Edit Cover Letter'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AccordionSection(
              title: 'Your Details',
              initiallyExpanded: true,
              child: _YourDetailsFields(data: data),
            ),
            AccordionSection(title: 'Recipient', child: _RecipientFields(data: data)),
            AccordionSection(title: 'Letter Content', child: _LetterContentFields(data: data)),
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

class _YourDetailsFields extends StatefulWidget {
  final CoverLetterData data;
  const _YourDetailsFields({required this.data});

  @override
  State<_YourDetailsFields> createState() => _YourDetailsFieldsState();
}

class _YourDetailsFieldsState extends State<_YourDetailsFields> {
  late final Map<String, TextEditingController> _c = {
    'fullName': TextEditingController(text: widget.data.fullName),
    'email': TextEditingController(text: widget.data.email),
    'phone': TextEditingController(text: widget.data.phone),
    'address': TextEditingController(text: widget.data.address),
    'date': TextEditingController(text: widget.data.date),
    'jobTitle': TextEditingController(text: widget.data.jobTitle),
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
        _field('Full Name', _c['fullName']!, (v) => d.fullName = v),
        _field('Email', _c['email']!, (v) => d.email = v),
        _field('Phone', _c['phone']!, (v) => d.phone = v),
        _field('Address', _c['address']!, (v) => d.address = v),
        _field('Date', _c['date']!, (v) => d.date = v),
        _field('Position You\'re Applying For', _c['jobTitle']!, (v) => d.jobTitle = v,
            isLast: true),
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

class _RecipientFields extends StatefulWidget {
  final CoverLetterData data;
  const _RecipientFields({required this.data});

  @override
  State<_RecipientFields> createState() => _RecipientFieldsState();
}

class _RecipientFieldsState extends State<_RecipientFields> {
  late final Map<String, TextEditingController> _c = {
    'recipientName': TextEditingController(text: widget.data.recipientName),
    'recipientTitle': TextEditingController(text: widget.data.recipientTitle),
    'companyName': TextEditingController(text: widget.data.companyName),
    'companyAddress': TextEditingController(text: widget.data.companyAddress),
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
        _field('Recipient Name', _c['recipientName']!, (v) => d.recipientName = v),
        _field('Recipient Title', _c['recipientTitle']!, (v) => d.recipientTitle = v),
        _field('Company Name', _c['companyName']!, (v) => d.companyName = v),
        _field('Company Address', _c['companyAddress']!, (v) => d.companyAddress = v, isLast: true),
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

class _LetterContentFields extends StatefulWidget {
  final CoverLetterData data;
  const _LetterContentFields({required this.data});

  @override
  State<_LetterContentFields> createState() => _LetterContentFieldsState();
}

class _LetterContentFieldsState extends State<_LetterContentFields> {
  late final _salutation = TextEditingController(text: widget.data.salutation);
  late final _body = TextEditingController(text: widget.data.body);
  late final _closing = TextEditingController(text: widget.data.closing);
  bool _aiBusy = false;

  @override
  void dispose() {
    _salutation.dispose();
    _body.dispose();
    _closing.dispose();
    super.dispose();
  }

  Future<void> _onGenerateWithAi() async {
    if (!GroqService.isConfigured) {
      _showAiNotConfiguredDialog(context);
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) _showAiLimitReachedDialog(context);
      return;
    }
    if (!mounted) return;
    final d = widget.data;
    if (d.jobTitle.trim().isEmpty && d.companyName.trim().isEmpty) {
      _showAiErrorSnackBar(context, 'Fill in Position and Company first so AI has something to write about.');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final result = await GroqService.generateCoverLetterBody(context: d);
      await AiUsageTracker.recordUsage();
      final previous = _body.text;
      setState(() {
        _body.text = result;
        d.body = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Letter body generated with AI'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() {
              _body.text = previous;
              d.body = previous;
            }),
          ),
        ));
      }
    } on AiServiceException catch (e) {
      if (mounted) _showAiErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _salutation,
            decoration: const InputDecoration(labelText: 'Salutation'),
            onChanged: (v) => d.salutation = v,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TextFormField(
            controller: _body,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Letter Body',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => d.body = v,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AiActionButton(
            label: 'Generate with AI',
            busy: _aiBusy,
            onPressed: _aiBusy ? null : _onGenerateWithAi,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _closing,
          decoration: const InputDecoration(labelText: 'Closing'),
          onChanged: (v) => d.closing = v,
        ),
      ],
    );
  }
}
