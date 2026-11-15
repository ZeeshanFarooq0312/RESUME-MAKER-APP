import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/auth/auth_kit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'ai_guard.dart';
import '../widgets/app_feedback.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart' show TranslateLanguage;
import 'package:printing/printing.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../models/template_kind.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../services/subscription_repository.dart';
import '../services/translation_service.dart';
import '../widgets/pill_search_field.dart';
import '../widgets/preview_scaffold.dart';
import 'cover_letter_template_screen.dart';
import 'interview_prep_screen.dart';
import 'template_screen.dart';



const _templateTitles = {
  ResumeTemplate.classic: 'Classic Resume',
  ResumeTemplate.modern: 'Modern Resume',
  ResumeTemplate.minimal: 'Minimal Resume',
  ResumeTemplate.professional: 'Professional Resume',
  ResumeTemplate.compact: 'Compact Resume',
  ResumeTemplate.executive: 'Executive Resume',
  ResumeTemplate.technical: 'Technical Resume',
  ResumeTemplate.simpleBold: 'Simple Bold Resume',
  ResumeTemplate.harvard: 'Harvard Resume',
  ResumeTemplate.creative: 'Creative Resume',
  ResumeTemplate.elegant: 'Elegant Resume',
  ResumeTemplate.timeline: 'Timeline Resume',
};

class PreviewScreen extends StatefulWidget {
  final ResumeData resumeData;
  final ResumeTemplate template;
  final String? documentId;
  final bool isSample;
  final bool isPremium;
  final VoidCallback? onUseTemplate;

  const PreviewScreen({
    super.key,
    required this.resumeData,
    required this.template,
    this.documentId,
    this.isSample = false,
    this.isPremium = false,
    this.onUseTemplate,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _downloading = false;
  TranslateLanguage? _translatedLanguage;
  late Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _setScreenshotBlocking(true);
    _pdfFuture = _generatePdf(widget.resumeData);
  }

  // Building a pw.Document + serializing it is real synchronous CPU work.
  // Running it on the main isolate visibly stutters the page-transition
  // frame right as this screen appears. Isolate.run offloads it — but a
  // background isolate has no Flutter bindings, so PdfFonts.theme()'s
  // rootBundle.load would throw there. Loading the font bytes here (on this
  // isolate, where bindings exist) and priming the isolate's own PdfFonts
  // cache from those bytes avoids touching rootBundle inside the isolate.
  Future<Uint8List> _generatePdf(ResumeData data) async {
    final fontBytes = await PdfFonts.loadBytes();
    final template = widget.template;
    return Isolate.run(() async {
      PdfFonts.primeFromBytes(fontBytes.regular, fontBytes.bold);
      final doc = await buildResumeDoc(template, data);
      return doc.save();
    });
  }

  // google_mlkit_translation only ships native support for Android/iOS.
  bool get _translationSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _openTranslateSheet() async {
    if (!_translationSupported) {
      showToast(context, 'Translation is available on Android and iOS.', tone: ToastTone.info);
      return;
    }
    final language = await showModalBottomSheet<TranslateLanguage>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _LanguagePickerSheet(),
    );
    if (language == null || !mounted) return;
    await _translateTo(language);
  }

  Future<void> _translateTo(TranslateLanguage language) async {
    final ready = await TranslationService.areModelsReady(language);
    if (!ready) {
      if (!mounted) return;
      final proceed = await _confirmDownload(language);
      if (proceed != true) return;
    }
    if (!mounted) return;

    showProgressOverlay(context, 'Preparing ${TranslationService.labelFor(language)} translation…');
    try {
      await TranslationService.ensureModelsReady(language);
      final translated = await TranslationService.translateResumeData(widget.resumeData, language);
      if (!mounted) return;
      setState(() {
        _translatedLanguage = language;
        _pdfFuture = _generatePdf(translated);
      });
    } catch (_) {
      if (mounted) {
        showToast(context, "Couldn't translate — check your internet connection and try again.", tone: ToastTone.error);
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _onGenerateCoverLetterPressed() async {
    if (!GroqService.isConfigured) {
      showAiUnavailableSheet(context);
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) showAiLimitSheet(context);
      return;
    }
    if (!mounted) return;

    final companyController = TextEditingController();
    final jobTitleController = TextEditingController(text: widget.resumeData.personalInfo.jobTitle);
    final submitted = await showInputSheet(
      context,
      icon: LucideIcons.mail,
      title: 'Write a cover letter',
      message: 'AI writes a cover letter from this resume, tailored to the company and role.',
      fields: [
        SheetField(
            label: 'Company', hint: 'Careem', icon: LucideIcons.building2, controller: companyController, required: true),
        SheetField(label: 'Job title', hint: 'Product Designer', icon: LucideIcons.briefcase, controller: jobTitleController),
      ],
      primaryLabel: 'Write cover letter',
      primaryIcon: LucideIcons.sparkles,
    );
    if (!submitted || !mounted) return;

    final companyName = companyController.text.trim();
    final jobTitle = jobTitleController.text.trim();

    showProgressOverlay(context, 'Writing your cover letter…');
    try {
      final body = await GroqService.generateCoverLetterFromResume(
        resume: widget.resumeData,
        companyName: companyName,
        jobTitle: jobTitle.isEmpty ? null : jobTitle,
      );
      await AiUsageTracker.recordUsage();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final letter = CoverLetterData(
        fullName: widget.resumeData.personalInfo.fullName,
        email: widget.resumeData.personalInfo.email,
        phone: widget.resumeData.personalInfo.phone,
        companyName: companyName,
        jobTitle: jobTitle.isEmpty ? widget.resumeData.personalInfo.jobTitle : jobTitle,
        body: body,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => CoverLetterTemplateScreen(data: letter)));
    } on AiServiceException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        showToast(context, e.message, tone: ToastTone.error);
      }
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        showToast(context, 'Something went wrong. Please try again.', tone: ToastTone.error);
      }
    }
  }

  Future<bool?> _confirmDownload(TranslateLanguage language) {
    final label = TranslationService.labelFor(language);
    return showPromptSheet(
      context,
      icon: LucideIcons.languages,
      title: 'Download $label?',
      message: 'Translating to $label needs a one-time download, so Wi-Fi is best. '
          'After that, translation runs fully on your device with no internet needed.',
      primaryLabel: 'Download',
      secondaryLabel: 'Cancel',
    );
  }

  void _revertTranslation() {
    setState(() {
      _translatedLanguage = null;
      _pdfFuture = _generatePdf(widget.resumeData);
    });
  }

  @override
  void dispose() {
    _setScreenshotBlocking(false);
    super.dispose();
  }

  // screen_protector only ships native support for Android/iOS; calling it
  // on desktop/web platforms would throw a MissingPluginException.
  void _setScreenshotBlocking(bool enabled) {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (enabled) {
      ScreenProtector.preventScreenshotOn();
    } else {
      ScreenProtector.preventScreenshotOff();
    }
  }

  String get _fileName =>
      '${widget.resumeData.personalInfo.fullName.isEmpty ? "resume" : widget.resumeData.personalInfo.fullName.replaceAll(" ", "_")}.pdf';

  // Bumps the saved document's updatedAt/templateId after a successful
  // download so the dashboard reflects the template actually used. Only
  // documents opened through the dashboard/templates flow carry an id —
  // skip silently otherwise (e.g. none exists yet for this document).
  Future<void> _touchDocumentEntry() async {
    final id = widget.documentId;
    if (id == null) return;
    final entries = await DocumentsRepository.loadAll();
    final index = entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final existing = entries[index];
    await DocumentsRepository.save(DocumentEntry(
      id: existing.id,
      kind: existing.kind,
      title: existing.title,
      templateId: widget.template.name,
      updatedAt: DateTime.now(),
      isFavorite: existing.isFavorite,
      companyLabel: existing.companyLabel,
      roleLabel: existing.roleLabel,
      customStyleSpec: existing.customStyleSpec,
      completionPercent: widget.resumeData.completionPercent,
      payload: widget.resumeData.toJson(),
    ));
  }

  Future<void> _onDownloadPressed() async {
    if (widget.isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic) {
      await showProUpgradeSheet(context);
      return;
    }
    setState(() => _downloading = true);
    try {
      final bytes = await _pdfFuture;
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
      await _touchDocumentEntry();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }


  bool get _locked => widget.isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic;

  void _changeTemplate() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TemplateScreen(resumeData: widget.resumeData, documentId: widget.documentId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translated = _translatedLanguage;
    return PreviewScaffold(
      title: _templateTitles[widget.template]!,
      subtitle: widget.isSample ? 'Template preview' : 'Your resume',
      isPro: widget.template.isPremium,
      pdf: _pdfFuture,
      isSample: widget.isSample,
      onShare: widget.isSample || _downloading ? null : _onDownloadPressed,
      banner: translated == null
          ? null
          : PreviewBanner(
              icon: LucideIcons.languages,
              text: 'Translated to ${TranslationService.labelFor(translated)}',
              actionLabel: 'Show original',
              onAction: _revertTranslation,
            ),
      tools: widget.isSample
          ? const []
          : [
              PreviewTool(icon: LucideIcons.languages, label: 'Translate', onTap: _openTranslateSheet),
              PreviewTool(icon: LucideIcons.mail, label: 'Cover letter', onTap: _onGenerateCoverLetterPressed),
              PreviewTool(
                icon: LucideIcons.messageSquareText,
                label: 'Interview',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InterviewPrepScreen(resumeData: widget.resumeData)),
                ),
              ),
              PreviewTool(icon: LucideIcons.layoutTemplate, label: 'Template', onTap: _changeTemplate),
            ],
      primaryLabel: widget.isSample
          ? 'Use this template'
          : _locked
              ? 'Upgrade to download'
              : 'Download PDF',
      primaryIcon: widget.isSample
          ? LucideIcons.arrowRight
          : _locked
              ? LucideIcons.crown
              : LucideIcons.download,
      primaryLoading: _downloading,
      onPrimary: widget.isSample ? widget.onUseTemplate : _onDownloadPressed,
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet();

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final languages = TranslationService.supportedLanguages
        .where((l) => TranslationService.labelFor(l).toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Translate resume',
              style: TextStyle(fontFamily: 'Fraunces', fontSize: 22, fontWeight: FontWeight.w600, color: p.title)),
          const SizedBox(height: 6),
          Text(
            'Runs on your device. Latin-script languages only for now, so Arabic, Hindi, Chinese and '
            'similar scripts are not supported yet.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: p.body),
          ),
          const SizedBox(height: 16),
          PillSearchField(
            controller: _query,
            hintText: 'Search languages',
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: languages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('No matching language', textAlign: TextAlign.center, style: TextStyle(color: p.body)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: languages.length,
                    itemBuilder: (context, i) {
                      final lang = languages[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, lang),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(TranslationService.labelFor(lang),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.title)),
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
