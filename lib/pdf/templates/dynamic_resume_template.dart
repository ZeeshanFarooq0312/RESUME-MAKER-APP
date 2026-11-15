import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/resume_data.dart';
import '../../models/template_style_spec.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// The design-spec template engine: renders a resume from a
/// [TemplateStyleSpec] (layout × fonts × color × heading style × density)
/// instead of a hand-written file per style. Drives both the curated Pro
/// designs (see resume_design_presets.dart) and AI "design your own".
/// Uses MultiPage so long resumes flow onto extra pages — sidebar layouts
/// included, via Partitions — rather than being clipped.
class DynamicResumeTemplate {
  static const _palette = <TemplateAccentColor, PdfColor>{
    TemplateAccentColor.violet: PdfColor.fromInt(0xFF6C5DD3),
    TemplateAccentColor.forestGreen: PdfColor.fromInt(0xFF1F6F54),
    TemplateAccentColor.navyBlue: PdfColor.fromInt(0xFF2C5C8A),
    TemplateAccentColor.burgundy: PdfColor.fromInt(0xFFB0413E),
    TemplateAccentColor.gold: PdfColor.fromInt(0xFFB8862F),
    TemplateAccentColor.charcoal: PdfColor.fromInt(0xFF2A2A33),
    TemplateAccentColor.teal: PdfColor.fromInt(0xFF1A6B70),
    TemplateAccentColor.slate: PdfColor.fromInt(0xFF1B2430),
    TemplateAccentColor.plum: PdfColor.fromInt(0xFF6B2F5E),
    TemplateAccentColor.rust: PdfColor.fromInt(0xFFB4532A),
    TemplateAccentColor.ocean: PdfColor.fromInt(0xFF1F5FA8),
    TemplateAccentColor.black: PdfColor.fromInt(0xFF111111),
  };

  static const _fonts = <TemplateFont, PdfFontFamily>{
    TemplateFont.lato: PdfFontFamily.lato,
    TemplateFont.poppins: PdfFontFamily.poppins,
    TemplateFont.ptSerif: PdfFontFamily.ptSerif,
    TemplateFont.ptSans: PdfFontFamily.ptSans,
    TemplateFont.crimsonText: PdfFontFamily.crimsonText,
    TemplateFont.plexSerif: PdfFontFamily.plexSerif,
  };

  /// ARGB value of an accent color, so UI swatches match the PDF exactly.
  static int accentArgb(TemplateAccentColor c) => _palette[c]!.toInt();

  /// The font families [spec] needs, so callers load only those bytes.
  static Set<PdfFontFamily> fontsFor(TemplateStyleSpec spec) => {_fonts[spec.headingFont]!, _fonts[spec.bodyFont]!};

  static const _ink = PdfColor.fromInt(0xFF222222);
  static const _muted = PdfColor.fromInt(0xFF666666);

  /// [c] blended toward white by [amount] (0 = c, 1 = white).
  static PdfColor _mix(PdfColor c, double amount) => PdfColor(
        c.red + (1 - c.red) * amount,
        c.green + (1 - c.green) * amount,
        c.blue + (1 - c.blue) * amount,
      );

  static Future<pw.Document> build(ResumeData data, TemplateStyleSpec spec) async {
    final base = await PdfFonts.theme();
    final head = PdfFonts.family(_fonts[spec.headingFont]!);
    final body = PdfFonts.family(_fonts[spec.bodyFont]!);
    final latoRegular = base.defaultTextStyle.font!;
    final theme = pw.ThemeData.withFont(
      base: body.regular,
      bold: body.bold,
      fontFallback: [latoRegular],
    );
    final doc = pw.Document(theme: theme);
    final r = _Renderer(data, spec, _palette[spec.accentColor]!, head.bold, head.regular);

    switch (spec.layoutVariant) {
      case TemplateLayoutVariant.sidebarLeft:
      case TemplateLayoutVariant.sidebarRight:
        doc.addPage(r.sidebarPage());
      case TemplateLayoutVariant.bannerHeader:
        doc.addPage(r.bannerPage());
      case TemplateLayoutVariant.plainHeader:
      case TemplateLayoutVariant.splitHeader:
        doc.addPage(r.plainPage());
    }
    return doc;
  }
}

class _Renderer {
  final ResumeData data;
  final TemplateStyleSpec spec;
  final PdfColor accent;
  final pw.Font headBold;
  final pw.Font headRegular;

  _Renderer(this.data, this.spec, this.accent, this.headBold, this.headRegular);

  PersonalInfo get info => data.personalInfo;
  PdfColor get tint => DynamicResumeTemplate._mix(accent, 0.88);

  double get _scale => switch (spec.density) {
        TemplateDensity.compact => 0.82,
        TemplateDensity.comfortable => 1.0,
        TemplateDensity.spacious => 1.22,
      };
  double sp(double v) => v * _scale;

  String get name => info.fullName.isEmpty ? 'Your Name' : info.fullName;

  // ---------------------------------------------------------------------------
  // Pieces
  // ---------------------------------------------------------------------------

  pw.Widget heading(String text, {bool onDark = false}) {
    final label = text.toUpperCase();
    final color = onDark ? PdfColors.white : accent;
    final pad = pw.EdgeInsets.only(bottom: sp(8));
    switch (spec.headingStyle) {
      case TemplateHeadingStyle.caps:
        return pw.Padding(
          padding: pad,
          child: pw.Text(label, style: pw.TextStyle(font: headBold, fontSize: 10.5, letterSpacing: 1.6, color: color)),
        );
      case TemplateHeadingStyle.underline:
        return pw.Container(
          margin: pad,
          padding: const pw.EdgeInsets.only(bottom: 3),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: color, width: 1.2))),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(font: headBold, fontSize: 10.5, letterSpacing: 1.2, color: color)),
            ),
          ]),
        );
      case TemplateHeadingStyle.bar:
        return pw.Padding(
          padding: pad,
          child: pw.Row(children: [
            pw.Container(width: 3, height: 12, color: color),
            pw.SizedBox(width: 8),
            pw.Text(label,
                style: pw.TextStyle(
                    font: headBold, fontSize: 10.5, letterSpacing: 1.2, color: onDark ? PdfColors.white : DynamicResumeTemplate._ink)),
          ]),
        );
      case TemplateHeadingStyle.pill:
        return pw.Padding(
          padding: pad,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: onDark ? DynamicResumeTemplate._mix(accent, 0.25) : tint,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: headBold, fontSize: 9.5, letterSpacing: 1.2, color: onDark ? PdfColors.white : accent)),
          ),
        );
    }
  }

  pw.Widget summary() => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: sp(16)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading('Profile'),
          pw.Text(info.summary,
              style: pw.TextStyle(fontSize: 10.2, lineSpacing: 2.5 * _scale, color: DynamicResumeTemplate._ink)),
        ]),
      );

  List<pw.Widget> experience() => [
        heading('Experience'),
        for (final e in data.experience)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: sp(12)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(
                  child: pw.Text(e.role.isEmpty ? 'Role' : e.role,
                      style: pw.TextStyle(font: headBold, fontSize: 11.2, color: DynamicResumeTemplate._ink)),
                ),
                if (e.startDate.isNotEmpty || e.endDate.isNotEmpty)
                  pw.Text(
                    [e.startDate, e.endDate].where((s) => s.isNotEmpty).join(' – '),
                    style: const pw.TextStyle(fontSize: 9.2, color: DynamicResumeTemplate._muted),
                  ),
              ]),
              if (e.company.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.5),
                  child: pw.Text(e.company, style: pw.TextStyle(fontSize: 10, color: accent)),
                ),
              if (e.description.isNotEmpty)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: sp(4)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: bulletLines(e.description, fontSize: 9.8),
                  ),
                ),
            ]),
          ),
        pw.SizedBox(height: sp(4)),
      ];

  List<pw.Widget> education({bool onDark = false, bool compact = false}) {
    final strong = onDark ? PdfColors.white : DynamicResumeTemplate._ink;
    final soft = onDark ? DynamicResumeTemplate._mix(accent, 0.65) : DynamicResumeTemplate._muted;
    return [
      heading('Education', onDark: onDark),
      for (final e in data.education)
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: sp(9)),
          child: compact
              ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e.degree, style: pw.TextStyle(font: headBold, fontSize: 9.8, color: strong)),
                  if (e.school.isNotEmpty) pw.Text(e.school, style: pw.TextStyle(fontSize: 9, color: soft)),
                  if (e.startDate.isNotEmpty || e.endDate.isNotEmpty)
                    pw.Text([e.startDate, e.endDate].where((s) => s.isNotEmpty).join(' – '),
                        style: pw.TextStyle(fontSize: 8.6, color: soft)),
                ])
              : pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Expanded(
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(e.degree, style: pw.TextStyle(font: headBold, fontSize: 10.8, color: strong)),
                      if (e.school.isNotEmpty) pw.Text(e.school, style: pw.TextStyle(fontSize: 9.8, color: accent)),
                    ]),
                  ),
                  pw.Text([e.startDate, e.endDate].where((s) => s.isNotEmpty).join(' – '),
                      style: pw.TextStyle(fontSize: 9.2, color: soft)),
                ]),
        ),
      pw.SizedBox(height: sp(8)),
    ];
  }

  List<pw.Widget> skills({bool onDark = false, bool asList = false}) => [
        heading('Skills', onDark: onDark),
        if (asList)
          for (final s in data.skills)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: sp(3.5)),
              child: pw.Text(s,
                  style: pw.TextStyle(fontSize: 9.4, color: onDark ? PdfColors.white : DynamicResumeTemplate._ink)),
            )
        else if (spec.headingStyle == TemplateHeadingStyle.pill || spec.headingStyle == TemplateHeadingStyle.bar)
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in data.skills)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: pw.BoxDecoration(color: tint, borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(s, style: pw.TextStyle(fontSize: 9.2, color: accent)),
                ),
            ],
          )
        else
          pw.Text(data.skills.join('   ·   '),
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 3, color: DynamicResumeTemplate._ink)),
        pw.SizedBox(height: sp(8)),
      ];

  /// Sections for a single-column body, in the spec's order.
  List<pw.Widget> fullBody() {
    final out = <pw.Widget>[];
    for (final s in spec.sectionOrder) {
      switch (s) {
        case TemplateSection.summary:
          if (info.summary.isNotEmpty) out.add(summary());
        case TemplateSection.experience:
          if (data.experience.isNotEmpty) out.addAll(experience());
        case TemplateSection.education:
          if (data.education.isNotEmpty) out.addAll(education());
        case TemplateSection.skills:
          if (data.skills.isNotEmpty) out.addAll(skills());
      }
    }
    return out;
  }

  List<String> get contacts => [info.email, info.phone, info.location].where((s) => s.isNotEmpty).toList();

  // ---------------------------------------------------------------------------
  // Layouts
  // ---------------------------------------------------------------------------

  pw.MultiPage plainPage() {
    final split = spec.layoutVariant == TemplateLayoutVariant.splitHeader;
    final centered = !split && spec.headerStyle == TemplateHeaderStyle.centered;
    final align = centered ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start;

    final nameBlock = pw.Column(crossAxisAlignment: align, children: [
      pw.Text(name, style: pw.TextStyle(font: headBold, fontSize: 26, color: accent)),
      if (info.jobTitle.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(info.jobTitle,
              style: pw.TextStyle(font: headRegular, fontSize: 13, color: DynamicResumeTemplate._ink)),
        ),
    ]);

    final header = split
        ? pw.Column(children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(child: nameBlock),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  for (final c in contacts)
                    pw.Text(c, style: const pw.TextStyle(fontSize: 9.4, color: DynamicResumeTemplate._muted)),
                ],
              ),
            ]),
            pw.SizedBox(height: sp(10)),
            pw.Container(height: 3, color: accent),
            pw.SizedBox(height: sp(18)),
          ])
        : pw.Column(crossAxisAlignment: align, children: [
            nameBlock,
            if (contacts.isNotEmpty) ...[
              pw.SizedBox(height: sp(6)),
              pw.Text(contacts.join('   ·   '),
                  textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
                  style: const pw.TextStyle(fontSize: 9.6, color: DynamicResumeTemplate._muted)),
            ],
            pw.SizedBox(height: sp(10)),
            pw.Container(height: 1, color: DynamicResumeTemplate._mix(accent, 0.6)),
            pw.SizedBox(height: sp(16)),
          ]);

    return pw.MultiPage(
      margin: pw.EdgeInsets.symmetric(horizontal: 42, vertical: sp(38)),
      build: (_) => [header, ...fullBody()],
    );
  }

  pw.MultiPage bannerPage() {
    final centered = spec.headerStyle == TemplateHeaderStyle.centered;
    final align = centered ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start;
    final banner = pw.Container(
      width: double.infinity,
      color: accent,
      padding: pw.EdgeInsets.fromLTRB(42, sp(30), 42, sp(26)),
      child: pw.Column(crossAxisAlignment: align, children: [
        pw.Text(name, style: pw.TextStyle(font: headBold, fontSize: 26, color: PdfColors.white)),
        if (info.jobTitle.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(info.jobTitle,
                style: pw.TextStyle(
                    font: headRegular, fontSize: 12.5, color: DynamicResumeTemplate._mix(accent, 0.75))),
          ),
        if (contacts.isNotEmpty) ...[
          pw.SizedBox(height: sp(8)),
          pw.Text(contacts.join('   ·   '),
              textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
              style: const pw.TextStyle(fontSize: 9.4, color: PdfColors.white)),
        ],
      ]),
    );
    pw.Widget padded(pw.Widget w) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 42), child: w);
    return pw.MultiPage(
      margin: pw.EdgeInsets.only(bottom: sp(34)),
      // Pages after the first need their own top margin (the banner provides
      // it on page one).
      header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : pw.SizedBox(height: sp(34)),
      build: (_) => [banner, pw.SizedBox(height: sp(22)), ...fullBody().map(padded)],
    );
  }

  pw.MultiPage sidebarPage() {
    final left = spec.layoutVariant == TemplateLayoutVariant.sidebarLeft;
    // Left sidebar: solid accent with white text. Right sidebar: soft tint.
    final onDark = left;
    const sideWidth = 180.0;
    final sideColor = left ? accent : DynamicResumeTemplate._mix(accent, 0.9);
    final strong = onDark ? PdfColors.white : DynamicResumeTemplate._ink;
    final soft = onDark ? DynamicResumeTemplate._mix(accent, 0.7) : DynamicResumeTemplate._muted;

    pw.Widget? photo;
    if (spec.showPhoto && info.photoBase64.isNotEmpty) {
      try {
        photo = pw.ClipOval(
          child: pw.Image(pw.MemoryImage(base64Decode(info.photoBase64)), width: 84, height: 84, fit: pw.BoxFit.cover),
        );
      } catch (_) {
        photo = null;
      }
    }

    final side = pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(22, 0, 20, 0),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (photo != null) ...[photo, pw.SizedBox(height: sp(18))],
        if (contacts.isNotEmpty) ...[
          heading('Contact', onDark: onDark),
          for (final c in contacts)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: sp(5)),
              // A long email would otherwise break mid-word in the narrow
              // column, so split it onto two lines at the "@" instead.
              child: pw.Text(
                c.contains('@') && c.length > 26 ? c.replaceFirst('@', '\n@') : c,
                style: pw.TextStyle(fontSize: 9, color: strong),
              ),
            ),
          pw.SizedBox(height: sp(12)),
        ],
        if (data.skills.isNotEmpty) ...skills(onDark: onDark, asList: true),
        if (data.education.isNotEmpty) ...[
          pw.SizedBox(height: sp(4)),
          ...education(onDark: onDark, compact: true),
        ],
        if (info.location.isEmpty && contacts.isEmpty && data.skills.isEmpty && data.education.isEmpty)
          pw.Text(' ', style: pw.TextStyle(color: soft)),
      ]),
    );

    final mainChildren = <pw.Widget>[
      pw.Text(name, style: pw.TextStyle(font: headBold, fontSize: 25, color: left ? DynamicResumeTemplate._ink : accent)),
      if (info.jobTitle.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(info.jobTitle, style: pw.TextStyle(font: headRegular, fontSize: 12.5, color: accent)),
        ),
      pw.SizedBox(height: sp(20)),
      for (final s in spec.sectionOrder)
        if (s == TemplateSection.summary && info.summary.isNotEmpty)
          summary()
        else if (s == TemplateSection.experience && data.experience.isNotEmpty)
          ...experience(),
    ];
    final main = pw.Padding(
      padding: pw.EdgeInsets.fromLTRB(left ? 26 : 40, 0, left ? 40 : 26, 0),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: mainChildren),
    );

    final sidePartition = pw.Partition(width: sideWidth, child: side);
    final mainPartition = pw.Partition(child: main);

    return pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: pw.EdgeInsets.symmetric(vertical: sp(36)),
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
}
