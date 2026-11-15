import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/sample_documents.dart';
import '../models/document_entry.dart';
import '../models/template_kind.dart';
import '../pdf/pdf_builder.dart';
import '../pdf/pdf_fonts.dart';
import '../pdf/resume_design_presets.dart';

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

    final fontBytes = await PdfFonts.loadBytes(
      extra: documentFontsFor(widget.template as Enum),
    );
    final kind = widget.kind;
    final template = widget.template;
    final pdfBytes = await Isolate.run(() async {
      PdfFonts.primeFromBytes(fontBytes.regular, fontBytes.bold, fontBytes.extras);
      switch (kind) {
        case DocumentKind.resume:
          final doc = await buildResumeDoc(template as ResumeTemplate, sampleResumeData());
          return doc.save();
        case DocumentKind.coverLetter:
          final doc = await buildCoverLetterDoc(template as CoverLetterTemplate, sampleCoverLetterData());
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
        // Skeleton page while rendering — and as the fallback if rendering
        // fails, rather than spinning forever.
        if (!snapshot.hasData) return const _SkeletonPage();
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        );
      },
    );
  }
}

class _SkeletonPage extends StatelessWidget {
  const _SkeletonPage();

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFECEAF3);
    Widget bar(double f, {double h = 5}) => FractionallySizedBox(
          widthFactor: f,
          alignment: Alignment.centerLeft,
          child: Container(height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              bar(0.55, h: 8),
              const SizedBox(height: 5),
              bar(0.35),
              const SizedBox(height: 12),
              for (final f in [0.3, 0.9, 0.8, 0.85, 0.6]) ...[bar(f), const SizedBox(height: 5)],
              const SizedBox(height: 7),
              for (final f in [0.3, 0.88, 0.75, 0.5]) ...[bar(f), const SizedBox(height: 5)],
            ],
          ),
        ),
      ),
    );
  }
}
