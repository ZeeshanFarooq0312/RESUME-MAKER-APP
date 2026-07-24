import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Puts skills up front as a scannable, plain-text line — geared toward
/// engineering / IT roles where keyword matching matters most for ATS.
class TechnicalTemplate {
  static const _accent = PdfColor.fromInt(0xFF1F6F54);

  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              info.fullName.isEmpty ? 'Your Name' : info.fullName,
              style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            if (info.jobTitle.isNotEmpty)
              pw.Text(info.jobTitle,
                  style: pw.TextStyle(fontSize: 11, color: _accent, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(
              [info.email, info.phone, info.location]
                  .where((s) => s.isNotEmpty)
                  .join('   ·   '),
              style: const pw.TextStyle(fontSize: 9.5),
            ),
            pw.SizedBox(height: 14),
            if (data.skills.isNotEmpty) ...[
              _heading('Technical Skills'),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(data.skills.join('  •  '),
                    style: const pw.TextStyle(fontSize: 9.5)),
              ),
              pw.SizedBox(height: 16),
            ],
            if (info.summary.isNotEmpty) ...[
              _heading('Summary'),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
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
                            pw.Text(e.role,
                                style: const pw.TextStyle(
                                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${e.startDate} - ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 9.5)),
                          ],
                        ),
                        if (e.company.isNotEmpty)
                          pw.Text(e.company, style: const pw.TextStyle(fontSize: 9.5)),
                        if (e.description.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          ...bulletLines(e.description),
                        ],
                      ],
                    ),
                  )),
              pw.SizedBox(height: 4),
            ],
            if (data.education.isNotEmpty) ...[
              _heading('Education'),
              ...data.education.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(e.degree,
                                style: const pw.TextStyle(
                                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            if (e.school.isNotEmpty)
                              pw.Text(e.school, style: const pw.TextStyle(fontSize: 9.5)),
                          ],
                        ),
                        pw.Text('${e.startDate} - ${e.endDate}',
                            style: const pw.TextStyle(fontSize: 9.5)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: _accent,
            letterSpacing: 1.2,
          ),
        ),
      );
}
