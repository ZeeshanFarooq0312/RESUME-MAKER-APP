import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/cover_letter_data.dart';
import '../pdf_fonts.dart';

class CoverLetterModernTemplate {
  static const _navy = PdfColor.fromInt(0xFF1B2430);
  static const _gold = PdfColor.fromInt(0xFFC79A4B);

  static Future<pw.Document> build(CoverLetterData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());

    doc.addPage(
      pw.Page(
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              color: _navy,
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.fullName.isEmpty ? 'Your Name' : data.fullName,
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    [data.email, data.phone, data.address].where((s) => s.isNotEmpty).join('   ·   '),
                    style: const pw.TextStyle(color: _gold, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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
                        style: const pw.TextStyle(
                            fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _navy)),
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
