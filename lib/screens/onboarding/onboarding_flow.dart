import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/resume_data.dart';
import '../../services/account_repository.dart';
import '../../services/ai_usage_tracker.dart';
import '../../services/groq_service.dart';
import '../../services/resume_pdf_importer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_kit.dart';
import '../../widgets/shimmer_sweep.dart' show FloatBob;
import '../profile_screen.dart';

/// Shown once, right after signup, before the mandatory profile step. Owns
/// the choice-screen <-> profile-review transition as a plain local-state
/// swap rather than a Navigator push — mirroring how `AuthGate` itself
/// swaps Login/Signup/Onboarding/AppShell in place. That matters here for
/// the same reason it does in AuthGate: pushing ProfileScreen on top of
/// this screen would leave it (and AuthGate above it) alive but hidden
/// once onboarding completes, instead of being replaced by AppShell.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  bool _choiceMade = false;
  ResumeData? _importedData;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: !_choiceMade
          ? OnboardingChoiceScreen(
              key: const ValueKey('choice'),
              onManual: () => setState(() => _choiceMade = true),
              onImported: (data) => setState(() {
                _importedData = data;
                _choiceMade = true;
              }),
            )
          : ProfileScreen(
              key: const ValueKey('profile'),
              onboarding: true,
              initialData: _importedData,
              onOnboardingBack: () => setState(() {
                _choiceMade = false;
                _importedData = null;
              }),
            ),
    );
  }
}

enum _SetupPath { import, manual }

/// Lets a new user either upload an existing resume (AI-extracted into
/// [ResumeData], then handed to ProfileScreen for review/edit before
/// saving) or skip straight to filling their profile in manually.
class OnboardingChoiceScreen extends StatefulWidget {
  final VoidCallback onManual;
  final ValueChanged<ResumeData> onImported;
  const OnboardingChoiceScreen({super.key, required this.onManual, required this.onImported});

  @override
  State<OnboardingChoiceScreen> createState() => _OnboardingChoiceScreenState();
}

class _OnboardingChoiceScreenState extends State<OnboardingChoiceScreen> {
  _SetupPath _path = _SetupPath.import;
  bool _working = false;

  /// 0 = reading the PDF, 1 = AI extracting the profile.
  int _workingStep = 0;

  String get _firstName {
    String full;
    try {
      full = AccountRepository.currentAccount()?['fullName']?.trim() ?? '';
    } catch (_) {
      full = ''; // Firebase not initialised (e.g. preview rendering) -> no greeting
    }
    return full.isEmpty ? '' : full.split(RegExp(r'\s+')).first;
  }

  void _onContinue() {
    if (_path == _SetupPath.manual) {
      widget.onManual();
    } else {
      _onUploadPressed();
    }
  }

  Future<void> _onUploadPressed() async {
    if (!GroqService.isConfigured) {
      final manual = await showPromptSheet(
        context,
        icon: LucideIcons.cloudOff,
        title: "AI import isn't available",
        message: "This version of the app can't use AI right now. You can still set up your "
            'profile by hand. It only takes a few minutes.',
        primaryLabel: 'Fill in manually',
        secondaryLabel: 'Not now',
      );
      if (manual == true) widget.onManual();
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (!mounted) return;
      final manual = await showPromptSheet(
        context,
        icon: LucideIcons.hourglass,
        title: "You've reached today's AI limit",
        message: 'Free AI imports reset every day. Fill in your profile by hand now, or come back tomorrow.',
        primaryLabel: 'Fill in manually',
        secondaryLabel: 'Maybe later',
      );
      if (manual == true) widget.onManual();
      return;
    }

    try {
      // The progress view appears only once a file is chosen, never behind
      // the system file picker.
      final text = await ResumePdfImporter.pickAndExtractText(
        onPicked: () {
          if (mounted) {
            setState(() {
              _working = true;
              _workingStep = 0;
            });
          }
        },
      );
      if (text == null) return; // user cancelled the file picker
      if (mounted) setState(() => _workingStep = 1);
      final extracted = await GroqService.extractProfileFromResumeText(text);
      await AiUsageTracker.recordUsage();
      if (!mounted) return;
      widget.onImported(extracted);
    } on ResumeImportException catch (e) {
      if (mounted) await _offerManualFallback(e.message);
    } on AiServiceException catch (e) {
      if (mounted) await _offerManualFallback(e.message);
    } catch (_) {
      if (mounted) await _offerManualFallback("Something went wrong reading that resume.");
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _offerManualFallback(String message) async {
    final manual = await showPromptSheet(
      context,
      tone: PromptTone.error,
      icon: LucideIcons.fileText,
      title: "We couldn't read that resume",
      message: message,
      primaryLabel: 'Fill in manually',
      secondaryLabel: 'Try another file',
    );
    if (manual == true) {
      widget.onManual();
    } else if (manual == false) {
      _onUploadPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return PopScope(
      // Nothing to go back to from here, and backing out mid-import would
      // strand the request.
      canPop: false,
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _working
                    ? ImportProgressView(key: const ValueKey('working'), step: _workingStep)
                    : _buildChoice(p),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoice(AuthPalette p) {
    final name = _firstName;
    return Column(
      key: const ValueKey('choice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StepIndicator(current: 1, total: 2, label: 'Choose how to start'),
                  const SizedBox(height: 36),
                  if (name.isNotEmpty) ...[
                    Text(
                      'Welcome, $name',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGoldDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'How would you like to start?',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 30,
                      height: 1.15,
                      letterSpacing: -0.3,
                      fontWeight: FontWeight.w600,
                      color: p.title,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your profile fills in every resume, cover letter and proposal you create. '
                    'You can change it anytime.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: p.body),
                  ),
                  const SizedBox(height: 28),
                  _OptionCard(
                    selected: _path == _SetupPath.import,
                    icon: LucideIcons.fileUp,
                    title: 'Import my existing resume',
                    subtitle: 'Upload a PDF and AI fills in your details. You review everything before saving.',
                    badge: 'Fastest',
                    onTap: () => setState(() => _path = _SetupPath.import),
                  ),
                  const SizedBox(height: 12),
                  _OptionCard(
                    selected: _path == _SetupPath.manual,
                    icon: LucideIcons.squarePen,
                    title: 'Start from scratch',
                    subtitle: 'Enter your details yourself, section by section.',
                    onTap: () => setState(() => _path = _SetupPath.manual),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              AuthPrimaryButton(
                label: _path == _SetupPath.import ? 'Choose a PDF' : 'Continue',
                trailingIcon:
                    _path == _SetupPath.import ? LucideIcons.upload : LucideIcons.arrowRight,
                onPressed: _onContinue,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.shieldCheck, size: 15, color: p.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Stored only on this device.',
                      style: TextStyle(fontSize: 12.5, color: p.body),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Radio-style selectable card. Selected state is carried by border, a
/// filled check and a tinted icon tile, not just color, so it reads at a
/// glance.
class _OptionCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? p.focus : p.fieldBorder, width: selected ? 1.8 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.08 : 0.03),
                  blurRadius: selected ? 20 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: selected
                        ? const LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep])
                        : null,
                    color: selected ? null : p.background,
                  ),
                  child: Icon(icon, size: 22, color: selected ? AppColors.ink : p.body),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.title),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accentGold.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.sparkles, size: 11, color: AppColors.accentGoldDeep),
                                  SizedBox(width: 3),
                                  Text(
                                    'AI',
                                    style: TextStyle(
                                        fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accentGoldDeep),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(subtitle, style: TextStyle(fontSize: 13.5, height: 1.4, color: p.body)),
                      if (badge != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$badge · about 1 minute',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _RadioDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? p.focus : Colors.transparent,
        border: Border.all(color: selected ? p.focus : p.fieldBorder, width: 1.6),
      ),
      child: selected ? Icon(LucideIcons.check, size: 14, color: p.onPrimary) : null,
    );
  }
}

/// Shown after a resume PDF is chosen, while it's read and turned into a
/// profile: a calm centered mark and a step card, so the wait reads as
/// progress rather than a spinner.
class ImportProgressView extends StatelessWidget {
  final int step;
  const ImportProgressView({super.key, required this.step});

  static const _steps = [
    ('Reading your resume', 'Pulling the text out of your PDF'),
    ('Filling in your profile', 'AI sorts it into experience, education and skills'),
    ('Ready to review', "You check everything before it's saved"),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentGold.withValues(alpha: 0.10),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentGold.withValues(alpha: 0.16),
                      ),
                    ),
                    FloatBob(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.accentGold, AppColors.accentGoldDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: AppColors.accentGold.withValues(alpha: 0.35), blurRadius: 24),
                          ],
                        ),
                        child: const Icon(LucideIcons.fileScan, color: AppColors.ink, size: 30),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Building your profile',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Fraunces', fontSize: 28, fontWeight: FontWeight.w600, color: p.title),
            ),
            const SizedBox(height: 8),
            Text(
              'This usually takes a few seconds. Please keep the app open.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.45, color: p.body),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.fieldBorder),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _steps.length; i++) _stepRow(p, i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(AuthPalette p, int i) {
    final done = i < step;
    final active = i == step;
    final (title, detail) = _steps[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: done
                ? const Icon(LucideIcons.circleCheck, size: 24, color: AppColors.success)
                : active
                    ? Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: p.focus),
                      )
                    : Icon(LucideIcons.circle, size: 24, color: p.fieldBorder),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: done || active ? p.title : p.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(fontSize: 13, height: 1.35, color: p.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
