import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';

/// Each experience entry gets a small violet dot + connecting left border
/// (a per-entry "timeline" segment) instead of plain text — the one new
/// resume template with a genuinely different structural gimmick.
class TimelineTemplate {
  static const _violet = PdfColor.fromInt(0xFF6C5DD3);

  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              info.fullName.isEmpty ? 'Your Name' : info.fullName,
              style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            if (info.jobTitle.isNotEmpty)
              pw.Text(info.jobTitle, style: const pw.TextStyle(fontSize: 12, color: _violet)),
            pw.SizedBox(height: 6),
            pw.Text(
              [info.email, info.phone, info.location].where((s) => s.isNotEmpty).join('   •   '),
              style: const pw.TextStyle(fontSize: 9.5),
            ),
            pw.SizedBox(height: 16),
            if (info.summary.isNotEmpty) ...[
              _heading('SUMMARY'),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10.5)),
              pw.SizedBox(height: 16),
            ],
            if (data.experience.isNotEmpty) ...[
              _heading('EXPERIENCE'),
              pw.SizedBox(height: 8),
              ...data.experience.map(_timelineEntry),
              pw.SizedBox(height: 8),
            ],
            if (data.education.isNotEmpty) ...[
              _heading('EDUCATION'),
              pw.SizedBox(height: 8),
              ...data.education.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('${e.degree}${e.school.isNotEmpty ? " — ${e.school}" : ""}',
                            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${e.startDate} - ${e.endDate}',
                            style: const pw.TextStyle(fontSize: 9.5)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],
            if (data.skills.isNotEmpty) ...[
              _heading('SKILLS'),
              pw.SizedBox(height: 8),
              pw.Text(data.skills.join('  •  '), style: const pw.TextStyle(fontSize: 10.5)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _timelineEntry(ExperienceEntry e) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Stack(
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(left: 4),
              padding: const pw.EdgeInsets.only(left: 16, top: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: _violet, width: 1.5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFEDEAFB),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text('${e.startDate} - ${e.endDate}',
                        style: const pw.TextStyle(fontSize: 8.5, color: _violet)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('${e.role}${e.company.isNotEmpty ? " — ${e.company}" : ""}',
                      style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  if (e.description.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3),
                      child: pw.Text(e.description, style: const pw.TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
            pw.Positioned(
              left: 0,
              top: 3,
              child: pw.Container(
                width: 9,
                height: 9,
                decoration: const pw.BoxDecoration(color: _violet, shape: pw.BoxShape.circle),
              ),
            ),
          ],
        ),
      );

  static pw.Widget _heading(String text) => pw.Text(
        text,
        style: const pw.TextStyle(
            fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1, color: _violet),
      );
}
