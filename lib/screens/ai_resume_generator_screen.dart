import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/profile_repository.dart';
import '../theme/app_theme.dart';
import 'form_screen.dart';

const _uuid = Uuid();

const _templateTitles = {
  ResumeTemplate.classic: 'Classic',
  ResumeTemplate.modern: 'Modern',
  ResumeTemplate.minimal: 'Minimal',
  ResumeTemplate.professional: 'Professional',
  ResumeTemplate.compact: 'Compact',
  ResumeTemplate.executive: 'Executive',
  ResumeTemplate.technical: 'Technical',
  ResumeTemplate.simpleBold: 'Simple Bold',
  ResumeTemplate.harvard: 'Harvard',
  ResumeTemplate.creative: 'Creative',
  ResumeTemplate.elegant: 'Elegant',
  ResumeTemplate.timeline: 'Timeline',
};

/// Paste a job description + pick a template, and let AI tailor the user's
/// saved Profile into a resume for it. Requires a saved Profile to exist —
/// the caller (home_dashboard_screen.dart) is responsible for checking that
/// and redirecting to ProfileScreen first if it doesn't.
class AiResumeGeneratorScreen extends StatefulWidget {
  const AiResumeGeneratorScreen({super.key});

  @override
  State<AiResumeGeneratorScreen> createState() => _AiResumeGeneratorScreenState();
}

class _AiResumeGeneratorScreenState extends State<AiResumeGeneratorScreen> {
  final _jobDescription = TextEditingController();
  final _jobTitleOverride = TextEditingController();
  ResumeTemplate _template = ResumeTemplate.classic;

  @override
  void dispose() {
    _jobDescription.dispose();
    _jobTitleOverride.dispose();
    super.dispose();
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Couldn't generate resume"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _onGenerate() async {
    final jd = _jobDescription.text.trim();
    if (jd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a job description first.')),
      );
      return;
    }

    _showProgressDialog('Tailoring your resume to this job description…');
    try {
      final profile = await ProfileRepository.load();
      if (profile == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mounted) _showError('Your profile could not be loaded. Please set it up again.');
        return;
      }

      final tailored = await GroqService.generateTailoredResume(
        profile: profile,
        jobDescription: jd,
        jobTitleOverride: _jobTitleOverride.text.trim().isEmpty ? null : _jobTitleOverride.text.trim(),
      );
      await AiUsageTracker.recordUsage();

      final entry = DocumentEntry(
        id: _uuid.v4(),
        kind: DocumentKind.resume,
        title: tailored.personalInfo.fullName.isEmpty ? 'My Resume' : tailored.personalInfo.fullName,
        templateId: _template.name,
        updatedAt: DateTime.now(),
        completionPercent: tailored.completionPercent,
        payload: tailored.toJson(),
      );
      await DocumentsRepository.save(entry);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormScreen(entry: entry)),
      );
    } on AiServiceException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) _showError('Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Resume from Job Description')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Paste a job description below. AI will tailor your saved Profile\'s summary, '
              'wording, and skill selection to match it — your real employers, dates, and '
              'education are always kept exactly as you entered them.',
              style: TextStyle(color: AppColors.slate600, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _jobDescription,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Paste the job description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _jobTitleOverride,
              decoration: const InputDecoration(labelText: 'Job title override (optional)'),
            ),
            const SizedBox(height: 20),
            const Text('Template', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ResumeTemplate.values.map((t) {
                final selected = _template == t;
                return ChoiceChip(
                  label: Text(_templateTitles[t]!),
                  selected: selected,
                  onSelected: (_) => setState(() => _template = t),
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.slate800,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _onGenerate, child: const Text('Generate Resume')),
          ),
        ),
      ),
    );
  }
}
