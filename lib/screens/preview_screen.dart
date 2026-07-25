import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart' show TranslateLanguage;
import 'package:printing/printing.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../services/documents_repository.dart';
import '../services/download_credits_service.dart';
import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import 'paywall_sheet.dart';
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
};

class PreviewScreen extends StatefulWidget {
  final ResumeData resumeData;
  final ResumeTemplate template;
  final String? documentId;
  final bool isSample;
  final VoidCallback? onUseTemplate;

  const PreviewScreen({
    super.key,
    required this.resumeData,
    required this.template,
    this.documentId,
    this.isSample = false,
    this.onUseTemplate,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  int _credits = 0;
  bool _downloading = false;
  TranslateLanguage? _translatedLanguage;
  late Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _refreshCredits();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Translation is available on Android and iOS.'),
      ));
      return;
    }
    final language = await showModalBottomSheet<TranslateLanguage>(
      context: context,
      isScrollControlled: true,
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

    _showProgressDialog('Preparing ${TranslationService.labelFor(language)} translation…');
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't translate — check your internet connection and try again."),
        ));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<bool?> _confirmDownload(TranslateLanguage language) {
    final label = TranslationService.labelFor(language);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Download language pack?'),
        content: Text(
          'Translating to $label needs a one-time download (requires Wi-Fi) the first '
          'time. After that, translation runs fully on your device — no internet needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
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

  Future<void> _refreshCredits() async {
    final credits = await DownloadCreditsService.getCredits();
    if (mounted) setState(() => _credits = credits);
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
      completionPercent: widget.resumeData.completionPercent,
      payload: widget.resumeData.toJson(),
    ));
  }

  Future<void> _onDownloadPressed() async {
    if (_credits <= 0) {
      final unlocked = await showPaywallSheet(context);
      if (unlocked != true) return;
      await _refreshCredits();
    }

    setState(() => _downloading = true);
    try {
      final spent = await DownloadCreditsService.consumeCredit();
      if (!spent) return; // race with another download; bail safely
      final bytes = await _pdfFuture;
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
      await _touchDocumentEntry();
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        await _refreshCredits();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_templateTitles[widget.template]!),
        actions: [
          if (!widget.isSample)
            IconButton(
              icon: const Icon(Icons.translate),
              tooltip: 'Translate',
              onPressed: _openTranslateSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.slate600.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              widget.isSample
                  ? 'Sample preview with placeholder text — double-tap or pinch to zoom'
                  : 'Double-tap or pinch to zoom in for details',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate600, fontSize: 12),
            ),
          ),
          if (_translatedLanguage != null)
            Container(
              width: double.infinity,
              color: AppColors.goldLight.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Translated to ${TranslationService.labelFor(_translatedLanguage!)}',
                      style: const TextStyle(color: AppColors.slate900, fontSize: 12.5),
                    ),
                  ),
                  TextButton(
                    onPressed: _revertTranslation,
                    child: const Text('Revert', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PdfPreview(
              build: (format) => _pdfFuture,
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              pdfFileName: _fileName,
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE1E4E8))),
              ),
              child: widget.isSample
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onUseTemplate,
                        child: const Text('Use This Template'),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            _credits > 0
                                ? '$_credits download${_credits == 1 ? '' : 's'} available'
                                : 'Preview is free — \$3 unlocks 2 downloads',
                            style: const TextStyle(color: AppColors.slate600, fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _downloading ? null : _onDownloadPressed,
                          icon: _downloading
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_credits > 0 ? Icons.download : Icons.lock_outline, size: 18),
                          label: Text(_credits > 0 ? 'Download PDF' : 'Unlock & Download'),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
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
    final languages = TranslationService.supportedLanguages
        .where((l) => TranslationService.labelFor(l).toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Translate Resume', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Latin-script languages only for now — Arabic, Hindi, Chinese and similar '
              'scripts aren\'t supported yet.',
              style: TextStyle(color: AppColors.slate600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              decoration: const InputDecoration(
                hintText: 'Search languages',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: languages.length,
                itemBuilder: (context, i) {
                  final lang = languages[i];
                  return ListTile(
                    title: Text(TranslationService.labelFor(lang)),
                    onTap: () => Navigator.pop(context, lang),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
