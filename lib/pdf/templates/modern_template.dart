import 'dart:convert';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';

class ModernTemplate {
  static const _navy = PdfColor.fromInt(0xFF1B2430);
  static const _gold = PdfColor.fromInt(0xFFC79A4B);

  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Sidebar
            pw.Container(
              width: 170,
              height: double.infinity,
              color: _navy,
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (info.photoBase64.isNotEmpty) ...[
                    pw.Center(
                      child: pw.ClipOval(
                        child: pw.Container(
                          width: 76,
                          height: 76,
                          color: PdfColors.white,
                          child: pw.Image(
                            pw.MemoryImage(base64Decode(info.photoBase64)),
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 14),
                  ],
                  pw.Text(
                    info.fullName.isEmpty ? 'Your Name' : info.fullName,
                    style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  if (info.jobTitle.isNotEmpty)
                    pw.Text(info.jobTitle,
                        style: const pw.TextStyle(color: _gold, fontSize: 11)),
                  pw.SizedBox(height: 18),
                  _sidebarHeading('CONTACT'),
                  pw.SizedBox(height: 6),
                  if (info.email.isNotEmpty) _sidebarLine(info.email),
                  if (info.phone.isNotEmpty) _sidebarLine(info.phone),
                  if (info.location.isNotEmpty) _sidebarLine(info.location),
                  pw.SizedBox(height: 18),
                  if (data.skills.isNotEmpty) ...[
                    _sidebarHeading('SKILLS'),
                    pw.SizedBox(height: 6),
                    ...data.skills.map((s) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(s,
                              style: const pw.TextStyle(
                                  color: PdfColors.white, fontSize: 9.5)),
                        )),
                  ],
                  if (data.education.isNotEmpty) ...[
                    pw.SizedBox(height: 18),
                    _sidebarHeading('EDUCATION'),
                    pw.SizedBox(height: 6),
                    ...data.education.map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(e.degree,
                                  style: const pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 9.5,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(e.school,
                                  style: const pw.TextStyle(
                                      color: _gold, fontSize: 9)),
                              pw.Text('${e.startDate} - ${e.endDate}',
                                  style: const pw.TextStyle(
                                      color: PdfColors.grey400, fontSize: 8.5)),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
            // Main content
            pw.Expanded(
              child: pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (info.summary.isNotEmpty) ...[
                      _mainHeading('PROFILE'),
                      pw.SizedBox(height: 6),
                      pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 18),
                    ],
                    if (data.experience.isNotEmpty) ...[
                      _mainHeading('EXPERIENCE'),
                      pw.SizedBox(height: 8),
                      ...data.experience.map((e) => pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 12),
                            padding: const pw.EdgeInsets.only(left: 10),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                left: pw.BorderSide(color: _gold, width: 2),
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(e.role,
                                    style: const pw.TextStyle(
                                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                                pw.Text(
                                    '${e.company}   ${e.startDate} - ${e.endDate}',
                                    style: const pw.TextStyle(
                                        fontSize: 9, color: PdfColors.grey700)),
                                if (e.description.isNotEmpty)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(top: 4),
                                    child: pw.Text(e.description,
                                        style: const pw.TextStyle(fontSize: 9.5)),
                                  ),
                              ],
                            ),
                          )),
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

  static pw.Widget _sidebarHeading(String text) => pw.Text(
        text,
        style: const pw.TextStyle(
          color: _gold,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1,
        ),
      );

  static pw.Widget _sidebarLine(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(text,
            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
      );

  static pw.Widget _mainHeading(String text) => pw.Text(
        text,
        style: const pw.TextStyle(
          color: _navy,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1,
        ),
      );
}

