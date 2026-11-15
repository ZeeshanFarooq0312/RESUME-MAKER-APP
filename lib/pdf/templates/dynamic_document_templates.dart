import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cover_letter_data.dart';
import '../../models/proposal_data.dart';
import '../../models/template_style_spec.dart';
import '../pdf_helpers.dart';
import 'design_kit.dart';

/// Shared page scaffolding for spec-driven letters and proposals: the same
/// five layouts as the resume engine, so a resume and its letter/proposal
/// in the same design read as one set.
abstract class _DocRenderer extends DesignKit {
  _DocRenderer(DesignKit kit) : super(kit.spec, kit.accent, kit.headBold, kit.headRegular);

  /// Big title at the top of the page (sender name / proposal title).
  String get titleText;

  /// Small line under the title (e.g. "Prepared for …").
  String? get subtitleText;

  /// Short facts for headers and sidebars (email, phone, date…).
  List<String> get headerFacts;

  /// Labeled blocks shown in the sidebar on sidebar layouts.
  List<(String, List<String>)> get sideBlocks;

  /// The document body, in reading order.
  List<pw.Widget> body();

  pw.MultiPage page() {
    switch (spec.layoutVariant) {
      case TemplateLayoutVariant.sidebarLeft:
      case TemplateLayoutVariant.sidebarRight:
        return _sidebarPage();
      case TemplateLayoutVariant.bannerHeader:
        return _bannerPage();
      case TemplateLayoutVariant.plainHeader:
      case TemplateLayoutVariant.splitHeader:
        return _plainPage();
    }
  }

  pw.Widget _titleBlock({required pw.CrossAxisAlignment align, PdfColor? color, PdfColor? subColor}) {
    return pw.Column(crossAxisAlignment: align, children: [
      pw.Text(titleText, style: pw.TextStyle(font: headBold, fontSize: 25, color: color ?? accent)),
      if (subtitleText != null && subtitleText!.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(subtitleText!,
              style: pw.TextStyle(font: headRegular, fontSize: 12, color: subColor ?? DesignKit.ink)),
        ),
    ]);
  }

  pw.MultiPage _plainPage() {
    final split = spec.layoutVariant == TemplateLayoutVariant.splitHeader;
    final centered = !split && spec.headerStyle == TemplateHeaderStyle.centered;
    final align = centered ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start;
    final header = split
        ? pw.Column(children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(child: _titleBlock(align: pw.CrossAxisAlignment.start)),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                for (final f in headerFacts) pw.Text(f, style: const pw.TextStyle(fontSize: 9.4, color: DesignKit.muted)),
              ]),
            ]),
            pw.SizedBox(height: sp(10)),
            pw.Container(height: 3, color: accent),
            pw.SizedBox(height: sp(20)),
          ])
        : pw.Column(crossAxisAlignment: align, children: [
            _titleBlock(align: align),
            if (headerFacts.isNotEmpty) ...[
              pw.SizedBox(height: sp(6)),
              pw.Text(headerFacts.join('   ·   '),
                  textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
                  style: const pw.TextStyle(fontSize: 9.6, color: DesignKit.muted)),
            ],
            pw.SizedBox(height: sp(10)),
            pw.Container(height: 1, color: DesignKit.mix(accent, 0.6)),
            pw.SizedBox(height: sp(20)),
          ]);
    return pw.MultiPage(
      margin: pw.EdgeInsets.symmetric(horizontal: 48, vertical: sp(40)),
      build: (_) => [header, ...body()],
    );
  }

  pw.MultiPage _bannerPage() {
    final centered = spec.headerStyle == TemplateHeaderStyle.centered;
    final align = centered ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start;
    final banner = pw.Container(
      width: double.infinity,
      color: accent,
      padding: pw.EdgeInsets.fromLTRB(48, sp(30), 48, sp(26)),
      child: pw.Column(crossAxisAlignment: align, children: [
        _titleBlock(align: align, color: PdfColors.white, subColor: DesignKit.mix(accent, 0.75)),
        if (headerFacts.isNotEmpty) ...[
          pw.SizedBox(height: sp(8)),
          pw.Text(headerFacts.join('   ·   '),
              textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
              style: const pw.TextStyle(fontSize: 9.4, color: PdfColors.white)),
        ],
      ]),
    );
    pw.Widget padded(pw.Widget w) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 48), child: w);
    return pw.MultiPage(
      margin: pw.EdgeInsets.only(bottom: sp(36)),
      header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : pw.SizedBox(height: sp(36)),
      build: (_) => [banner, pw.SizedBox(height: sp(24)), ...body().map(padded)],
    );
  }

  pw.MultiPage _sidebarPage() {
    final left = spec.layoutVariant == TemplateLayoutVariant.sidebarLeft;
    const sideWidth = 170.0;
    final sideColor = left ? accent : DesignKit.mix(accent, 0.9);
    final strong = left ? PdfColors.white : DesignKit.ink;

    final side = pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(22, 0, 18, 0),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        for (final (label, values) in sideBlocks)
          if (values.isNotEmpty) ...[
            heading(label, onDark: left),
            for (final v in values)
              pw.Padding(
                padding: pw.EdgeInsets.only(bottom: sp(4)),
                child: pw.Text(
                  v.contains('@') && v.length > 24 ? v.replaceFirst('@', '\n@') : v,
                  style: pw.TextStyle(fontSize: 9, color: strong),
                ),
              ),
            pw.SizedBox(height: sp(12)),
          ],
      ]),
    );
    final main = pw.Padding(
      padding: pw.EdgeInsets.fromLTRB(left ? 28 : 44, 0, left ? 44 : 28, 0),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _titleBlock(align: pw.CrossAxisAlignment.start, color: left ? DesignKit.ink : accent, subColor: accent),
        pw.SizedBox(height: sp(22)),
        ...body(),
      ]),
    );
    final sidePartition = pw.Partition(width: sideWidth, child: side);
    final mainPartition = pw.Partition(child: main);
    return pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: pw.EdgeInsets.symmetric(vertical: sp(38)),
        buildBackground: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Row(children: [
            if (left) pw.Container(width: sideWidth, color: sideColor),
            pw.Expanded(child: pw.Container(color: PdfColors.white)),
            if (!left) pw.Container(width: sideWidth, color: sideColor),
          ]),
        ),
      ),
      build: (_) => [
        pw.Partitions(children: left ? [sidePartition, mainPartition] : [mainPartition, sidePartition]),
      ],
    );
  }

  pw.Widget paragraph(String text, {double size = 10.4, PdfColor color = DesignKit.ink}) => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: sp(9)),
        child: pw.Text(text, style: pw.TextStyle(fontSize: size, lineSpacing: 2.8 * scale, color: color)),
      );
}

// ---------------------------------------------------------------------------
// Cover letter
// ---------------------------------------------------------------------------

class DynamicCoverLetterTemplate {
  static Future<pw.Document> build(CoverLetterData data, TemplateStyleSpec spec) async {
    final (theme, kit) = await DesignKit.load(spec);
    final doc = pw.Document(theme: theme);
    doc.addPage(_LetterRenderer(data, kit).page());
    return doc;
  }
}

class _LetterRenderer extends _DocRenderer {
  final CoverLetterData d;
  _LetterRenderer(this.d, super.kit);

  bool get _sidebar =>
      spec.layoutVariant == TemplateLayoutVariant.sidebarLeft || spec.layoutVariant == TemplateLayoutVariant.sidebarRight;

  @override
  String get titleText => d.fullName.isEmpty ? 'Your Name' : d.fullName;

  @override
  String? get subtitleText => null;

  @override
  List<String> get headerFacts => [d.email, d.phone, d.address].where((s) => s.isNotEmpty).toList();

  @override
  List<(String, List<String>)> get sideBlocks => [
        ('Contact', headerFacts),
        ('Applying for', [d.jobTitle, d.companyName].where((s) => s.isNotEmpty).toList()),
      ];

  @override
  List<pw.Widget> body() {
    final recipient =
        [d.recipientName, d.recipientTitle, d.companyName, d.companyAddress].where((s) => s.isNotEmpty).toList();
    return [
      if (d.date.isNotEmpty)
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: sp(14)),
          child: pw.Text(d.date, style: const pw.TextStyle(fontSize: 10, color: DesignKit.muted)),
        ),
      if (recipient.isNotEmpty)
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: sp(16)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            for (var i = 0; i < recipient.length; i++)
              pw.Text(recipient[i],
                  style: i == 0
                      ? pw.TextStyle(font: headBold, fontSize: 10.6, color: DesignKit.ink)
                      : const pw.TextStyle(fontSize: 10, color: DesignKit.ink)),
          ]),
        ),
      if (d.jobTitle.isNotEmpty && !_sidebar) heading('Re: ${d.jobTitle}'),
      if (d.salutation.isNotEmpty) paragraph(d.salutation),
      for (final p in DesignKit.paragraphs(d.body)) paragraph(p),
      pw.SizedBox(height: sp(6)),
      if (d.closing.isNotEmpty) paragraph(d.closing),
      pw.SizedBox(height: sp(14)),
      pw.Text(titleText, style: pw.TextStyle(font: headBold, fontSize: 12, color: accent)),
    ];
  }
}

// ---------------------------------------------------------------------------
// Proposal
// ---------------------------------------------------------------------------

class DynamicProposalTemplate {
  static Future<pw.Document> build(ProposalData data, TemplateStyleSpec spec) async {
    final (theme, kit) = await DesignKit.load(spec);
    final doc = pw.Document(theme: theme);
    doc.addPage(_ProposalRenderer(data, kit).page());
    return doc;
  }
}

class _ProposalRenderer extends _DocRenderer {
  final ProposalData d;
  _ProposalRenderer(this.d, super.kit);

  bool get _sidebar =>
      spec.layoutVariant == TemplateLayoutVariant.sidebarLeft || spec.layoutVariant == TemplateLayoutVariant.sidebarRight;

  String get _client => [d.clientName, d.clientCompany].where((s) => s.isNotEmpty).join(', ');
  String get _sender => [d.senderName, d.senderCompany].where((s) => s.isNotEmpty).join(', ');

  @override
  String get titleText => d.title.isEmpty ? 'Project Proposal' : d.title;

  @override
  String? get subtitleText => _sidebar || _client.isEmpty ? null : 'Prepared for $_client';

  @override
  List<String> get headerFacts =>
      [if (_sender.isNotEmpty) 'By $_sender', d.date].where((s) => s.isNotEmpty).toList();

  @override
  List<(String, List<String>)> get sideBlocks => [
        ('Prepared for', [d.clientName, d.clientCompany].where((s) => s.isNotEmpty).toList()),
        ('Prepared by', [d.senderName, d.senderCompany, d.senderEmail, d.senderPhone].where((s) => s.isNotEmpty).toList()),
        ('Date', [d.date].where((s) => s.isNotEmpty).toList()),
      ];

  /// "Design: $2,000" / "Design - $2,000" → ("Design", "$2,000") when the
  /// right side looks like an amount; otherwise null.
  static (String, String)? _priceRow(String line) {
    final m = RegExp(r'^(.*?)\s*(?::|\s[-–—]\s)\s*(.*\d.*)$').firstMatch(line);
    if (m == null || m.group(1)!.isEmpty) return null;
    return (m.group(1)!, m.group(2)!);
  }

  List<pw.Widget> _section(String title, List<pw.Widget> content) => [
        heading(title),
        ...content,
        pw.SizedBox(height: sp(10)),
      ];

  List<pw.Widget> _rows(String text, {bool emphasizeLast = false}) {
    final lines = DesignKit.lines(text);
    return [
      for (var i = 0; i < lines.length; i++)
        () {
          final row = _priceRow(lines[i]);
          final last = emphasizeLast && i == lines.length - 1 && lines.length > 1;
          final style = last
              ? pw.TextStyle(font: headBold, fontSize: 10.6, color: DesignKit.ink)
              : const pw.TextStyle(fontSize: 10.2, color: DesignKit.ink);
          return pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: sp(5)),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: DesignKit.mix(accent, last ? 0.4 : 0.85), width: last ? 1.2 : 0.6),
              ),
            ),
            child: row == null
                ? pw.Text(lines[i], style: style)
                : pw.Row(children: [
                    pw.Expanded(child: pw.Text(row.$1, style: style)),
                    pw.Text(row.$2, style: style.copyWith(font: headBold, color: last ? accent : DesignKit.ink)),
                  ]),
          );
        }(),
    ];
  }

  @override
  List<pw.Widget> body() => [
        if (d.overview.trim().isNotEmpty)
          ..._section('Overview', [for (final p in DesignKit.paragraphs(d.overview)) paragraph(p)]),
        if (d.scopeOfWork.trim().isNotEmpty)
          ..._section('Scope of work', [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: bulletLines(d.scopeOfWork, fontSize: 10.2),
            ),
          ]),
        if (d.timeline.trim().isNotEmpty) ..._section('Timeline', _rows(d.timeline)),
        if (d.pricing.trim().isNotEmpty) ..._section('Pricing', _rows(d.pricing, emphasizeLast: true)),
        if (d.termsAndConditions.trim().isNotEmpty)
          ..._section('Terms', [
            for (final p in DesignKit.paragraphs(d.termsAndConditions))
              paragraph(p, size: 9.4, color: DesignKit.muted),
          ]),
      ];
}
