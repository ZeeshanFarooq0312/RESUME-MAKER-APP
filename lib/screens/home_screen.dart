import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/resume_data.dart';
import '../services/resume_pdf_importer.dart';
import '../theme/app_theme.dart';
import 'form_screen.dart';

const String kResumeStorageKey = 'resume_data_v1';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasExisting = false;
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kResumeStorageKey);
    setState(() {
      _hasExisting = saved != null;
      _loading = false;
    });
  }

  Future<void> _openForm({required bool fresh}) async {
    ResumeData data;
    if (fresh) {
      data = ResumeData();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kResumeStorageKey);
      data = saved != null ? ResumeData.decode(saved) : ResumeData();
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormScreen(resumeData: data)),
    );
    _checkExisting();
  }

  Future<void> _uploadResume() async {
    setState(() => _importing = true);
    try {
      final imported = await ResumePdfImporter.pickAndImport();
      if (!mounted || imported == null) return;

      final proceed = await _showImportSummary(imported);
      if (proceed != true || !mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FormScreen(resumeData: imported)),
      );
      _checkExisting();
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
          "Automatic parsing isn't perfect — please review and correct each step.",
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

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.slate900,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.description_outlined,
                          color: AppColors.gold, size: 28),
                    ),
                    const SizedBox(height: 24),
                    Text('Smart Resume Builder',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Build a professional, ATS-friendly CV in minutes.\nWorks fully offline.',
                      style: TextStyle(
                          color: AppColors.slate600, height: 1.4, fontSize: 15),
                    ),
                    const SizedBox(height: 40),
                    if (_hasExisting) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _openForm(fresh: false),
                          child: const Text('Continue My Resume'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _openForm(fresh: true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.slate400),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Start a New Resume'),
                        ),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _openForm(fresh: true),
                          child: const Text('Create My Resume'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _importing ? null : _uploadResume,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.slate400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _importing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file, size: 18),
                        label: Text(_importing ? 'Reading PDF…' : 'Upload Existing Resume (PDF)'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
