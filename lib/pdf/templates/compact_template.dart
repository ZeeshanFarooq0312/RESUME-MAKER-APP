import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Dense single-column layout that fits more content per page — for
/// candidates with a long history. Plain text, no tables, ATS-safe.
class CompactTemplate {
  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              info.fullName.isEmpty ? 'Your Name' : info.fullName,
              style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              [
                info.jobTitle,
                info.email,
                info.phone,
                info.location,
              ].where((s) => s.isNotEmpty).join('   ·   '),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            if (info.summary.isNotEmpty) ...[
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 9.5)),
              pw.SizedBox(height: 10),
            ],
            if (data.experience.isNotEmpty) ...[
              _heading('Experience'),
              ...data.experience.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 7),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                                '${e.role}${e.company.isNotEmpty ? " - ${e.company}" : ""}',
                                style: const pw.TextStyle(
                                    fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${e.startDate} - ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                        if (e.description.isNotEmpty)
                          ...bulletLines(e.description, fontSize: 9),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 4),
            ],
            if (data.education.isNotEmpty) ...[
              _heading('Education'),
              ...data.education.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            '${e.degree}${e.school.isNotEmpty ? " - ${e.school}" : ""}',
                            style: const pw.TextStyle(
                                fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${e.startDate} - ${e.endDate}',
                            style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 4),
            ],
            if (data.skills.isNotEmpty) ...[
              _heading('Skills'),
              pw.Text(data.skills.join(', '),
                  style: const pw.TextStyle(fontSize: 9.5)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          text.toUpperCase(),
          style: const pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      );
}
