import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../theme/app_theme.dart';

// Renders a real, low-res snapshot of a template's first page (filled with
// sample data) so users can see what a template actually looks like before
// picking it, instead of a generic placeholder mockup.
class TemplateThumbnail extends StatefulWidget {
  final DocumentKind kind;
  final Object template;

  const TemplateThumbnail({super.key, required this.kind, required this.template});

  @override
  State<TemplateThumbnail> createState() => _TemplateThumbnailState();
}

class _TemplateThumbnailState extends State<TemplateThumbnail> {
  static final _cache = <String, Uint8List>{};

  late final Future<Uint8List> _future = _load();

  String get _cacheKey => '${widget.kind.name}_${(widget.template as Enum).name}';

  Future<Uint8List> _load() async {
    final cached = _cache[_cacheKey];
    if (cached != null) return cached;

    final fontBytes = await PdfFonts.loadBytes();
    final kind = widget.kind;
    final template = widget.template;
    final pdfBytes = await Isolate.run(() async {
      PdfFonts.primeFromBytes(fontBytes.regular, fontBytes.bold);
      switch (kind) {
        case DocumentKind.resume:
          final doc = await buildResumeDoc(template as ResumeTemplate, sampleResumeData());
          return doc.save();
        case DocumentKind.coverLetter:
          final doc =
              await buildCoverLetterDoc(template as CoverLetterTemplate, sampleCoverLetterData());
          return doc.save();
        case DocumentKind.proposal:
          final doc = await buildProposalDoc(template as ProposalTemplate, sampleProposalData());
          return doc.save();
      }
    });

    final raster = await Printing.raster(pdfBytes, pages: const [0], dpi: 90).first;
    final png = await raster.toPng();
    _cache[_cacheKey] = png;
    return png;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: AppColors.slate100,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        );
      },
    );
  }
}
