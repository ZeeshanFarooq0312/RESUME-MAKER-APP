import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Centered header with a traditional business layout. Single column,
/// plain text sections — safe for applicant tracking systems.
class ProfessionalTemplate {
  static const _accent = PdfColor.fromInt(0xFF2C5C8A);

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
              child: pw.Column(
                children: [
                  pw.Text(
                    info.fullName.isEmpty ? 'Your Name' : info.fullName,
                    style: const pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold),
                  ),
                  if (info.jobTitle.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(info.jobTitle,
                        style: const pw.TextStyle(fontSize: 11.5, color: _accent)),
                  ],
                  pw.SizedBox(height: 6),
                  pw.Text(
                    [info.email, info.phone, info.location]
                        .where((s) => s.isNotEmpty)
                        .join('  |  '),
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(height: 1.4, color: _accent),
            pw.SizedBox(height: 16),
            if (info.summary.isNotEmpty) ...[
              _heading('Professional Summary'),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
            ],
            if (data.experience.isNotEmpty) ...[
              _heading('Professional Experience'),
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
                          pw.Text(e.company,
                              style: const pw.TextStyle(
                                  fontSize: 10, color: _accent, fontWeight: pw.FontWeight.bold)),
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
              pw.SizedBox(height: 4),
            ],
            if (data.skills.isNotEmpty) ...[
              _heading('Core Skills'),
              pw.Text(data.skills.join('  •  '),
                  style: const pw.TextStyle(fontSize: 10)),
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
          style: const pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: _accent,
            letterSpacing: 1.2,
          ),
        ),
      );
}
