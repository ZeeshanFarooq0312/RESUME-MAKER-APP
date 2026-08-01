import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/profile_repository.dart';
import '../services/resume_pdf_importer.dart';
import '../theme/app_theme.dart';
import '../widgets/document_card.dart';
import 'ai_resume_generator_screen.dart';
import 'cover_letter_form_screen.dart';
import 'form_screen.dart';
import 'profile_screen.dart';
import 'proposal_form_screen.dart';

const _uuid = Uuid();

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<DocumentEntry>? _entries;
  bool _importing = false;

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
        screen = const FormScreen();
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

  Future<void> _onGenerateFromJobDescription() async {
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
      return;
    }
    final hasProfile = await ProfileRepository.exists();
    if (!mounted) return;
    if (!hasProfile) {
      final setUp = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Set up your profile first'),
          content: const Text(
              'AI resume tailoring uses your saved profile (work history, education, skills) as '
              'the source of truth. Add it once and reuse it for every tailored resume.'),
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
      return;
    }
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
                    Text('Resume Builder', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.offline_bolt_outlined, color: Colors.white, size: 22),
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _onGenerateFromJobDescription,
                        icon: const Icon(Icons.psychology_outlined, size: 18),
                        label: const Text('Generate Resume from Job Description'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('My Documents', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No documents yet — create one above to get started.',
                          style: TextStyle(color: AppColors.slate600, fontSize: 13),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E5F3)),
        ),
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
