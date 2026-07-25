import 'package:pdf/widgets.dart' as pw;
import '../../models/cover_letter_data.dart';
import '../pdf_fonts.dart';

class CoverLetterClassicTemplate {
  static Future<pw.Document> build(CoverLetterData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(48),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.fullName.isEmpty ? 'Your Name' : data.fullName,
              style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              [data.email, data.phone, data.address].where((s) => s.isNotEmpty).join('  |  '),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 24),
            if (data.date.isNotEmpty) ...[
              pw.Text(data.date, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
            ],
            if (data.recipientName.isNotEmpty)
              pw.Text(data.recipientName, style: const pw.TextStyle(fontSize: 10.5)),
            if (data.recipientTitle.isNotEmpty)
              pw.Text(data.recipientTitle, style: const pw.TextStyle(fontSize: 10.5)),
            if (data.companyName.isNotEmpty)
              pw.Text(data.companyName, style: const pw.TextStyle(fontSize: 10.5)),
            if (data.companyAddress.isNotEmpty)
              pw.Text(data.companyAddress, style: const pw.TextStyle(fontSize: 10.5)),
            pw.SizedBox(height: 20),
            if (data.jobTitle.isNotEmpty) ...[
              pw.Text('Re: Application for ${data.jobTitle}',
                  style: const pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
            ],
            pw.Text(data.salutation.isEmpty ? 'Dear Hiring Manager,' : data.salutation,
                style: const pw.TextStyle(fontSize: 10.5)),
            pw.SizedBox(height: 12),
            ..._bodyParagraphs(data.body),
            pw.SizedBox(height: 20),
            pw.Text(data.closing.isEmpty ? 'Sincerely,' : data.closing,
                style: const pw.TextStyle(fontSize: 10.5)),
            pw.SizedBox(height: 28),
            pw.Text(data.fullName, style: const pw.TextStyle(fontSize: 10.5)),
          ],
        ),
      ),
    );
    return doc;
  }

  static List<pw.Widget> _bodyParagraphs(String body) {
    final paragraphs = body.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    return paragraphs
        .map((p) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(p, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
            ))
        .toList();
  }
}
