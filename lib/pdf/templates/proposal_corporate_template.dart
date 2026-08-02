import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/proposal_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// Bold cover-style title banner + numbered section headers — the
/// proposal half of the Creative/Bold visual family.
class ProposalCorporateTemplate {
  static const _violet = PdfColor.fromInt(0xFF6C5DD3);

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
              color: _violet,
              padding: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.title.isEmpty ? 'Business Proposal' : data.title,
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  if (data.date.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(data.date, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ],
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child: _party('PREPARED BY', data.senderName, data.senderCompany,
                              [data.senderEmail, data.senderPhone].where((s) => s.isNotEmpty).join('  |  '))),
                      pw.Expanded(child: _party('PREPARED FOR', data.clientName, data.clientCompany, '')),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  if (data.overview.isNotEmpty) ...[
                    _heading('01', 'OVERVIEW'),
                    pw.Text(data.overview, style: const pw.TextStyle(fontSize: 10.5)),
                    pw.SizedBox(height: 16),
                  ],
                  if (data.scopeOfWork.isNotEmpty) ...[
                    _heading('02', 'SCOPE OF WORK'),
                    ...bulletLines(data.scopeOfWork, fontSize: 10.5),
                    pw.SizedBox(height: 16),
                  ],
                  if (data.timeline.isNotEmpty) ...[
                    _heading('03', 'TIMELINE'),
                    pw.Text(data.timeline, style: const pw.TextStyle(fontSize: 10.5)),
                    pw.SizedBox(height: 16),
                  ],
                  if (data.pricing.isNotEmpty) ...[
                    _heading('04', 'PRICING'),
                    pw.Text(data.pricing, style: const pw.TextStyle(fontSize: 10.5)),
                    pw.SizedBox(height: 16),
                  ],
                  if (data.termsAndConditions.isNotEmpty) ...[
                    _heading('05', 'TERMS & CONDITIONS'),
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

  static pw.Widget _party(String label, String name, String company, String contact) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _violet)),
          pw.SizedBox(height: 3),
          if (name.isNotEmpty) pw.Text(name, style: const pw.TextStyle(fontSize: 10.5)),
          if (company.isNotEmpty) pw.Text(company, style: const pw.TextStyle(fontSize: 10)),
          if (contact.isNotEmpty) pw.Text(contact, style: const pw.TextStyle(fontSize: 9.5)),
        ],
      );

  static pw.Widget _heading(String number, String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          children: [
            pw.Text(number, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _violet)),
            pw.SizedBox(width: 8),
            pw.Text(text,
                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      );
}
