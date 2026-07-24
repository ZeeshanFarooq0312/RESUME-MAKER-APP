import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Refined single-column layout with a centered, letter-spaced header —
/// suited to senior and leadership roles. ATS-safe plain text sections.
class ExecutiveTemplate {
  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.symmetric(horizontal: 46, vertical: 42),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                (info.fullName.isEmpty ? 'Your Name' : info.fullName).toUpperCase(),
                style: const pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 3),
              ),
            ),
            if (info.jobTitle.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(info.jobTitle.toUpperCase(),
                    style: const pw.TextStyle(
                        fontSize: 10.5, color: PdfColors.grey700, letterSpacing: 2)),
              ),
            ],
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                [info.email, info.phone, info.location]
                    .where((s) => s.isNotEmpty)
                    .join('     '),
                style: const pw.TextStyle(fontSize: 9.5),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(height: 0.8, color: PdfColors.grey600),
            pw.SizedBox(height: 4),
            pw.Container(height: 0.8, color: PdfColors.grey600),
            pw.SizedBox(height: 20),
            if (info.summary.isNotEmpty) ...[
              _heading('Executive Summary'),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10.5)),
              pw.SizedBox(height: 18),
            ],
            if (data.experience.isNotEmpty) ...[
              _heading('Leadership Experience'),
              ...data.experience.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 14),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(e.company,
                            style: const pw.TextStyle(
                                fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(e.role,
                                style: const pw.TextStyle(
                                    fontSize: 10, fontStyle: pw.FontStyle.italic)),
                            pw.Text('${e.startDate} - ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 9.5)),
                          ],
                        ),
                        if (e.description.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          ...bulletLines(e.description, fontSize: 10),
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
              _heading('Core Competencies'),
              pw.Text(data.skills.join('   |   '),
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          text.toUpperCase(),
          style: const pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      );
}
