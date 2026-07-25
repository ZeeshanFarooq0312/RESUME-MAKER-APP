import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../pdf/pdf_fonts.dart';
import '../pdf/templates/cover_letter_classic_template.dart';
import '../pdf/templates/cover_letter_minimal_template.dart';
import '../pdf/templates/cover_letter_modern_template.dart';
import '../services/documents_repository.dart';
import '../services/download_credits_service.dart';
import '../theme/app_theme.dart';
import 'cover_letter_template_screen.dart';
import 'paywall_sheet.dart';

const _templateTitles = {
  CoverLetterTemplate.classic: 'Classic Cover Letter',
  CoverLetterTemplate.modern: 'Modern Cover Letter',
  CoverLetterTemplate.minimal: 'Minimal Cover Letter',
};

Future<pw.Document> _buildDoc(CoverLetterTemplate template, CoverLetterData data) {
  switch (template) {
    case CoverLetterTemplate.classic:
      return CoverLetterClassicTemplate.build(data);
    case CoverLetterTemplate.modern:
      return CoverLetterModernTemplate.build(data);
    case CoverLetterTemplate.minimal:
      return CoverLetterMinimalTemplate.build(data);
  }
}

class CoverLetterPreviewScreen extends StatefulWidget {
  final CoverLetterData data;
  final CoverLetterTemplate template;
  final String? documentId;
  final bool isSample;
  final VoidCallback? onUseTemplate;

  const CoverLetterPreviewScreen({
    super.key,
    required this.data,
    required this.template,
    this.documentId,
    this.isSample = false,
    this.onUseTemplate,
  });

  @override
  State<CoverLetterPreviewScreen> createState() => _CoverLetterPreviewScreenState();
}

class _CoverLetterPreviewScreenState extends State<CoverLetterPreviewScreen> {
  int _credits = 0;
  bool _downloading = false;
  late final Future<Uint8List> _pdfFuture = _generatePdf();

  @override
  void initState() {
    super.initState();
    _refreshCredits();
    _setScreenshotBlocking(true);
  }

  @override
  void dispose() {
    _setScreenshotBlocking(false);
    super.dispose();
  }

  Future<Uint8List> _generatePdf() async {
    final fontBytes = await PdfFonts.loadBytes();
    final template = widget.template;
    final data = widget.data;
    return Isolate.run(() async {
      PdfFonts.primeFromBytes(fontBytes.regular, fontBytes.bold);
      final doc = await _buildDoc(template, data);
      return doc.save();
    });
  }

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
      '${widget.data.fullName.isEmpty ? "cover_letter" : "${widget.data.fullName.replaceAll(" ", "_")}_cover_letter"}.pdf';

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
      completionPercent: widget.data.completionPercent,
      payload: widget.data.toJson(),
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
      if (!spent) return;
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
