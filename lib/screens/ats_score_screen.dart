import 'package:flutter/material.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../services/ai_usage_tracker.dart';
import '../services/ats_score_service.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/resume_pdf_importer.dart';
import '../theme/app_theme.dart';

/// Entry point for ATS scoring: pick a resume already saved in the app, or
/// upload an existing resume PDF, then hand off to [AtsScoreResultScreen].
/// Reached from the Home dashboard's "Check ATS Score" card.
class AtsScoreEntryScreen extends StatefulWidget {
  const AtsScoreEntryScreen({super.key});

  @override
  State<AtsScoreEntryScreen> createState() => _AtsScoreEntryScreenState();
}

class _AtsScoreEntryScreenState extends State<AtsScoreEntryScreen> {
  bool _working = false;

  Future<void> _scoreSavedResume() async {
    final all = await DocumentsRepository.loadAll();
    final resumes = all.where((d) => d.kind == DocumentKind.resume).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (resumes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("You don't have any saved resumes yet. Create one first, or upload a PDF instead."),
        ));
      }
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<DocumentEntry>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ResumePickerSheet(resumes: resumes),
    );
    if (chosen == null || !mounted) return;
    final data = ResumeData.fromJson(chosen.payload);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AtsScoreResultScreen(
          resumeData: data,
          sourceLabel: chosen.title.isEmpty ? 'Untitled Resume' : chosen.title,
        ),
      ),
    );
  }

  Future<void> _scoreUploadedResume() async {
    setState(() => _working = true);
    try {
      final text = await ResumePdfImporter.pickAndExtractText();
      if (text == null) return; // user cancelled the file picker
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AtsScoreResultScreen(rawText: text, sourceLabel: 'Uploaded resume'),
        ),
      );
    } on ResumeImportException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong reading that resume.')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check ATS Score')),
      body: SafeArea(
        child: _working
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    "See how well a resume would survive an Applicant Tracking System's automated "
                    'screening — contact info, standard sections, quantified achievements, and '
                    'more — plus AI-written feedback on how to improve it.',
                    style: TextStyle(color: AppColors.slate600, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  _ChoiceCard(
                    icon: Icons.description_outlined,
                    title: 'Score a saved resume',
                    subtitle: "Check one of the resumes you've already built in the app.",
                    onTap: _scoreSavedResume,
                  ),
                  const SizedBox(height: 14),
                  _ChoiceCard(
                    icon: Icons.upload_file_outlined,
                    title: 'Upload a resume (PDF)',
                    subtitle: 'Check an existing resume from your device.',
                    onTap: _scoreUploadedResume,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.card(radius: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColors.slate600, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}

class _ResumePickerSheet extends StatelessWidget {
  final List<DocumentEntry> resumes;
  const _ResumePickerSheet({required this.resumes});

  static String _relativeDate(DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'Updated today';
    if (days == 1) return 'Updated yesterday';
    return 'Updated $days days ago';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        itemCount: resumes.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68, color: AppColors.cardBorder),
        itemBuilder: (_, i) {
          final r = resumes[i];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: AppColors.primary,
              child: Icon(Icons.description_outlined, size: 20),
            ),
            title: Text(r.title.isEmpty ? 'Untitled Resume' : r.title),
            subtitle: Text(_relativeDate(r.updatedAt)),
            onTap: () => Navigator.pop(context, r),
          );
        },
      ),
    );
  }
}

/// Shows the rule-based score/checklist immediately (instant, always
/// available), then loads AI-written feedback in the background — a failure
/// or daily-limit hit there degrades gracefully rather than blocking the
/// score itself. Exactly one of [resumeData]/[rawText] must be given.
class AtsScoreResultScreen extends StatefulWidget {
  final ResumeData? resumeData;
  final String? rawText;
  final String sourceLabel;

  const AtsScoreResultScreen({super.key, this.resumeData, this.rawText, required this.sourceLabel})
      : assert(resumeData != null || rawText != null, 'Provide either resumeData or rawText');

  @override
  State<AtsScoreResultScreen> createState() => _AtsScoreResultScreenState();
}

class _AtsScoreResultScreenState extends State<AtsScoreResultScreen> {
  late final AtsScoreResult _result;
  late final String _flatText;
  final _jobDescription = TextEditingController();
  KeywordMatchResult? _keywordResult;

  bool _aiLoading = true;
  String? _aiSummary;
  List<String> _aiSuggestions = [];
  String? _aiUnavailableReason;

  @override
  void initState() {
    super.initState();
    if (widget.resumeData != null) {
      _result = AtsScoreService.scoreResumeData(widget.resumeData!);
      _flatText = AtsScoreService.flattenResumeText(widget.resumeData!);
    } else {
      _result = AtsScoreService.scoreRawText(widget.rawText!);
      _flatText = widget.rawText!;
    }
    _loadAiFeedback();
  }

  @override
  void dispose() {
    _jobDescription.dispose();
    super.dispose();
  }

  Future<void> _loadAiFeedback() async {
    if (!GroqService.isConfigured) {
      setState(() {
        _aiLoading = false;
        _aiUnavailableReason = "AI feedback isn't set up on this build.";
      });
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiUnavailableReason = "You've used today's free AI generations — the checklist above still "
              'applies, upgrade to Pro for unlimited AI feedback.';
        });
      }
      return;
    }
    try {
      final review = await GroqService.reviewAtsScore(resumeText: _flatText);
      await AiUsageTracker.recordUsage();
      if (!mounted) return;
      setState(() {
        _aiSummary = review.summary;
        _aiSuggestions = review.suggestions;
        _aiLoading = false;
      });
    } on AiServiceException catch (e) {
      if (mounted) setState(() { _aiLoading = false; _aiUnavailableReason = e.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiUnavailableReason = 'Something went wrong getting AI feedback.';
        });
      }
    }
  }

  void _checkKeywordMatch() {
    final jd = _jobDescription.text.trim();
    if (jd.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _keywordResult = AtsScoreService.matchKeywords(jobDescription: jd, resumeText: _flatText);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ATS Score')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.sourceLabel,
              style: const TextStyle(color: AppColors.slate600, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Center(child: _ScoreGauge(score: _result.score)),
            const SizedBox(height: 28),
            Text('Checklist', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Container(
              decoration: AppDecorations.card(radius: 16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _result.checks.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                    _CheckRow(item: _result.checks[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('AI Feedback', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            _AiFeedbackCard(
              loading: _aiLoading,
              summary: _aiSummary,
              suggestions: _aiSuggestions,
              unavailableReason: _aiUnavailableReason,
            ),
            const SizedBox(height: 28),
            Text('Match against a job description', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Optional — paste a job posting to see which of its key terms this resume already covers.',
              style: TextStyle(color: AppColors.slate600, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _jobDescription,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Paste a job description', alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: _checkKeywordMatch, child: const Text('Check Keyword Match')),
            ),
            if (_keywordResult != null) ...[
              const SizedBox(height: 14),
              _KeywordMatchCard(result: _keywordResult!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular 0-100 gauge, colored by band: red (<60), gold (60-79), green
/// (80+) — mirrors the same "traffic light" convention as
/// ResumeData.completionPercent's use elsewhere in the app.
class _ScoreGauge extends StatelessWidget {
  final int score;
  const _ScoreGauge({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.accentGoldDeep;
    return AppColors.danger;
  }

  String get _label {
    if (score >= 80) return 'Strong';
    if (score >= 60) return 'Needs work';
    return 'Weak';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 156,
            height: 156,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 12,
              backgroundColor: AppColors.primaryLight,
              valueColor: AlwaysStoppedAnimation(_color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: _color)),
              Text(_label, style: const TextStyle(color: AppColors.slate600, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final AtsCheckItem item;
  const _CheckRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.passed ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(item.passed ? Icons.check_rounded : Icons.close_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(item.hint, style: const TextStyle(color: AppColors.slate600, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiFeedbackCard extends StatelessWidget {
  final bool loading;
  final String? summary;
  final List<String> suggestions;
  final String? unavailableReason;
  const _AiFeedbackCard({
    required this.loading,
    required this.summary,
    required this.suggestions,
    required this.unavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 16),
      child: loading
          ? const Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Getting AI feedback…', style: TextStyle(color: AppColors.slate600))),
              ],
            )
          : (unavailableReason != null)
              ? Text(unavailableReason!, style: const TextStyle(color: AppColors.slate600, fontSize: 12.5, height: 1.4))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (summary != null && summary!.isNotEmpty)
                      Text(summary!, style: const TextStyle(fontSize: 13, height: 1.45)),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final s in suggestions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Icon(Icons.circle, size: 6, color: AppColors.accentGoldDeep),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(s, style: const TextStyle(fontSize: 12.5, height: 1.4))),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _KeywordMatchCard extends StatelessWidget {
  final KeywordMatchResult result;
  const _KeywordMatchCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matched ${result.matched} of ${result.total} key terms',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          if (result.missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Consider adding:', style: TextStyle(color: AppColors.slate600, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.missing
                  .map((k) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(k, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Great coverage — no obvious gaps found.', style: TextStyle(color: AppColors.slate600, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
