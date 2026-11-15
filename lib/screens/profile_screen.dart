import 'package:flutter/material.dart';
import '../widgets/app_feedback.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/resume_data.dart';
import '../services/account_repository.dart';
import '../services/profile_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_kit.dart';
import 'resume_sections.dart';

/// Local profile form: name, title, contact info, experience, education,
/// and skills, saved under a single SharedPreferences key via
/// [ProfileRepository]. This is the source of truth the AI resume-tailoring
/// feature reads from — there's no server involved, it's stored on this
/// device exactly like every other document in the app.
///
/// Doubles as the app's mandatory onboarding step when [onboarding] is true
/// (step 2 of 2, right after the import/manual choice): "Finish setup"
/// instead of "Save profile". Completing it only flips
/// [AccountSession.onboardingComplete] rather than navigating directly —
/// `AuthGate` is what's watching that and swaps itself to `AppShell` in
/// place, consistent with how the rest of the auth flow avoids Navigator.
class ProfileScreen extends StatefulWidget {
  final bool onboarding;

  /// Pre-fills the form with already-extracted data (e.g. from the
  /// "upload my resume" onboarding path) instead of loading the saved
  /// profile — the user still reviews/edits every field before it's
  /// actually saved via the normal Continue/Save flow below.
  final ResumeData? initialData;

  /// Onboarding only: returns to step 1 (the import/manual choice).
  final VoidCallback? onOnboardingBack;

  const ProfileScreen({super.key, this.onboarding = false, this.initialData, this.onOnboardingBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ResumeData? _data;
  final _scroll = ScrollController();
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.initialData != null) {
      if (mounted) setState(() => _data = widget.initialData);
      return;
    }
    final loaded = await ProfileRepository.load();
    if (mounted) setState(() => _data = loaded ?? ResumeData());
  }

  Future<void> _save() async {
    final data = _data;
    if (data == null) return;
    await ProfileRepository.save(data);
  }

  Future<void> _onBack() async {
    await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onSavePressed() async {
    setState(() => _saving = true);
    await _save();
    if (!mounted) return;
    setState(() => _saving = false);
    showToast(context, 'Profile saved', tone: ToastTone.success);
  }

  Future<void> _onFinishPressed() async {
    final data = _data;
    if (data == null) return;
    if (data.personalInfo.fullName.trim().isEmpty) {
      setState(() => _nameError = 'Add your name to continue.');
      _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      return;
    }
    setState(() => _saving = true);
    await _save();
    await AccountRepository.markOnboardingComplete();
    AccountSession.onboardingComplete.value = true;
  }

  /// Field edits write straight into [_data]; this just refreshes the
  /// section status pills.
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final data = _data;
    final onboarding = widget.onboarding;

    Widget body;
    if (data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final info = data.personalInfo;
      final basicsFilled = filledBasics(info);

      body = ListView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (onboarding) ...[
            const SizedBox(height: 8),
            const StepIndicator(current: 2, total: 2, label: 'Your profile'),
            const SizedBox(height: 28),
            Text(
              widget.initialData != null ? 'Check your details' : 'Tell us about yourself',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                height: 1.15,
                letterSpacing: -0.3,
                fontWeight: FontWeight.w600,
                color: p.title,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only your name is required. Everything else can be added later.',
              style: TextStyle(fontSize: 14.5, height: 1.45, color: p.body),
            ),
            const SizedBox(height: 20),
          ],
          _NoticeBanner(imported: widget.initialData != null),
          const SizedBox(height: 16),
          ResumeSectionCard(
            icon: LucideIcons.idCard,
            title: 'Personal details',
            subtitle: 'Name, title, contact',
            status: basicsFilled == 5 ? 'Complete' : '$basicsFilled of 5',
            done: basicsFilled == 5,
            initiallyExpanded: true,
            child: PersonalDetailsFields(
              data: data,
              nameError: _nameError,
              onChanged: () {
                if (_nameError != null && info.fullName.trim().isNotEmpty) _nameError = null;
                _refresh();
              },
            ),
          ),
          ResumeSectionCard(
            icon: LucideIcons.alignLeft,
            title: 'Summary',
            subtitle: 'Your short intro',
            status: info.summary.trim().isEmpty ? 'Optional' : 'Added',
            done: info.summary.trim().isNotEmpty,
            child: SummaryEditor(data: data, onChanged: _refresh),
          ),
          ResumeSectionCard(
            icon: LucideIcons.briefcase,
            title: 'Work experience',
            subtitle: 'Most recent first',
            status: countLabel(data.experience.length, 'role'),
            done: data.experience.isNotEmpty,
            child: ExperienceEditor(data: data, onChanged: _refresh),
          ),
          ResumeSectionCard(
            icon: LucideIcons.graduationCap,
            title: 'Education',
            subtitle: 'Degrees and courses',
            status: countLabel(data.education.length, 'entry', plural: 'entries'),
            done: data.education.isNotEmpty,
            child: EducationEditor(data: data, onChanged: _refresh),
          ),
          ResumeSectionCard(
            icon: LucideIcons.zap,
            title: 'Skills',
            subtitle: 'Tools and strengths',
            status: countLabel(data.skills.length, 'skill'),
            done: data.skills.length >= 3,
            child: SkillsEditor(data: data, onChanged: _refresh),
          ),
        ],
      );
    }

    Widget scaffold = Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        automaticallyImplyLeading: false,
        leading: onboarding
            ? (widget.onOnboardingBack == null
                ? null
                : IconButton(
                    tooltip: 'Back',
                    icon: const Icon(LucideIcons.arrowLeft),
                    onPressed: widget.onOnboardingBack,
                  ))
            : IconButton(tooltip: 'Back', icon: const Icon(LucideIcons.arrowLeft), onPressed: _onBack),
        title: onboarding ? null : const Text('My profile'),
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: data == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: p.background,
                  border: Border(top: BorderSide(color: p.fieldBorder)),
                ),
                child: AuthPrimaryButton(
                  label: onboarding ? 'Finish setup' : 'Save profile',
                  trailingIcon: onboarding ? LucideIcons.arrowRight : null,
                  loading: _saving,
                  onPressed: onboarding ? _onFinishPressed : _onSavePressed,
                ),
              ),
            ),
    );

    // System back: onboarding returns to step 1; otherwise save and leave,
    // same as the app-bar back button.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (onboarding) {
          widget.onOnboardingBack?.call();
        } else {
          _onBack();
        }
      },
      child: scaffold,
    );
  }
}

// ---------------------------------------------------------------------------
// Layout pieces
// ---------------------------------------------------------------------------

class _NoticeBanner extends StatelessWidget {
  final bool imported;
  const _NoticeBanner({required this.imported});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final color = imported ? AppColors.accentGoldDeep : p.body;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: imported ? AppColors.accentGold.withValues(alpha: 0.12) : p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: imported ? AppColors.accentGold.withValues(alpha: 0.45) : p.fieldBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(imported ? LucideIcons.sparkles : LucideIcons.lock, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              imported
                  ? 'Filled in by AI from your resume. Give each section a quick check, since automatic '
                      "extraction isn't perfect."
                  : 'Saved only on this device. It is sent to AI only when you ask it to tailor a resume.',
              style: TextStyle(fontSize: 13, height: 1.45, color: imported ? p.title : p.body),
            ),
          ),
        ],
      ),
    );
  }
}
