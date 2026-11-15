import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/ai_tool_kit.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/responsive_scaffold.dart';
import 'ai_guard.dart';
import '../widgets/app_feedback.dart';
import 'package:image_picker/image_picker.dart';
import '../models/interview_question.dart';
import '../models/resume_data.dart';
import '../services/ai_usage_tracker.dart';
import '../services/groq_service.dart';
import '../theme/app_theme.dart';



/// Paste a job description and generate likely interview questions grounded
/// in [resumeData], AI-powered. Same job-description entry UX (paste +
/// camera scan) as AiResumeGeneratorScreen, intentionally — the two screens
/// are opened from different places but ask the user for the same input.
class InterviewPrepScreen extends StatefulWidget {
  final ResumeData resumeData;
  const InterviewPrepScreen({super.key, required this.resumeData});

  @override
  State<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends State<InterviewPrepScreen> {
  final _jobDescription = TextEditingController();
  final _jobTitle = TextEditingController();
  bool _loading = false;
  bool _scanning = false;
  List<InterviewQuestion>? _questions;

  @override
  void dispose() {
    _jobDescription.dispose();
    _jobTitle.dispose();
    super.dispose();
  }

  /// Sends the photo to the AI model directly (vision), which reads it and
  /// regenerates clean job description text rather than passing through
  /// raw OCR output — see GroqService.extractJobDescriptionFromImage.
  Future<void> _onScanPressed() async {
    if (!GroqService.isConfigured) {
      showAiUnavailableSheet(context);
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) showAiLimitSheet(context);
      return;
    }
    if (!mounted) return;

    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    } catch (_) {
      if (mounted) {
        showToast(context, "Couldn't open the camera. Check camera permission in Settings.", tone: ToastTone.error);
      }
      return;
    }
    if (photo == null) return;

    setState(() => _scanning = true);
    try {
      final bytes = await photo.readAsBytes();
      final text = await GroqService.extractJobDescriptionFromImage(bytes);
      await AiUsageTracker.recordUsage();
      final existing = _jobDescription.text.trim();
      _jobDescription.text = existing.isEmpty ? text : '$existing\n\n$text';
    } on AiServiceException catch (e) {
      if (mounted) {
        showToast(context, e.message, tone: ToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, "Couldn't read that photo. Please try again.", tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _onGenerate() async {
    final jd = _jobDescription.text.trim();
    if (jd.isEmpty) {
      showToast(context, 'Paste a job description first.', tone: ToastTone.info);
      return;
    }
    if (!GroqService.isConfigured) {
      showAiUnavailableSheet(context);
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) showAiLimitSheet(context);
      return;
    }
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final questions = await GroqService.generateInterviewQuestions(
        resume: widget.resumeData,
        jobDescription: jd,
        jobTitle: _jobTitle.text.trim().isEmpty ? null : _jobTitle.text.trim(),
      );
      await AiUsageTracker.recordUsage();
      if (!mounted) return;
      setState(() => _questions = questions);
    } on AiServiceException catch (e) {
      if (mounted) {
        showToast(context, e.message, tone: ToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Something went wrong. Please try again.', tone: ToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final questions = _questions;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
            tooltip: 'Back', icon: const Icon(LucideIcons.arrowLeft), onPressed: () => Navigator.maybePop(context)),
        title: questions == null ? null : const Text('Interview prep'),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContentBound(
          maxWidth: 720,
          child: questions != null ? _buildResults(questions) : _buildForm(),
        ),
      ),
      bottomNavigationBar: questions != null
          ? null
          : AiActionBar(
              label: _loading ? 'Writing questions…' : 'Get my questions',
              icon: LucideIcons.sparkles,
              loading: _loading,
              onPressed: _onGenerate,
            ),
    );
  }

  Widget _buildForm() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const AiToolHeader(
          icon: LucideIcons.messageSquareText,
          title: 'Prepare for your interview',
          subtitle: 'Get the questions you are likely to be asked for this role, with tips on how to answer, '
              'based on your resume.',
        ),
        const StepHeading(number: 1, title: 'The job'),
        JobDescriptionField(controller: _jobDescription, onScan: _onScanPressed, scanning: _scanning),
        const SizedBox(height: 14),
        AuthField(
          dense: true,
          label: 'Job title (optional)',
          hint: 'e.g. Product Designer',
          controller: _jobTitle,
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _buildResults(List<InterviewQuestion> questions) {
    final p = AuthPalette.of(context);
    final byCategory = <String, List<InterviewQuestion>>{};
    for (final q in questions) {
      byCategory.putIfAbsent(q.category, () => []).add(q);
    }
    var number = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(
          '${questions.length} questions to practice',
          style: TextStyle(
              fontFamily: 'Fraunces', fontSize: 26, height: 1.15, fontWeight: FontWeight.w600, color: p.title),
        ),
        const SizedBox(height: 6),
        Text('Tap a question to see how to answer it.', style: TextStyle(fontSize: 14.5, color: p.body)),
        for (final entry in byCategory.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: entry.key),
                TextSpan(
                  text: '  ${entry.value.length}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.muted),
                ),
              ]),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.title),
            ),
          ),
          for (final q in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuestionCard(question: q, number: ++number),
            ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _questions = null),
            icon: const Icon(LucideIcons.rotateCcw, size: 18),
            label: const Text('Try a different job'),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.title,
              backgroundColor: p.surface,
              side: BorderSide(color: p.fieldBorder, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final InterviewQuestion question;
  final int number;
  const _QuestionCard({required this.question, required this.number});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final tip = widget.question.answerTip;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tip.isEmpty ? null : () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _open ? p.focus : p.fieldBorder, width: _open ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(8)),
                    child: Text('${widget.number}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.title)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.question.question,
                        style: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: p.title)),
                  ),
                  if (tip.isNotEmpty)
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(LucideIcons.chevronDown, size: 20, color: p.muted),
                    ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(38, 12, 4, 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.lightbulb, size: 16, color: AppColors.accentGoldDeep),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(tip, style: TextStyle(fontSize: 13.5, height: 1.5, color: p.title)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
