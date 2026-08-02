import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';

/// Centered, letter-spaced header and quiet uppercase section headings with
/// a thin bottom rule — a restrained, editorial look, distinct from
/// Classic's plain left-aligned layout.
class ElegantTemplate {
  static const _ink = PdfColor.fromInt(0xFF221F35);

  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    (info.fullName.isEmpty ? 'YOUR NAME' : info.fullName).toUpperCase(),
                    style: const pw.TextStyle(fontSize: 22, letterSpacing: 3, fontWeight: pw.FontWeight.bold),
                  ),
                  if (info.jobTitle.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(info.jobTitle.toUpperCase(),
                        style: const pw.TextStyle(fontSize: 10, letterSpacing: 2, color: PdfColors.grey700)),
                  ],
                  pw.SizedBox(height: 10),
                  pw.Text(
                    [info.email, info.phone, info.location].where((s) => s.isNotEmpty).join('   |   '),
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Divider(thickness: 0.75, color: PdfColors.grey400),
            pw.SizedBox(height: 18),
            if (info.summary.isNotEmpty) ...[
              _heading('Summary'),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5)),
              pw.SizedBox(height: 18),
            ],
            if (data.experience.isNotEmpty) ...[
              _heading('Experience'),
              ...data.experience.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('${e.role}${e.company.isNotEmpty ? ", ${e.company}" : ""}',
                                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${e.startDate} – ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                        if (e.description.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Text(e.description,
                                style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4)),
                          ),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],
            if (data.education.isNotEmpty) ...[
              _heading('Education'),
              ...data.education.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('${e.degree}${e.school.isNotEmpty ? ", ${e.school}" : ""}',
                            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${e.startDate} – ${e.endDate}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],
            if (data.skills.isNotEmpty) ...[
              _heading('Skills'),
              pw.Text(data.skills.join('   ·   '), style: const pw.TextStyle(fontSize: 10.5)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              text.toUpperCase(),
              style: const pw.TextStyle(fontSize: 10.5, letterSpacing: 2, color: _ink, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 0.75, width: 28, color: _ink),
            pw.SizedBox(height: 8),
          ],
        ),
      );
}
