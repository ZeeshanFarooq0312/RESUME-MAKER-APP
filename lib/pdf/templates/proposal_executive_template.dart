import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/proposal_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

/// The first two-column proposal layout: a narrow dark sidebar for parties
/// and date, main column for overview/scope/timeline/pricing/terms.
class ProposalExecutiveTemplate {
  static const _ink = PdfColor.fromInt(0xFF221F35);
  static const _violet = PdfColor.fromInt(0xFF6C5DD3);

  static Future<pw.Document> build(ProposalData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());

    doc.addPage(
      pw.Page(
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 160,
              height: double.infinity,
              color: _ink,
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.title.isEmpty ? 'Business Proposal' : data.title,
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold),
                  ),
                  if (data.date.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(data.date, style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                  ],
                  pw.SizedBox(height: 22),
                  _sidebarLabel('PREPARED BY'),
                  pw.SizedBox(height: 4),
                  if (data.senderName.isNotEmpty) _sidebarLine(data.senderName),
                  if (data.senderCompany.isNotEmpty) _sidebarLine(data.senderCompany),
                  if (data.senderEmail.isNotEmpty) _sidebarLine(data.senderEmail),
                  if (data.senderPhone.isNotEmpty) _sidebarLine(data.senderPhone),
                  pw.SizedBox(height: 18),
                  _sidebarLabel('PREPARED FOR'),
                  pw.SizedBox(height: 4),
                  if (data.clientName.isNotEmpty) _sidebarLine(data.clientName),
                  if (data.clientCompany.isNotEmpty) _sidebarLine(data.clientCompany),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.all(28),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (data.overview.isNotEmpty) ...[
                      _heading('Overview'),
                      pw.Text(data.overview, style: const pw.TextStyle(fontSize: 10.5)),
                      pw.SizedBox(height: 16),
                    ],
                    if (data.scopeOfWork.isNotEmpty) ...[
                      _heading('Scope of Work'),
                      ...bulletLines(data.scopeOfWork, fontSize: 10.5),
                      pw.SizedBox(height: 16),
                    ],
                    if (data.timeline.isNotEmpty) ...[
                      _heading('Timeline'),
                      pw.Text(data.timeline, style: const pw.TextStyle(fontSize: 10.5)),
                      pw.SizedBox(height: 16),
                    ],
                    if (data.pricing.isNotEmpty) ...[
                      _heading('Pricing'),
                      pw.Text(data.pricing, style: const pw.TextStyle(fontSize: 10.5)),
                      pw.SizedBox(height: 16),
                    ],
                    if (data.termsAndConditions.isNotEmpty) ...[
                      _heading('Terms & Conditions'),
                      pw.Text(data.termsAndConditions, style: const pw.TextStyle(fontSize: 10.5)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _sidebarLabel(String text) => pw.Text(
        text,
        style: const pw.TextStyle(color: _violet, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
      );

  static pw.Widget _sidebarLine(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(text, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
      );

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          text,
          style: const pw.TextStyle(color: _ink, fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
        ),
      );
}
