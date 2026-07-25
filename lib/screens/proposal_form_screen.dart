import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/proposal_data.dart';
import '../theme/app_theme.dart';
import 'proposal_home_screen.dart';
import 'proposal_template_screen.dart';

class ProposalFormScreen extends StatefulWidget {
  final ProposalData data;
  const ProposalFormScreen({super.key, required this.data});

  @override
  State<ProposalFormScreen> createState() => _ProposalFormScreenState();
}

class _ProposalFormScreenState extends State<ProposalFormScreen> {
  int _step = 0;

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kProposalStorageKey, widget.data.encode());
  }

  void _next() {
    _save();
    if (_step < 3) {
      setState(() => _step++);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProposalTemplateScreen(data: widget.data)),
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
    final steps = ['Parties & Date', 'Overview & Scope', 'Timeline & Pricing', 'Terms'];
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
                    _PartiesStep(data: widget.data),
                    _OverviewScopeStep(data: widget.data),
                    _TimelinePricingStep(data: widget.data),
                    _TermsStep(data: widget.data),
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
                  child: Text(_step < 3 ? 'Continue' : 'Choose Template'),
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

class _PartiesStep extends StatefulWidget {
  final ProposalData data;
  const _PartiesStep({required this.data});

  @override
  State<_PartiesStep> createState() => _PartiesStepState();
}

class _PartiesStepState extends State<_PartiesStep> {
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
    return ListView(
      children: [
        _field('Proposal Title', _c['title']!, (v) => d.title = v),
        const _SectionLabel('From'),
        _field('Your Name', _c['senderName']!, (v) => d.senderName = v),
        _field('Your Company', _c['senderCompany']!, (v) => d.senderCompany = v),
        _field('Email', _c['senderEmail']!, (v) => d.senderEmail = v),
        _field('Phone', _c['senderPhone']!, (v) => d.senderPhone = v),
        const SizedBox(height: 12),
        const _SectionLabel('To'),
        _field('Client Name', _c['clientName']!, (v) => d.clientName = v),
        _field('Client Company', _c['clientCompany']!, (v) => d.clientCompany = v),
        _field('Date', _c['date']!, (v) => d.date = v),
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

class _OverviewScopeStep extends StatefulWidget {
  final ProposalData data;
  const _OverviewScopeStep({required this.data});

  @override
  State<_OverviewScopeStep> createState() => _OverviewScopeStepState();
}

class _OverviewScopeStepState extends State<_OverviewScopeStep> {
  late final _overview = TextEditingController(text: widget.data.overview);
  late final _scope = TextEditingController(text: widget.data.scopeOfWork);

  @override
  void dispose() {
    _overview.dispose();
    _scope.dispose();
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
            controller: _overview,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Overview / Executive Summary',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => d.overview = v,
          ),
        ),
        TextFormField(
          controller: _scope,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Scope of Work (one item per line)',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => d.scopeOfWork = v,
        ),
      ],
    );
  }
}

class _TimelinePricingStep extends StatefulWidget {
  final ProposalData data;
  const _TimelinePricingStep({required this.data});

  @override
  State<_TimelinePricingStep> createState() => _TimelinePricingStepState();
}

class _TimelinePricingStepState extends State<_TimelinePricingStep> {
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
    return ListView(
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

class _TermsStep extends StatefulWidget {
  final ProposalData data;
  const _TermsStep({required this.data});

  @override
  State<_TermsStep> createState() => _TermsStepState();
}

class _TermsStepState extends State<_TermsStep> {
  late final _terms = TextEditingController(text: widget.data.termsAndConditions);

  @override
  void dispose() {
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ListView(
      children: [
        TextFormField(
          controller: _terms,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Terms & Conditions',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => d.termsAndConditions = v,
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
