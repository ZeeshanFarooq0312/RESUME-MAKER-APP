import 'package:pdf/widgets.dart' as pw;
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';

class ClassicTemplate {
  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              info.fullName.isEmpty ? 'Your Name' : info.fullName,
              style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            if (info.jobTitle.isNotEmpty)
              pw.Text(info.jobTitle, style: const pw.TextStyle(fontSize: 13)),
            pw.SizedBox(height: 6),
            pw.Text(
              [info.email, info.phone, info.location]
                  .where((s) => s.isNotEmpty)
                  .join('  |  '),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(thickness: 1, height: 20),

            if (info.summary.isNotEmpty) ...[
              _sectionTitle('SUMMARY'),
              pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10.5)),
              pw.SizedBox(height: 14),
            ],

            if (data.experience.isNotEmpty) ...[
              _sectionTitle('EXPERIENCE'),
              ...data.experience.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('${e.role}${e.company.isNotEmpty ? " — ${e.company}" : ""}',
                                style: const pw.TextStyle(
                                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${e.startDate} - ${e.endDate}',
                                style: const pw.TextStyle(fontSize: 9.5)),
                          ],
                        ),
                        if (e.description.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 3),
                            child: pw.Text(e.description,
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],

            if (data.education.isNotEmpty) ...[
              _sectionTitle('EDUCATION'),
              ...data.education.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('${e.degree}${e.school.isNotEmpty ? " — ${e.school}" : ""}',
                            style: const pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${e.startDate} - ${e.endDate}',
                            style: const pw.TextStyle(fontSize: 9.5)),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 6),
            ],

            if (data.skills.isNotEmpty) ...[
              _sectionTitle('SKILLS'),
              pw.Text(data.skills.join('  •  '),
                  style: const pw.TextStyle(fontSize: 10.5)),
            ],
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: const pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      );
}
