import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../services/documents_repository.dart';
import '../services/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/zoomable_pdf_view.dart';
import 'cover_letter_template_screen.dart';
import 'paywall_screen.dart';

const _templateTitles = {
  CoverLetterTemplate.classic: 'Classic Cover Letter',
  CoverLetterTemplate.modern: 'Modern Cover Letter',
  CoverLetterTemplate.minimal: 'Minimal Cover Letter',
  CoverLetterTemplate.bold: 'Bold Cover Letter',
  CoverLetterTemplate.formal: 'Formal Cover Letter',
};

class CoverLetterPreviewScreen extends StatefulWidget {
  final CoverLetterData data;
  final CoverLetterTemplate template;
  final String? documentId;
  final bool isSample;
  final bool isPremium;
  final VoidCallback? onUseTemplate;

  const CoverLetterPreviewScreen({
    super.key,
    required this.data,
    required this.template,
    this.documentId,
    this.isSample = false,
    this.isPremium = false,
    this.onUseTemplate,
  });

  @override
  State<CoverLetterPreviewScreen> createState() => _CoverLetterPreviewScreenState();
}

class _CoverLetterPreviewScreenState extends State<CoverLetterPreviewScreen> {
  bool _downloading = false;
  late final Future<Uint8List> _pdfFuture = _generatePdf();

  @override
  void initState() {
    super.initState();
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
      final doc = await buildCoverLetterDoc(template, data);
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
    if (widget.isPremium && SubscriptionSession.tier.value == SubscriptionTier.basic) {
      await _showUpgradeDialog();
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

  Future<void> _showUpgradeDialog() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Premium template'),
        content: const Text('This template is available on Pro. Upgrade to export or download it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_templateTitles[widget.template]!),
        actions: [
          if (!widget.isSample)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _downloading ? null : _onDownloadPressed,
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
                  ? 'Sample preview with placeholder text — pinch to zoom'
                  : 'Pinch to zoom in for details',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate600, fontSize: 12),
            ),
          ),
          Expanded(
            child: ZoomablePdfView(pdf: _pdfFuture),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A1030).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: widget.isSample
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onUseTemplate,
                        child: const Text('Use This Template'),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _downloading ? null : _onDownloadPressed,
                        icon: _downloading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download, size: 18),
                        label: const Text('Download PDF'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
