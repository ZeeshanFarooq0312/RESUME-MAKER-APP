import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/proposal_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

class ProposalModernTemplate {
  static const _navy = PdfColor.fromInt(0xFF1B2430);
  static const _gold = PdfColor.fromInt(0xFFC79A4B);

  static Future<pw.Document> build(ProposalData data) async {
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
                    data.title.isEmpty ? 'Business Proposal' : data.title,
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  if (data.date.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(data.date, style: const pw.TextStyle(color: _gold, fontSize: 9.5)),
                  ],
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child: _party('Prepared By', data.senderName, data.senderCompany,
                              [data.senderEmail, data.senderPhone]
                                  .where((s) => s.isNotEmpty)
                                  .join('  |  '))),
                      pw.Expanded(
                          child: _party('Prepared For', data.clientName, data.clientCompany, '')),
                    ],
                  ),
                  pw.SizedBox(height: 18),
                  if (data.overview.isNotEmpty) ...[
                    _sectionTitle('OVERVIEW'),
                    pw.Text(data.overview, style: const pw.TextStyle(fontSize: 10.5)),
                    pw.SizedBox(height: 14),
                  ],
                  if (data.scopeOfWork.isNotEmpty) ...[
                    _sectionTitle('SCOPE OF WORK'),
                    ...bulletLines(data.scopeOfWork, fontSize: 10.5),
                    pw.SizedBox(height: 14),
                  ],
                  if (data.timeline.isNotEmpty) ...[
                    _sectionTitle('TIMELINE'),
                    pw.Text(data.timeline, style: const pw.TextStyle(fontSize: 10.5)),
                    pw.SizedBox(height: 14),
                  ],
                  if (data.pricing.isNotEmpty) ...[
                    _sectionTitle('PRICING'),
                    pw.Text(data.pricing, style: const pw.TextStyle(fontSize: 10.5)),
                    pw.SizedBox(height: 14),
                  ],
                  if (data.termsAndConditions.isNotEmpty) ...[
                    _sectionTitle('TERMS & CONDITIONS'),
                    pw.Text(data.termsAndConditions, style: const pw.TextStyle(fontSize: 10.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _party(String label, String name, String company, String contact) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.SizedBox(height: 3),
          if (name.isNotEmpty) pw.Text(name, style: const pw.TextStyle(fontSize: 10.5)),
          if (company.isNotEmpty) pw.Text(company, style: const pw.TextStyle(fontSize: 10)),
          if (contact.isNotEmpty) pw.Text(contact, style: const pw.TextStyle(fontSize: 9.5)),
        ],
      );

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: const pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 1),
        ),
      );
}
