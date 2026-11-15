import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/preview_scaffold.dart';
import 'package:printing/printing.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../models/template_style_spec.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../services/documents_repository.dart';

/// Preview/export screen for a resume rendered from an AI-generated
/// [TemplateStyleSpec] rather than a named [ResumeTemplate] — the
/// "custom" counterpart to preview_screen.dart's PreviewScreen. A separate,
/// smaller screen rather than extending PreviewScreen itself, since that
/// screen's translate/share actions and ResumeTemplate-keyed title lookup
/// don't apply here.
class DynamicPreviewScreen extends StatefulWidget {
  final ResumeData resumeData;
  final TemplateStyleSpec styleSpec;
  final String? documentId;
  final bool isSample;
  final VoidCallback? onUseTemplate;

  const DynamicPreviewScreen({
    super.key,
    required this.resumeData,
    required this.styleSpec,
    this.documentId,
    this.isSample = false,
    this.onUseTemplate,
  });

  @override
  State<DynamicPreviewScreen> createState() => _DynamicPreviewScreenState();
}

class _DynamicPreviewScreenState extends State<DynamicPreviewScreen> {
  bool _downloading = false;
  late final Future<Uint8List> _pdfFuture = _generatePdf();

  Future<Uint8List> _generatePdf() async {
    final fontBytes = await PdfFonts.loadBytes();
    final data = widget.resumeData;
    final spec = widget.styleSpec;
    return Isolate.run(() async {
      PdfFonts.primeFromBytes(fontBytes.regular, fontBytes.bold);
      final doc = await buildDynamicResumeDoc(data, spec);
      return doc.save();
    });
  }

  String get _fileName =>
      '${widget.resumeData.personalInfo.fullName.isEmpty ? "resume" : widget.resumeData.personalInfo.fullName.replaceAll(" ", "_")}.pdf';

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
      templateId: 'custom',
      updatedAt: DateTime.now(),
      isFavorite: existing.isFavorite,
      completionPercent: widget.resumeData.completionPercent,
      payload: widget.resumeData.toJson(),
      companyLabel: existing.companyLabel,
      roleLabel: existing.roleLabel,
      customStyleSpec: widget.styleSpec.toJson(),
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
    return PreviewScaffold(
      title: 'Your custom template',
      subtitle: widget.isSample ? 'Template preview' : 'Designed with AI',
      pdf: _pdfFuture,
      isSample: widget.isSample,
      onShare: widget.isSample || _downloading ? null : _onDownloadPressed,
      primaryLabel: widget.isSample ? 'Use this template' : 'Download PDF',
      primaryIcon: widget.isSample ? LucideIcons.arrowRight : LucideIcons.download,
      primaryLoading: _downloading,
      onPrimary: widget.isSample ? widget.onUseTemplate : _onDownloadPressed,
    );
  }
}
