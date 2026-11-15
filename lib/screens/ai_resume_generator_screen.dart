import 'package:flutter/material.dart';
import 'ai_guard.dart';
import '../widgets/auth/auth_kit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/app_feedback.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/profile_repository.dart';
import '../widgets/ai_tool_kit.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/template_thumbnail.dart';
import 'template_screen.dart' show resumeTemplateLabel;
import 'form_screen.dart';

const _uuid = Uuid();


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

  Future<void> _showError(String message) async {
    final retry = await showPromptSheet(
      context,
      tone: PromptTone.error,
      icon: LucideIcons.fileX,
      title: "Couldn't generate your resume",
      message: message,
      primaryLabel: 'Try again',
      secondaryLabel: 'Close',
    );
    if (retry == true && mounted) _onGenerate();
  }

  /// Photographs a job posting and fills the job-description field with a
  /// cleaned-up transcription of it — the photo is sent to the AI model
  /// directly (vision), which reads it and regenerates the job description
  /// text itself rather than passing through raw OCR output, so stray
  /// characters/UI chrome/noise a plain OCR pass would capture get left
  /// out. This is an AI call like any other here (network, daily quota),
  /// unlike the old fully on-device OCR path.
  Future<void> _onScanPressed() async {
    if (!await ensureAiAvailable(context)) return;
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
    if (photo == null || !mounted) return; // user cancelled

    showProgressOverlay(context, 'Reading job description from photo…');
    try {
      final bytes = await photo.readAsBytes();
      final text = await GroqService.extractJobDescriptionFromImage(bytes);
      await AiUsageTracker.recordUsage();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      final existing = _jobDescription.text.trim();
      _jobDescription.text = existing.isEmpty ? text : '$existing\n\n$text';
    } on AiServiceException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        showToast(context, e.message, tone: ToastTone.error);
      }
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        showToast(context, "Couldn't read that photo. Please try again.", tone: ToastTone.error);
      }
    }
  }

  Future<void> _onGenerate() async {
    final jd = _jobDescription.text.trim();
    if (jd.isEmpty) {
      showToast(context, 'Paste a job description first.', tone: ToastTone.info);
      return;
    }

    showProgressOverlay(context, 'Tailoring your resume to this job description…');
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
        child: ResponsiveContentBound(
          maxWidth: 720,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const AiToolHeader(
                icon: LucideIcons.sparkles,
                title: 'Tailor your resume to a job',
                subtitle: 'AI rewrites your summary, wording and skills for this role. Your employers, dates '
                    'and education stay exactly as you entered them.',
              ),
              const StepHeading(number: 1, title: 'The job'),
              JobDescriptionField(controller: _jobDescription, onScan: _onScanPressed),
              const SizedBox(height: 14),
              AuthField(
                dense: true,
                label: 'Job title (optional)',
                hint: 'Leave blank to use the title from the posting',
                controller: _jobTitleOverride,
                textCapitalization: TextCapitalization.words,
              ),
              StepHeading(number: 2, title: 'Pick a design', trailing: resumeTemplateLabel(_template)),
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: ResumeTemplate.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final t = ResumeTemplate.values[i];
                    final selected = t == _template;
                    return Semantics(
                      selected: selected,
                      button: true,
                      label: '${resumeTemplateLabel(t)} template',
                      child: GestureDetector(
                        onTap: () => setState(() => _template = t),
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 100,
                                height: 141,
                                padding: EdgeInsets.all(selected ? 3 : 0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? p.focus : p.fieldBorder,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(selected ? 8 : 11),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      TemplateThumbnail(kind: DocumentKind.resume, template: t),
                                      if (selected)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(color: p.focus, shape: BoxShape.circle),
                                            child: Icon(LucideIcons.check, size: 14, color: p.onPrimary),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                resumeTemplateLabel(t),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? p.title : p.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AiActionBar(label: 'Tailor my resume', icon: LucideIcons.sparkles, onPressed: _onGenerate),
    );
  }
}
