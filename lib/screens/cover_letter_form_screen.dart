import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cover_letter_data.dart';
import '../theme/app_theme.dart';
import 'cover_letter_home_screen.dart';
import 'cover_letter_template_screen.dart';

class CoverLetterFormScreen extends StatefulWidget {
  final CoverLetterData data;
  const CoverLetterFormScreen({super.key, required this.data});

  @override
  State<CoverLetterFormScreen> createState() => _CoverLetterFormScreenState();
}

class _CoverLetterFormScreenState extends State<CoverLetterFormScreen> {
  int _step = 0;

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kCoverLetterStorageKey, widget.data.encode());
  }

  void _next() {
    _save();
    if (_step < 1) {
      setState(() => _step++);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CoverLetterTemplateScreen(data: widget.data)),
      );
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Sender & Recipient', 'Letter Content'];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text(steps[_step]),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(step: _step, total: steps.length),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: IndexedStack(
                  index: _step,
                  children: [
                    _SenderRecipientStep(data: widget.data),
                    _LetterContentStep(data: widget.data),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_step < 1 ? 'Continue' : 'Choose Template'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.gold : const Color(0xFFE1E4E8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SenderRecipientStep extends StatefulWidget {
  final CoverLetterData data;
  const _SenderRecipientStep({required this.data});

  @override
  State<_SenderRecipientStep> createState() => _SenderRecipientStepState();
}

class _SenderRecipientStepState extends State<_SenderRecipientStep> {
  late final Map<String, TextEditingController> _c = {
    'fullName': TextEditingController(text: widget.data.fullName),
    'email': TextEditingController(text: widget.data.email),
    'phone': TextEditingController(text: widget.data.phone),
    'address': TextEditingController(text: widget.data.address),
    'date': TextEditingController(text: widget.data.date),
    'jobTitle': TextEditingController(text: widget.data.jobTitle),
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
    return ListView(
      children: [
        const _SectionLabel('Your Details'),
        _field('Full Name', _c['fullName']!, (v) => d.fullName = v),
        _field('Email', _c['email']!, (v) => d.email = v),
        _field('Phone', _c['phone']!, (v) => d.phone = v),
        _field('Address', _c['address']!, (v) => d.address = v),
        _field('Date', _c['date']!, (v) => d.date = v),
        _field('Position You\'re Applying For', _c['jobTitle']!, (v) => d.jobTitle = v),
        const SizedBox(height: 12),
        const _SectionLabel('Recipient'),
        _field('Recipient Name', _c['recipientName']!, (v) => d.recipientName = v),
        _field('Recipient Title', _c['recipientTitle']!, (v) => d.recipientTitle = v),
        _field('Company Name', _c['companyName']!, (v) => d.companyName = v),
        _field('Company Address', _c['companyAddress']!, (v) => d.companyAddress = v),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, Function(String) onSave) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        onChanged: onSave,
      ),
    );
  }
}

class _LetterContentStep extends StatefulWidget {
  final CoverLetterData data;
  const _LetterContentStep({required this.data});

  @override
  State<_LetterContentStep> createState() => _LetterContentStepState();
}

class _LetterContentStepState extends State<_LetterContentStep> {
  late final _salutation = TextEditingController(text: widget.data.salutation);
  late final _body = TextEditingController(text: widget.data.body);
  late final _closing = TextEditingController(text: widget.data.closing);

  @override
  void dispose() {
    _salutation.dispose();
    _body.dispose();
    _closing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ListView(
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
          padding: const EdgeInsets.only(bottom: 14),
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
        TextFormField(
          controller: _closing,
          decoration: const InputDecoration(labelText: 'Closing'),
          onChanged: (v) => d.closing = v,
        ),
      ],
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
