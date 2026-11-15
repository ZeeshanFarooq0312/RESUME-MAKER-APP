import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import '../theme/app_theme.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/document_card.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/template_showcase.dart';
import 'ai_guard.dart';
import 'ai_resume_generator_screen.dart';
import 'ats_score_screen.dart';
import 'cover_letter_form_screen.dart';
import 'document_actions.dart';
import 'documents_screen.dart';
import 'form_screen.dart';
import 'preview_screen.dart';
import 'profile_screen.dart';
import 'proposal_form_screen.dart';

const _uuid = Uuid();

/// How many documents show under "Recent" before "See all".
const _recentLimit = 4;

class HomeDashboardScreen extends StatefulWidget {
  /// Switches the app shell to the Templates tab.
  final VoidCallback? onOpenTemplates;
  const HomeDashboardScreen({super.key, this.onOpenTemplates});

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
    DocumentsRepository.revision.addListener(_load);
  }

  @override
  void dispose() {
    DocumentsRepository.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await DocumentsRepository.migrateLegacyIfNeeded();
    final entries = await DocumentsRepository.loadAll();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (mounted) setState(() => _entries = entries);
  }

  String get _firstName {
    final full = _account?['fullName']?.trim() ?? '';
    return full.isEmpty ? '' : full.split(RegExp(r'\s+')).first;
  }

  String get _initial {
    final n = _firstName;
    if (n.isNotEmpty) return n[0].toUpperCase();
    final e = _account?['email'] ?? '';
    return e.isNotEmpty ? e[0].toUpperCase() : '';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';
    return _firstName.isEmpty ? part : '$part, $_firstName';
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// One "Import PDF" entry point that lets the user pick quick (offline,
  /// rule-based) or smart (AI) parsing, replacing the two separate buttons.
  Future<void> _onImportPressed() async {
    final useAi = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (context) => const _ImportChoiceSheet(),
    );
    if (useAi == null || !mounted) return;
    if (useAi) {
      await _importWithAi();
    } else {
      await _importQuick();
    }
  }

  Future<void> _importQuick() async {
    setState(() => _importing = true);
    try {
      final imported = await ResumePdfImporter.pickAndImport();
      if (!mounted || imported == null) return;
      await _finishImport(imported);
    } on ResumeImportException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError("Something went wrong while reading that PDF.");
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importWithAi() async {
    if (!await ensureAiAvailable(context)) return;
    if (!mounted) return;

    setState(() => _importing = true);
    try {
      final imported = await ResumePdfImporter.pickAndImportWithAi();
      if (!mounted || imported == null) return;
      await AiUsageTracker.recordUsage();
      await _finishImport(imported);
    } on ResumeImportException catch (e) {
      if (mounted) _showError(e.message);
    } on AiServiceException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError("Something went wrong while reading that PDF.");
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _finishImport(ResumeData imported) async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (_) => _ImportSummarySheet(data: imported),
    );
    if (proceed != true || !mounted) return;

    final entry = DocumentEntry(
      id: _uuid.v4(),
      kind: DocumentKind.resume,
      title: imported.personalInfo.fullName.isEmpty ? 'My Resume' : imported.personalInfo.fullName,
      templateId: 'classic',
      updatedAt: DateTime.now(),
      completionPercent: imported.completionPercent,
      payload: imported.toJson(),
    );
    await DocumentsRepository.save(entry);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FormScreen(entry: entry)));
    _load();
  }

  // ---------------------------------------------------------------------------
  // AI tools
  // ---------------------------------------------------------------------------

  /// Shared guard for every AI-resume-generation entry point: confirms AI is
  /// configured, the daily limit allows it, and a Profile exists (offering
  /// to set one up if not). Returns true only if the caller should proceed.
  Future<bool> _checkAiGuards() async {
    // Availability + Pro gate first — so a free user is invited to upgrade
    // immediately instead of being sent to build a whole profile first.
    if (!await ensureAiAvailable(context)) return false;
    if (!mounted) return false;
    final hasProfile = await ProfileRepository.exists();
    if (!mounted) return false;
    if (!hasProfile) {
      final setUp = await showPromptSheet(
        context,
        icon: LucideIcons.user,
        title: 'Set up your profile first',
        message: 'AI builds tailored resumes from your profile: work history, education and skills. '
            'Add it once and reuse it every time.',
        primaryLabel: 'Set up profile',
        secondaryLabel: 'Not now',
      );
      if (setUp == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }
      return false;
    }
    return true;
  }

  Future<void> _onGenerateFromJobDescription() async {
    if (!await _checkAiGuards()) return;
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AiResumeGeneratorScreen()));
    _load();
  }

  // No _checkAiGuards here: the rule-based ATS score works with no Groq key
  // and no daily-limit check at all, and doesn't need a saved Profile.
  void _onCheckAtsScore() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AtsScoreEntryScreen()));
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  // ---------------------------------------------------------------------------
  // Document actions
  // ---------------------------------------------------------------------------

  void _showError(String message) {
    showPromptSheet(
      context,
      tone: PromptTone.error,
      icon: LucideIcons.fileText,
      title: "Couldn't import that PDF",
      message: message,
      primaryLabel: 'OK',
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final entries = _entries;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: entries == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ResponsiveContentBound(
                  maxWidth: 720,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      _Header(greeting: _greeting, initial: _initial, onAvatarTap: _openProfile),
                      const SizedBox(height: 20),
                      if (entries.isEmpty)
                        _StartHero(
                          onCreate: () => _openNew(DocumentKind.resume),
                          onImport: _importing ? null : _onImportPressed,
                        )
                      else
                        _ContinueHero(entry: entries.first, onContinue: () => _openExisting(entries.first)),
                      const SizedBox(height: 28),
                      const _SectionTitle('Create'),
                      Row(
                        children: [
                          for (final kind in DocumentKind.values) ...[
                            Expanded(
                              child: _CreateTile(
                                icon: documentKindStyle(kind).icon,
                                label: kind == DocumentKind.coverLetter ? 'Cover letter' : kind.label,
                                onTap: () => _openNew(kind),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: _CreateTile(
                              icon: LucideIcons.fileUp,
                              label: 'Import PDF',
                              loading: _importing,
                              onTap: _importing ? null : _onImportPressed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const _SectionTitle('AI tools'),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _ToolCard(
                                featured: true,
                                icon: LucideIcons.sparkles,
                                title: 'Tailor to a job',
                                subtitle: 'Paste a job post and get a matching resume',
                                onTap: _onGenerateFromJobDescription,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ToolCard(
                                icon: LucideIcons.gauge,
                                title: 'ATS score check',
                                subtitle: 'See how screening software rates your resume',
                                onTap: _onCheckAtsScore,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // The latest document is already featured in the
                      // Continue card above, so the list starts after it.
                      if (entries.length > 1) ...[
                        const SizedBox(height: 28),
                        _SectionTitle(
                          'Recent documents',
                          action: 'See all',
                          onAction: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                          ),
                        ),
                        DocumentGroup(
                          children: [
                            for (final e in entries.skip(1).take(_recentLimit))
                              DocumentCard(
                                key: ValueKey(e.id),
                                entry: e,
                                onTap: () => _openExisting(e),
                                onToggleFavorite: () => toggleDocumentFavorite(context, e),
                                onDelete: () => deleteDocument(context, e),
                                onDuplicate: () => duplicateDocument(context, e),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      const SizedBox(height: 10),
                      TemplateShowcase(
                        onOpen: _openTemplatePreview,
                        onSeeAll: widget.onOpenTemplates,
                        totalTemplates: ResumeTemplate.values.length +
                            CoverLetterTemplate.values.length +
                            ProposalTemplate.values.length,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String greeting;
  final String initial;
  final VoidCallback onAvatarTap;
  const _Header({required this.greeting, required this.initial, required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 26,
                  height: 1.15,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w600,
                  color: p.title,
                ),
              ),
              const SizedBox(height: 4),
              Text("Let's land your next role.", style: TextStyle(fontSize: 14.5, color: p.body)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'My profile',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAvatarTap,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.accentGold, AppColors.accentGoldDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: initial.isEmpty
                  ? const Icon(LucideIcons.user, color: AppColors.ink, size: 24)
                  : Text(
                      initial,
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.text, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.title)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.link,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Flat dark hero shared by both hero variants — solid color, no gradient,
/// glow or shine. In dark mode it steps up one surface level with a hairline
/// border so it doesn't vanish into the ink background.
class _HeroShell extends StatelessWidget {
  final Widget child;
  const _HeroShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? AppColors.slate900 : AppColors.ink,
        borderRadius: BorderRadius.circular(24),
        border: dark ? Border.all(color: AppColors.slate800) : null,
      ),
      child: child,
    );
  }
}

/// Returning user: jump straight back into the most recently edited document.
class _ContinueHero extends StatelessWidget {
  final DocumentEntry entry;
  final VoidCallback onContinue;
  const _ContinueHero({required this.entry, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final pct = entry.completionPercent.clamp(0, 100).toDouble();
    return _HeroShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTINUE WHERE YOU LEFT OFF',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isEmpty ? entry.kind.label : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.kind.label} · Edited ${relativeTime(entry.updatedAt).toLowerCase()}',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      color: AppColors.accentGold,
                    ),
                    Center(
                      child: Text(
                        '${pct.round()}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Continue editing'), SizedBox(width: 8), Icon(LucideIcons.arrowRight, size: 18)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// New user: one clear first step.
class _StartHero extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback? onImport;
  const _StartHero({required this.onCreate, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return _HeroShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: AppColors.accentGold,
            ),
            child: const Icon(LucideIcons.fileText, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create your first resume',
            style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a template, add your details, and export a polished PDF.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: onCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Start a resume', maxLines: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: onImport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Import PDF'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const _CreateTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.fieldBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: p.title),
                      )
                    : Icon(icon, color: p.title, size: 21),
              ),
              const SizedBox(height: 8),
              // Fixed two-line slot so tiles stay equal height whether a
              // label wraps ("Cover letter") or not ("Resume").
              SizedBox(
                height: 30,
                child: Center(
                  child: Text(
                    loading ? 'Reading…' : label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: p.title),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool featured;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: featured ? AppColors.accentGold.withValues(alpha: 0.6) : p.fieldBorder,
              width: featured ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: featured
                          ? const LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep])
                          : null,
                      color: featured ? null : p.background,
                    ),
                    child: Icon(icon, size: 20, color: featured ? AppColors.ink : p.title),
                  ),
                  const Spacer(),
                  if (featured)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accentGoldDeep),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.title)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12.5, height: 1.4, color: p.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick (offline) vs smart (AI) import choice.
class _ImportChoiceSheet extends StatelessWidget {
  const _ImportChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    Widget option({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool ai,
    }) {
      return Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, ai),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ai ? AppColors.accentGold.withValues(alpha: 0.6) : p.fieldBorder,
                width: ai ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient:
                        ai ? const LinearGradient(colors: [AppColors.accentGold, AppColors.accentGoldDeep]) : null,
                    color: ai ? null : p.background,
                  ),
                  child: Icon(icon, color: ai ? AppColors.ink : p.title, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.title)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 13, height: 1.4, color: p.body)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: p.muted),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Import a resume',
            style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: p.title),
          ),
          const SizedBox(height: 6),
          Text('Choose a PDF and we\'ll turn it into an editable resume.',
              style: TextStyle(fontSize: 14, height: 1.45, color: p.body)),
          const SizedBox(height: 18),
          option(
            icon: LucideIcons.sparkles,
            title: 'Smart import with AI',
            subtitle: 'Most accurate. Works with LinkedIn PDFs. Uses 1 AI credit.',
            ai: true,
          ),
          const SizedBox(height: 10),
          option(
            icon: LucideIcons.zap,
            title: 'Quick import',
            subtitle: 'Instant and works offline. Best for simple layouts.',
            ai: false,
          ),
        ],
      ),
    );
  }
}

/// What the importer found, before saving.
class _ImportSummarySheet extends StatelessWidget {
  final ResumeData data;
  const _ImportSummarySheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final name = data.personalInfo.fullName.trim();
    final rows = <(IconData, String, String)>[
      (LucideIcons.user, 'Name', name.isEmpty ? 'Not detected' : name),
      (LucideIcons.briefcase, 'Work experience', '${data.experience.length}'),
      (LucideIcons.graduationCap, 'Education', '${data.education.length}'),
      (LucideIcons.zap, 'Skills', '${data.skills.length}'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.check, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Text(
                'Resume imported',
                style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: p.title),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.fieldBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(rows[i].$1, size: 18, color: p.body),
                        const SizedBox(width: 10),
                        Expanded(child: Text(rows[i].$2, style: TextStyle(fontSize: 14, color: p.body))),
                        Text(rows[i].$3,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.title)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Automatic reading isn't perfect, so give each section a quick check.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.body),
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(label: 'Review and edit', onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 6),
          SizedBox(
            height: 46,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: p.body),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
