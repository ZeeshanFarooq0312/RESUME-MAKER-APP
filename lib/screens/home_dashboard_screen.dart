import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../models/template_kind.dart';
import '../services/account_repository.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/profile_repository.dart';
import '../services/resume_pdf_importer.dart';
import '../services/resume_profile_prefill.dart';
import '../services/theme_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_sweep.dart';
import '../widgets/template_card.dart';
import 'ai_resume_generator_screen.dart';
import 'cover_letter_form_screen.dart';
import 'form_screen.dart';
import 'paywall_screen.dart';
import 'preview_screen.dart';
import 'profile_screen.dart';
import 'proposal_form_screen.dart';

const _uuid = Uuid();

const _recommendedTemplates = <ResumeTemplate>[
  ResumeTemplate.classic,
  ResumeTemplate.modern,
  ResumeTemplate.professional,
  ResumeTemplate.creative,
];

const _recommendedTemplateLabels = {
  ResumeTemplate.classic: 'Classic',
  ResumeTemplate.modern: 'Modern',
  ResumeTemplate.professional: 'Professional',
  ResumeTemplate.creative: 'Creative',
};

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<DocumentEntry>? _entries;
  bool _importing = false;
  late final _account = AccountRepository.currentAccount();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DocumentsRepository.migrateLegacyIfNeeded();
    final entries = await DocumentsRepository.loadAll();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _openNew(DocumentKind kind) async {
    Widget screen;
    switch (kind) {
      case DocumentKind.resume:
        final starting = await promptResumeStartingData(context);
        if (!mounted) return;
        screen = FormScreen(initialData: starting);
        break;
      case DocumentKind.coverLetter:
        screen = const CoverLetterFormScreen();
        break;
      case DocumentKind.proposal:
        screen = const ProposalFormScreen();
        break;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _openTemplatePreview(ResumeTemplate template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          resumeData: sampleResumeData(),
          template: template,
          isSample: true,
          onUseTemplate: () => _useRecommendedTemplate(template),
        ),
      ),
    );
    _load();
  }

  Future<void> _useRecommendedTemplate(ResumeTemplate template) async {
    final starting = await promptResumeStartingData(context);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FormScreen(initialTemplate: template, initialData: starting),
      ),
    );
  }

  Future<void> _openExisting(DocumentEntry entry) async {
    Widget screen;
    switch (entry.kind) {
      case DocumentKind.resume:
        screen = FormScreen(entry: entry);
        break;
      case DocumentKind.coverLetter:
        screen = CoverLetterFormScreen(entry: entry);
        break;
      case DocumentKind.proposal:
        screen = ProposalFormScreen(entry: entry);
        break;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _uploadResume() async {
    setState(() => _importing = true);
    try {
      final imported = await ResumePdfImporter.pickAndImport();
      if (!mounted || imported == null) return;
      final proceed = await _showImportSummary(imported);
      if (proceed != true || !mounted) return;

      final now = DateTime.now();
      final entry = DocumentEntry(
        id: _uuid.v4(),
        kind: DocumentKind.resume,
        title: imported.personalInfo.fullName.isEmpty ? 'My Resume' : imported.personalInfo.fullName,
        templateId: 'classic',
        updatedAt: now,
        completionPercent: imported.completionPercent,
        payload: imported.toJson(),
      );
      await DocumentsRepository.save(entry);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FormScreen(entry: entry)),
      );
      _load();
    } on ResumeImportException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError("Something went wrong while reading that PDF.");
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool?> _showImportSummary(ResumeData data) {
    final expCount = data.experience.length;
    final eduCount = data.education.length;
    final skillCount = data.skills.length;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resume imported'),
        content: Text(
          "We found: ${data.personalInfo.fullName.isEmpty ? 'name not detected' : data.personalInfo.fullName} · "
          "$expCount work ${expCount == 1 ? 'entry' : 'entries'} · "
          "$eduCount education ${eduCount == 1 ? 'entry' : 'entries'} · "
          "$skillCount skill${skillCount == 1 ? '' : 's'}.\n\n"
          "Automatic parsing isn't perfect — please review and correct each field.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Review & Edit'),
          ),
        ],
      ),
    );
  }

  /// Shared guard for every AI-resume-generation entry point: confirms a
  /// Groq key is configured and a Profile exists (offering to set one up if
  /// not) before letting the caller navigate to its own generator screen.
  /// Returns true only if both checks passed and the caller should proceed.
  Future<bool> _checkAiGuards() async {
    if (!GroqService.isConfigured) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('AI features not set up'),
          content: const Text(
              "AI features aren't set up on this build. Ask the developer to configure a Groq API key."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return false;
    }
    // Pro gate first — so a free user is invited to upgrade immediately
    // instead of being sent to build a whole profile only to be blocked.
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) await _showAiLimitReachedDialog();
      return false;
    }
    if (!mounted) return false;
    final hasProfile = await ProfileRepository.exists();
    if (!mounted) return false;
    if (!hasProfile) {
      final setUp = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Set up your profile first'),
          content: const Text(
              'AI resume generation uses your saved profile (work history, education, skills) as '
              'the source of truth. Add it once and reuse it for every AI-generated resume.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Set Up Profile'),
            ),
          ],
        ),
      );
      if (setUp == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }
      return false;
    }
    return true;
  }

  Future<void> _showAiLimitReachedDialog() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Daily AI limit reached'),
        content: const Text(
            "You've used today's free AI generations. Upgrade to Pro for unlimited AI-powered "
            'summaries, rewrites, cover letters, and resume generation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  Future<void> _onGenerateFromJobDescription() async {
    if (!await _checkAiGuards()) return;
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AiResumeGeneratorScreen()));
    _load();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import failed'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(DocumentEntry entry) async {
    await DocumentsRepository.toggleFavorite(entry.id);
    _load();
  }

  Future<void> _delete(DocumentEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this document?'),
        content: Text('"${entry.title}" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DocumentsRepository.delete(entry.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      body: SafeArea(
        child: entries == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RESUME BUILDER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _account?['fullName']?.isNotEmpty == true
                                    ? 'Hi, ${_account!['fullName']}'
                                    : 'Welcome back',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const _ThemeModeButton(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.ink, AppColors.slate900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.offline_bolt_outlined, color: AppColors.accentGold, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Everything you build stays on this device by default — AI features are optional and need internet.',
                              style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.badge_outlined,
                            label: 'New Resume',
                            onTap: () => _openNew(DocumentKind.resume),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.mail_outline,
                            label: 'Cover Letter',
                            onTap: () => _openNew(DocumentKind.coverLetter),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.handshake_outlined,
                            label: 'Proposal',
                            onTap: () => _openNew(DocumentKind.proposal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _importing ? null : _uploadResume,
                        icon: _importing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file, size: 18),
                        label: Text(_importing ? 'Reading PDF…' : 'Upload Existing Resume (PDF)'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AiGenerateButton(onTap: _onGenerateFromJobDescription),
                    const SizedBox(height: 28),
                    Text('Recommended Templates', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 188,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recommendedTemplates.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final template = _recommendedTemplates[i];
                          return SizedBox(
                            width: 130,
                            child: TemplateCard(
                              kind: DocumentKind.resume,
                              template: template,
                              title: _recommendedTemplateLabels[template]!,
                              badgeText: template.isPremium ? 'PRO' : null,
                              badgeBackgroundColor: AppColors.primaryLight.withValues(alpha: 0.7),
                              badgeTextColor: AppColors.slate900,
                              onTap: () => _openTemplatePreview(template),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('My Documents', style: Theme.of(context).textTheme.titleLarge),
                        if (entries.isNotEmpty)
                          Text(
                            '${entries.length}',
                            style: const TextStyle(
                                color: AppColors.slate400, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: EmptyState(
                          icon: Icons.description_outlined,
                          title: 'No documents yet',
                          message: 'Create a resume, cover letter, or proposal above to get started.',
                        ),
                      )
                    else
                      ...entries.map((e) => DocumentCard(
                            entry: e,
                            onTap: () => _openExisting(e),
                            onToggleFavorite: () => _toggleFavorite(e),
                            onDelete: () => _delete(e),
                          )),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Opens a picker for Light/Dark/System, reflecting the current choice via
/// [ThemeSession.mode] — the one global control for the app-wide theme,
/// reachable from the Home header rather than buried in Settings.
class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton();

  static const _icons = {
    ThemeMode.light: Icons.light_mode_rounded,
    ThemeMode.dark: Icons.dark_mode_rounded,
    ThemeMode.system: Icons.brightness_auto_rounded,
  };

  static const _labels = {
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
    ThemeMode.system: 'System default',
  };

  Future<void> _openPicker(BuildContext context, ThemeMode current) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Appearance', style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                leading: Icon(
                  _icons[mode],
                  color: mode == current ? AppColors.primary : AppColors.slate400,
                ),
                title: Text(_labels[mode]!),
                trailing: mode == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  ThemeRepository.setMode(mode);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeSession.mode,
      builder: (context, mode, _) {
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openPicker(context, mode),
          child: Container(
            width: 44,
            height: 44,
            decoration: AppDecorations.card(radius: 22),
            child: Icon(_icons[mode], color: AppColors.primary, size: 20),
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width, gradient-branded entry point into the AI resume-tailoring
/// flow. Deliberately styled differently from every other button on this
/// screen (which are all white/outlined) so the AI feature reads as its
/// own distinct thing rather than one more document-type action.
class _AiGenerateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AiGenerateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ShimmerSweep(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.ink, AppColors.slate900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep]),
                    borderRadius: BorderRadius.all(Radius.circular(11)),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.ink, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Resume with AI',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Paste a job description, get a resume tailored to it',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppColors.accentGold, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
