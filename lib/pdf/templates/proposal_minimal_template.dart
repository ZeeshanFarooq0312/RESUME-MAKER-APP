import 'package:pdf/widgets.dart' as pw;
import '../../models/proposal_data.dart';
import '../pdf_fonts.dart';
import '../pdf_helpers.dart';

class ProposalMinimalTemplate {
  static Future<pw.Document> build(ProposalData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(48),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.title.isEmpty ? 'Business Proposal' : data.title,
              style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (data.date.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(data.date, style: const pw.TextStyle(fontSize: 9.5)),
            ],
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _party('From', data.senderName, data.senderCompany,
                    [data.senderEmail, data.senderPhone].where((s) => s.isNotEmpty).join('  ·  '))),
                pw.Expanded(child: _party('To', data.clientName, data.clientCompany, '')),
              ],
            ),
            pw.SizedBox(height: 20),
            if (data.overview.isNotEmpty) ...[
              _sectionTitle('Overview'),
              pw.Text(data.overview, style: const pw.TextStyle(fontSize: 9.5)),
              pw.SizedBox(height: 16),
            ],
            if (data.scopeOfWork.isNotEmpty) ...[
              _sectionTitle('Scope of Work'),
              ...bulletLines(data.scopeOfWork, fontSize: 9.5),
              pw.SizedBox(height: 16),
            ],
            if (data.timeline.isNotEmpty) ...[
              _sectionTitle('Timeline'),
              pw.Text(data.timeline, style: const pw.TextStyle(fontSize: 9.5)),
              pw.SizedBox(height: 16),
            ],
            if (data.pricing.isNotEmpty) ...[
              _sectionTitle('Pricing'),
              pw.Text(data.pricing, style: const pw.TextStyle(fontSize: 9.5)),
              pw.SizedBox(height: 16),
            ],
            if (data.termsAndConditions.isNotEmpty) ...[
              _sectionTitle('Terms & Conditions'),
              pw.Text(data.termsAndConditions, style: const pw.TextStyle(fontSize: 9.5)),
            ],
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
              style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          if (name.isNotEmpty) pw.Text(name, style: const pw.TextStyle(fontSize: 9.5)),
          if (company.isNotEmpty) pw.Text(company, style: const pw.TextStyle(fontSize: 9)),
          if (contact.isNotEmpty) pw.Text(contact, style: const pw.TextStyle(fontSize: 8.5)),
        ],
      );

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
        ),
      );
}
