import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/resume_data.dart';
import '../../models/template_style_spec.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Renders a resume from a [TemplateStyleSpec] instead of a hand-written
/// per-style file — the flexible renderer behind "describe your own
/// template". Every branch below mirrors a layout/color/spacing choice
/// already proven in the app's 12 hand-built templates (see classic_template
/// .dart for the plain-header layout this generalizes, and
/// creative_template.dart for the banner-header layout), parameterized
/// instead of duplicated per style.
class DynamicResumeTemplate {
  static const _palette = <TemplateAccentColor, PdfColor>{
    TemplateAccentColor.violet: PdfColor.fromInt(0xFF6C5DD3),
    TemplateAccentColor.forestGreen: PdfColor.fromInt(0xFF1F6F54),
    TemplateAccentColor.navyBlue: PdfColor.fromInt(0xFF2C5C8A),
    TemplateAccentColor.burgundy: PdfColor.fromInt(0xFFB0413E),
    TemplateAccentColor.gold: PdfColor.fromInt(0xFFC79A4B),
    TemplateAccentColor.charcoal: PdfColor.fromInt(0xFF221F35),
    TemplateAccentColor.teal: PdfColor.fromInt(0xFF1A6B70),
    TemplateAccentColor.slate: PdfColor.fromInt(0xFF1B2430),
  };

  // Light tint of the accent, blended toward white — used for section
  // heading backgrounds/skill chips in the banner layout, mirroring
  // creative_template.dart's _violetLight convention.
  static PdfColor _tint(PdfColor c) => PdfColor(
        c.red + (1 - c.red) * 0.88,
        c.green + (1 - c.green) * 0.88,
        c.blue + (1 - c.blue) * 0.88,
      );

  static Future<pw.Document> build(ResumeData data, TemplateStyleSpec spec) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;
    final accent = _palette[spec.accentColor]!;
    final tint = _tint(accent);

    final scale = switch (spec.density) {
      TemplateDensity.compact => 0.85,
      TemplateDensity.comfortable => 1.0,
      TemplateDensity.spacious => 1.2,
    };
    double sp(double base) => base * scale;

    pw.Widget heading(String text) => pw.Padding(
          padding: pw.EdgeInsets.only(bottom: sp(6)),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
              color: spec.layoutVariant == TemplateLayoutVariant.bannerHeader ? accent : null,
            ),
          ),
        );

    pw.Widget section(TemplateSection kind) {
      switch (kind) {
        case TemplateSection.summary:
          if (info.summary.isEmpty) return pw.SizedBox();
          return pw.Padding(
            padding: pw.EdgeInsets.only(bottom: sp(14)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                heading('SUMMARY'),
                pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10.5)),
              ],
            ),
          );
        case TemplateSection.experience:
          if (data.experience.isEmpty) return pw.SizedBox();
          return pw.Padding(
            padding: pw.EdgeInsets.only(bottom: sp(6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                heading('EXPERIENCE'),
                ...data.experience.map((e) => pw.Padding(
                      padding: pw.EdgeInsets.only(bottom: sp(10)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('${e.role}${e.company.isNotEmpty ? " — ${e.company}" : ""}',
                                  style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Text('${e.startDate} - ${e.endDate}',
                                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                            ],
                          ),
                          if (e.description.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 3),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: bulletLines(e.description, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    )),
              ],
            ),
          );
        case TemplateSection.education:
          if (data.education.isEmpty) return pw.SizedBox();
          return pw.Padding(
            padding: pw.EdgeInsets.only(bottom: sp(6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                heading('EDUCATION'),
                ...data.education.map((e) => pw.Padding(
                      padding: pw.EdgeInsets.only(bottom: sp(8)),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${e.degree}${e.school.isNotEmpty ? " — ${e.school}" : ""}',
                              style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text('${e.startDate} - ${e.endDate}',
                              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                        ],
                      ),
                    )),
              ],
            ),
          );
        case TemplateSection.skills:
          if (data.skills.isEmpty) return pw.SizedBox();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              heading('SKILLS'),
              spec.layoutVariant == TemplateLayoutVariant.bannerHeader
                  ? pw.Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.skills
                          .map((s) => pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: pw.BoxDecoration(color: tint, borderRadius: pw.BorderRadius.circular(4)),
                                child: pw.Text(s, style: pw.TextStyle(fontSize: 9.5, color: accent)),
                              ))
                          .toList(),
                    )
                  : pw.Text(data.skills.join('  •  '), style: const pw.TextStyle(fontSize: 10.5)),
            ],
          );
      }
    }

    final contactLine = [info.email, info.phone, info.location].where((s) => s.isNotEmpty).join('   •   ');

    pw.Widget header;
    switch (spec.layoutVariant) {
      case TemplateLayoutVariant.plainHeader:
        final align = spec.headerStyle == TemplateHeaderStyle.centered
            ? pw.CrossAxisAlignment.center
            : pw.CrossAxisAlignment.start;
        header = pw.Column(
          crossAxisAlignment: align,
          children: [
            pw.Text(
              info.fullName.isEmpty ? 'Your Name' : info.fullName,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: accent),
            ),
            if (info.jobTitle.isNotEmpty)
              pw.Text(info.jobTitle, style: const pw.TextStyle(fontSize: 13)),
            pw.SizedBox(height: 6),
            pw.Text(contactLine, style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(thickness: 1, height: 20),
          ],
        );
        break;
      case TemplateLayoutVariant.bannerHeader:
        final align = spec.headerStyle == TemplateHeaderStyle.centered
            ? pw.CrossAxisAlignment.center
            : pw.CrossAxisAlignment.start;
        header = pw.Container(
          width: double.infinity,
          color: accent,
          padding: pw.EdgeInsets.fromLTRB(36, sp(32), 36, sp(28)),
          child: pw.Column(
            crossAxisAlignment: align,
            children: [
              pw.Text(
                info.fullName.isEmpty ? 'Your Name' : info.fullName,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              if (info.jobTitle.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(info.jobTitle, style: pw.TextStyle(color: tint, fontSize: 12)),
              ],
              pw.SizedBox(height: 8),
              pw.Text(contactLine, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5)),
            ],
          ),
        );
        break;
    }

    final bodyPadding = spec.layoutVariant == TemplateLayoutVariant.bannerHeader
        ? pw.EdgeInsets.all(sp(36))
        : const pw.EdgeInsets.all(0);

    doc.addPage(
      pw.Page(
        margin: spec.layoutVariant == TemplateLayoutVariant.bannerHeader
            ? pw.EdgeInsets.zero
            : const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            header,
            pw.Padding(
              padding: bodyPadding,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [for (final s in spec.sectionOrder) section(s)],
              ),
            ),
          ],
        ),
      ),
    );
    return doc;
  }
}
