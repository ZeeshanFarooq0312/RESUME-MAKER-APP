import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Single-column, black & white layout with centered header and
/// horizontal-rule section headings — the classic "Harvard résumé" format.
class HarvardTemplate {
  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                (info.fullName.isEmpty ? 'Your Name' : info.fullName).toUpperCase(),
                style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                [info.phone, info.email, info.location]
                    .where((s) => s.isNotEmpty)
                    .join('   |   '),
                style: const pw.TextStyle(fontSize: 9.5),
              ),
            ),
            pw.SizedBox(height: 10),

            if (info.summary.isNotEmpty) ...[
              _heading('Summary'),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
            ],

            if (data.education.isNotEmpty) ...[
              _heading('Education'),
              ...data.education.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(e.school,
                                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${e.startDate} - ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        if (e.degree.isNotEmpty)
                          pw.Text(e.degree,
                              style: const pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],

            if (data.experience.isNotEmpty) ...[
              _heading('Experience'),
              ...data.experience.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(e.company,
                                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${e.startDate} - ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        if (e.role.isNotEmpty)
                          pw.Text(e.role,
                              style: const pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic)),
                        if (e.description.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          ...bulletLines(e.description),
                        ],
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],

            if (data.skills.isNotEmpty) ...[
              _heading('Technical Skills'),
              pw.Text(data.skills.join(', '), style: const pw.TextStyle(fontSize: 9.5)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),
          ],
        ),
      );
}
