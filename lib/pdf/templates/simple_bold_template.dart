import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Bold section headers with a thin colored rule beneath. Single column,
/// plain text — a safe, readable default that parses cleanly in ATS.
class SimpleBoldTemplate {
  static const _accent = PdfColor.fromInt(0xFFB0413E);

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
              style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            if (info.jobTitle.isNotEmpty)
              pw.Text(info.jobTitle, style: const pw.TextStyle(fontSize: 11.5)),
            pw.SizedBox(height: 6),
            pw.Text(
              [info.email, info.phone, info.location]
                  .where((s) => s.isNotEmpty)
                  .join('   ·   '),
              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 18),
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
                            pw.Text(
                                '${e.role}${e.company.isNotEmpty ? " — ${e.company}" : ""}',
                                style: const pw.TextStyle(
                                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${e.startDate} - ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 9.5)),
                          ],
                        ),
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
                        pw.Text(
                            '${e.degree}${e.school.isNotEmpty ? " — ${e.school}" : ""}',
                            style: const pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${e.startDate} - ${e.endDate}',
                            style: const pw.TextStyle(fontSize: 9.5)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 4),
            ],
            if (data.skills.isNotEmpty) ...[
              _heading('Skills'),
              pw.Text(data.skills.join('  •  '),
                  style: const pw.TextStyle(fontSize: 10.5)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              text.toUpperCase(),
              style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Container(height: 2, width: 28, color: _accent),
          ],
        ),
      );
}
