import 'package:flutter/material.dart';
import '../../models/resume_data.dart';
import '../../services/ai_usage_tracker.dart';
import '../../services/groq_service.dart';
import '../../services/resume_pdf_importer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_sweep.dart';
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
    if (!_choiceMade) {
      return OnboardingChoiceScreen(
        onManual: () => setState(() => _choiceMade = true),
        onImported: (data) => setState(() {
          _importedData = data;
          _choiceMade = true;
        }),
      );
    }
    return ProfileScreen(onboarding: true, initialData: _importedData);
  }
}

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
  bool _working = false;
  String _workingMessage = 'Working...';

  Future<void> _onUploadPressed() async {
    if (!GroqService.isConfigured) {
      await _showInfoDialog(
        title: 'AI features not set up',
        message: "AI features aren't set up on this build. You can still fill your profile in manually.",
      );
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      final fallback = await _showConfirmDialog(
        title: 'Daily AI limit reached',
        message: "You've used today's free AI generations. Fill your profile in manually for "
            'now, or come back tomorrow to upload with AI.',
        confirmLabel: 'Fill Manually',
      );
      if (fallback == true) widget.onManual();
      return;
    }

    setState(() {
      _working = true;
      _workingMessage = 'Reading your resume...';
    });
    try {
      final text = await ResumePdfImporter.pickAndExtractText();
      if (text == null) return; // user cancelled the file picker
      if (mounted) setState(() => _workingMessage = 'AI is filling in your profile...');
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
    final fallback = await _showConfirmDialog(
      title: "Couldn't import that resume",
      message: message,
      confirmLabel: 'Fill Manually',
    );
    if (fallback == true) widget.onManual();
  }

  Future<void> _showInfoDialog({required String title, required String message}) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _working
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: _WorkingView(message: _workingMessage),
              )
            : SingleChildScrollView(child: _ChoiceView(this)),
      ),
    );
  }
}

class _ChoiceView extends StatelessWidget {
  final _OnboardingChoiceScreenState state;
  const _ChoiceView(this.state);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeroHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrimaryChoiceCard(
                icon: Icons.document_scanner_rounded,
                title: 'Upload my resume',
                subtitle: "We'll read it and fill in your details for you.",
                badge: 'AI-Powered',
                onTap: state._onUploadPressed,
              ),
              const SizedBox(height: 14),
              _SecondaryChoiceCard(
                icon: Icons.edit_note_rounded,
                title: 'Start from scratch',
                subtitle: 'Fill in your details manually.',
                onTap: state.widget.onManual,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dark "ink" hero, matching the Paywall/Settings plan-card language, so the
/// very first screen after signup already reads as the app's real design
/// system instead of a plain white form.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      period: const Duration(milliseconds: 5200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.ink, AppColors.slate900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: -40, right: -30, child: GlowBlob(color: AppColors.primary, size: 150)),
            const Positioned(
                bottom: -60, left: -30, child: GlowBlob(color: AppColors.accentGold, size: 130, opacity: 0.28)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FloatBob(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.ink, size: 24),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Let's set up your profile",
                  style: TextStyle(
                      fontFamily: 'Fraunces', color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Powers every resume, cover letter, and proposal you create.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The recommended path — styled as a gold-accented CTA rather than a plain
/// list row, so it visually leads and its icon actually communicates
/// "scan a document" instead of a generic upload glyph.
class _PrimaryChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _PrimaryChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep]),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.ink),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: AppColors.ink, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: AppColors.slate600, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The manual fallback — deliberately quieter than the primary card (flat
/// bordered row, no accent color, no icon fill) so it doesn't compete for
/// attention.
class _SecondaryChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SecondaryChoiceCard({
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
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.slate600),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColors.slate600, fontSize: 13)),
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

class _WorkingView extends StatelessWidget {
  final String message;
  const _WorkingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(message, style: const TextStyle(color: AppColors.slate600, fontSize: 14)),
        ],
      ),
    );
  }
}

