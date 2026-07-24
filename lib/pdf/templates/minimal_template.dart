import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Clean single-column layout with generous whitespace. Plain text only —
/// no tables or columns — so applicant tracking systems parse it reliably.
class MinimalTemplate {
  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              info.fullName.isEmpty ? 'Your Name' : info.fullName,
              style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            if (info.jobTitle.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(info.jobTitle,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ],
            pw.SizedBox(height: 8),
            pw.Text(
              [info.email, info.phone, info.location]
                  .where((s) => s.isNotEmpty)
                  .join('   ·   '),
              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 22),
            if (info.summary.isNotEmpty) ...[
              _heading('Summary'),
              pw.SizedBox(height: 6),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 20),
            ],
            if (data.experience.isNotEmpty) ...[
              _heading('Experience'),
              pw.SizedBox(height: 8),
              ...data.experience.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 14),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(e.role,
                            style: const pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 1),
                        pw.Text(
                            [e.company, '${e.startDate} - ${e.endDate}']
                                .where((s) => s.isNotEmpty)
                                .join('   ·   '),
                            style: const pw.TextStyle(
                                fontSize: 9.5, color: PdfColors.grey700)),
                        if (e.description.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          ...bulletLines(e.description),
                        ],
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],
            if (data.education.isNotEmpty) ...[
              _heading('Education'),
              pw.SizedBox(height: 8),
              ...data.education.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(e.degree,
                            style: const pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            [e.school, '${e.startDate} - ${e.endDate}']
                                .where((s) => s.isNotEmpty)
                                .join('   ·   '),
                            style: const pw.TextStyle(
                                fontSize: 9.5, color: PdfColors.grey700)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],
            if (data.skills.isNotEmpty) ...[
              _heading('Skills'),
              pw.SizedBox(height: 6),
              pw.Text(data.skills.join('   ·   '),
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text.toUpperCase(),
            style: const pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(height: 0.8, color: PdfColors.grey400),
        ],
      );
}
