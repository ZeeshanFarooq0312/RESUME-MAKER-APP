import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../services/documents_repository.dart';
import '../theme/app_theme.dart';
import 'proposal_template_screen.dart';

const _templateTitles = {
  ProposalTemplate.classic: 'Classic Proposal',
  ProposalTemplate.modern: 'Modern Proposal',
  ProposalTemplate.minimal: 'Minimal Proposal',
};

class ProposalPreviewScreen extends StatefulWidget {
  final ProposalData data;
  final ProposalTemplate template;
  final String? documentId;
  final bool isSample;
  final VoidCallback? onUseTemplate;

  const ProposalPreviewScreen({
    super.key,
    required this.data,
    required this.template,
    this.documentId,
    this.isSample = false,
    this.onUseTemplate,
  });

  @override
  State<ProposalPreviewScreen> createState() => _ProposalPreviewScreenState();
}

class _ProposalPreviewScreenState extends State<ProposalPreviewScreen> {
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
      final doc = await buildProposalDoc(template, data);
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
      '${widget.data.title.isEmpty ? "proposal" : widget.data.title.replaceAll(" ", "_")}.pdf';

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
    setState(() => _downloading = true);
    try {
      final bytes = await _pdfFuture;
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
      await _touchDocumentEntry();
    } finally {
      if (mounted) setState(() => _downloading = false);
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
