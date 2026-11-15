import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../services/ai_usage_tracker.dart';
import '../services/ats_score_service.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/resume_pdf_importer.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/document_card.dart' show relativeTime;
import '../widgets/responsive_scaffold.dart';

/// Entry point for ATS scoring: pick a resume already saved in the app, or
/// upload an existing resume PDF, then hand off to [AtsScoreResultScreen].
/// Reached from the Home dashboard's "ATS score check" card.
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
        showToast(context, "You don't have any saved resumes yet. Create one first, or upload a PDF instead.");
      }
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<DocumentEntry>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ResumePickerSheet(resumes: resumes),
    );
    if (chosen == null || !mounted) return;
    final data = ResumeData.fromJson(chosen.payload);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AtsScoreResultScreen(
          resumeData: data,
          sourceLabel: chosen.title.isEmpty ? 'Untitled resume' : chosen.title,
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
        MaterialPageRoute(builder: (_) => AtsScoreResultScreen(rawText: text, sourceLabel: 'Uploaded resume')),
      );
    } on ResumeImportException catch (e) {
      if (mounted) showToast(context, e.message, tone: ToastTone.error);
    } catch (_) {
      if (mounted) showToast(context, 'Something went wrong reading that resume.', tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
            tooltip: 'Back', icon: const Icon(LucideIcons.arrowLeft), onPressed: () => Navigator.maybePop(context)),
      ),
      body: SafeArea(
        top: false,
        child: _working
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: p.title)),
                    const SizedBox(height: 14),
                    Text('Reading your resume…', style: TextStyle(fontSize: 14, color: p.body)),
                  ],
                ),
              )
            : ResponsiveContentBound(
                maxWidth: 620,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.fieldBorder)),
                        child: Icon(LucideIcons.gauge, color: p.title, size: 24),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Check your ATS score',
                      style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 28,
                          height: 1.15,
                          letterSpacing: -0.3,
                          fontWeight: FontWeight.w600,
                          color: p.title),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'See how screening software reads your resume: contact info, standard sections, '
                      'measurable results and more, plus AI tips to improve it.',
                      style: TextStyle(fontSize: 14.5, height: 1.5, color: p.body),
                    ),
                    const SizedBox(height: 26),
                    _ChoiceCard(
                      icon: LucideIcons.fileText,
                      title: 'Score a saved resume',
                      subtitle: "Check one you've built in the app.",
                      onTap: _scoreSavedResume,
                    ),
                    const SizedBox(height: 12),
                    _ChoiceCard(
                      icon: LucideIcons.fileUp,
                      title: 'Upload a PDF',
                      subtitle: 'Check an existing resume from your phone.',
                      onTap: _scoreUploadedResume,
                    ),
                  ],
                ),
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
  const _ChoiceCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.fieldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: p.title, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.title)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: p.body, fontSize: 13)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: p.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumePickerSheet extends StatelessWidget {
  final List<DocumentEntry> resumes;
  const _ResumePickerSheet({required this.resumes});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose a resume',
              style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: p.title)),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: resumes.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 58, color: p.fieldBorder),
              itemBuilder: (_, i) {
                final r = resumes[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(12)),
                          child: Icon(LucideIcons.fileText, size: 20, color: p.title),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title.isEmpty ? 'Untitled resume' : r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.title)),
                              const SizedBox(height: 2),
                              Text('Edited ${relativeTime(r.updatedAt).toLowerCase()}',
                                  style: TextStyle(fontSize: 12.5, color: p.body)),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.chevronRight, size: 18, color: p.muted),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
  bool _aiTailoredToJob = false;

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

  Future<void> _loadAiFeedback({String? jobDescription}) async {
    if (!GroqService.isConfigured) {
      setState(() {
        _aiLoading = false;
        _aiUnavailableReason = "AI tips aren't available in this version. The checklist above still applies.";
      });
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiUnavailableReason = "You've used today's free AI. The checklist above still applies; "
              'upgrade to Pro for unlimited AI tips.';
        });
      }
      return;
    }
    setState(() {
      _aiLoading = true;
      _aiUnavailableReason = null;
    });
    try {
      final review = await GroqService.reviewAtsScore(resumeText: _flatText, jobDescription: jobDescription);
      await AiUsageTracker.recordUsage();
      if (!mounted) return;
      setState(() {
        _aiSummary = review.summary;
        _aiSuggestions = review.suggestions;
        _aiLoading = false;
        _aiTailoredToJob = jobDescription != null;
      });
    } on AiServiceException catch (e) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiUnavailableReason = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiUnavailableReason = 'Something went wrong getting AI tips.';
        });
      }
    }
  }

  bool _needJobDescription() {
    if (_jobDescription.text.trim().isNotEmpty) return false;
    showToast(context, 'Paste a job description first.');
    return true;
  }

  void _checkKeywordMatch() {
    if (_needJobDescription()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _keywordResult =
          AtsScoreService.matchKeywords(jobDescription: _jobDescription.text.trim(), resumeText: _flatText);
    });
  }

  Future<void> _getAiSuggestionsForJob() async {
    if (_needJobDescription()) return;
    FocusScope.of(context).unfocus();
    await _loadAiFeedback(jobDescription: _jobDescription.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    // Failed checks first — those are the ones to act on.
    final checks = [..._result.checks]..sort((a, b) => (a.passed ? 1 : 0).compareTo(b.passed ? 1 : 0));
    final passed = _result.checks.where((c) => c.passed).length;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
            tooltip: 'Back', icon: const Icon(LucideIcons.arrowLeft), onPressed: () => Navigator.maybePop(context)),
        title: const Text('ATS score'),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContentBound(
          maxWidth: 720,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _ScoreHeader(
                score: _result.score,
                source: widget.sourceLabel,
                passed: passed,
                total: _result.checks.length,
              ),
              const _SectionHeader(title: 'Checklist', subtitle: 'What screening software looks for'),
              _Card(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < checks.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 58, color: p.fieldBorder),
                      _CheckRow(item: checks[i]),
                    ],
                  ],
                ),
              ),
              const _SectionHeader(title: 'AI tips', subtitle: 'How to make it stronger'),
              _AiFeedbackCard(
                loading: _aiLoading,
                summary: _aiSummary,
                suggestions: _aiSuggestions,
                unavailableReason: _aiUnavailableReason,
                tailoredToJob: _aiTailoredToJob,
              ),
              const _SectionHeader(
                title: 'Match a job',
                subtitle: 'Paste a job post to see which key terms you already cover',
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthField(
                      dense: true,
                      label: 'Job description',
                      hint: 'Paste the full job posting here',
                      controller: _jobDescription,
                      maxLines: 8,
                      minLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _checkKeywordMatch,
                              icon: const Icon(LucideIcons.listChecks, size: 18),
                              label: const Text('Keywords'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: p.title,
                                side: BorderSide(color: p.fieldBorder, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle:
                                    const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _aiLoading ? null : _getAiSuggestionsForJob,
                              icon: const Icon(LucideIcons.sparkles, size: 18),
                              label: const Text('AI tips'),
                              style: FilledButton.styleFrom(
                                backgroundColor: p.primary,
                                foregroundColor: p.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle:
                                    const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_keywordResult != null) ...[
                      const SizedBox(height: 16),
                      _KeywordMatch(result: _keywordResult!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.fieldBorder),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.title)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 13, color: p.body)),
        ],
      ),
    );
  }
}

/// Big score ring colored by band — red (<60), gold (60–79), green (80+).
class _ScoreHeader extends StatelessWidget {
  final int score;
  final String source;
  final int passed;
  final int total;
  const _ScoreHeader({required this.score, required this.source, required this.passed, required this.total});

  Color get _color => score >= 80
      ? AppColors.success
      : score >= 60
          ? AppColors.accentGoldDeep
          : AppColors.danger;

  String get _verdict => score >= 80
      ? 'Strong'
      : score >= 60
          ? 'Needs work'
          : 'Weak';

  String get _message => score >= 80
      ? 'Most screening software should read this resume well.'
      : score >= 60
          ? 'Fix the items below to improve your chances.'
          : 'Screening software may struggle with this resume. Start with the items below.';

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: v,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: p.background,
                    color: _color,
                  ),
                  Center(
                    child: Text(
                      '${(v * 100).round()}',
                      style: TextStyle(
                          fontFamily: 'Fraunces', fontSize: 34, height: 1, fontWeight: FontWeight.w600, color: p.title),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_verdict, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color)),
                ),
                const SizedBox(height: 8),
                Text('$passed of $total checks passed',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.title)),
                const SizedBox(height: 4),
                Text(_message, style: TextStyle(fontSize: 13, height: 1.4, color: p.body)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.fileText, size: 13, color: p.muted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(source,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
                    ),
                  ],
                ),
              ],
            ),
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
    final p = AuthPalette.of(context);
    final color = item.passed ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(item.passed ? LucideIcons.check : LucideIcons.x, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: p.title)),
                const SizedBox(height: 3),
                Text(item.hint, style: TextStyle(color: p.body, fontSize: 13, height: 1.4)),
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
  final bool tailoredToJob;
  const _AiFeedbackCard({
    required this.loading,
    required this.summary,
    required this.suggestions,
    required this.unavailableReason,
    this.tailoredToJob = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    Widget child;
    if (loading) {
      child = Row(
        children: [
          const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGoldDeep)),
          const SizedBox(width: 12),
          Expanded(child: Text('Writing your AI tips…', style: TextStyle(fontSize: 14, color: p.body))),
        ],
      );
    } else if (unavailableReason != null) {
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 18, color: p.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(unavailableReason!, style: TextStyle(fontSize: 13.5, height: 1.45, color: p.body))),
        ],
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 16, color: AppColors.accentGoldDeep),
              const SizedBox(width: 6),
              Text(tailoredToJob ? 'Tailored to the job you pasted' : 'Written by AI',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.body)),
            ],
          ),
          if (summary != null && summary!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(summary!, style: TextStyle(fontSize: 14, height: 1.5, color: p.title)),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < suggestions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: AppColors.accentGold.withValues(alpha: 0.18), shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accentGoldDeep)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(suggestions[i], style: TextStyle(fontSize: 13.5, height: 1.45, color: p.title)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      );
    }
    return _Card(child: child);
  }
}

class _KeywordMatch extends StatelessWidget {
  final KeywordMatchResult result;
  const _KeywordMatch({required this.result});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final ratio = result.total == 0 ? 0.0 : result.matched / result.total;
    final color = ratio >= 0.7
        ? AppColors.success
        : ratio >= 0.4
            ? AppColors.accentGoldDeep
            : AppColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${result.matched} of ${result.total} key terms covered',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: p.title)),
            ),
            Text('${(ratio * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: ratio, minHeight: 7, backgroundColor: p.background, color: color),
        ),
        if (result.missing.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Consider adding', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.body)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in result.missing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.fieldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 13, color: p.body),
                      const SizedBox(width: 4),
                      Text(k, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.title)),
                    ],
                  ),
                ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 10),
          Text('Great coverage. No obvious gaps found.', style: TextStyle(fontSize: 13, color: p.body)),
        ],
      ],
    );
  }
}
