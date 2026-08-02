import 'dart:convert';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../models/resume_data.dart';
import '../pdf_fonts.dart';

/// Full-width colored header banner, single-column body below with section
/// headings rendered as colored background bars — a bolder, more visual
/// take than Classic, using the app's own brand violet as its accent.
class CreativeTemplate {
  static const _violet = PdfColor.fromInt(0xFF6C5DD3);
  static const _violetLight = PdfColor.fromInt(0xFFEDEAFB);

  static Future<pw.Document> build(ResumeData data) async {
    final doc = pw.Document(theme: await PdfFonts.theme());
    final info = data.personalInfo;

    doc.addPage(
      pw.Page(
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              color: _violet,
              padding: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (info.photoBase64.isNotEmpty) ...[
                    pw.ClipOval(
                      child: pw.Container(
                        width: 70,
                        height: 70,
                        color: PdfColors.white,
                        child: pw.Image(
                          pw.MemoryImage(base64Decode(info.photoBase64)),
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 18),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          info.fullName.isEmpty ? 'Your Name' : info.fullName,
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold),
                        ),
                        if (info.jobTitle.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(info.jobTitle,
                              style: const pw.TextStyle(color: _violetLight, fontSize: 12)),
                        ],
                        pw.SizedBox(height: 8),
                        pw.Text(
                          [info.email, info.phone, info.location]
                              .where((s) => s.isNotEmpty)
                              .join('   •   '),
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(36),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (info.summary.isNotEmpty) ...[
                    _heading('SUMMARY'),
                    pw.SizedBox(height: 8),
                    pw.Text(info.summary, style: const pw.TextStyle(fontSize: 10.5)),
                    pw.SizedBox(height: 18),
                  ],
                  if (data.experience.isNotEmpty) ...[
                    _heading('EXPERIENCE'),
                    pw.SizedBox(height: 10),
                    ...data.experience.map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 12),
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
                                      style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                                ],
                              ),
                              if (e.description.isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 3),
                                  child: pw.Text(e.description, style: const pw.TextStyle(fontSize: 10)),
                                ),
                            ],
                          ),
                        )),
                    pw.SizedBox(height: 6),
                  ],
                  if (data.education.isNotEmpty) ...[
                    _heading('EDUCATION'),
                    pw.SizedBox(height: 10),
                    ...data.education.map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('${e.degree}${e.school.isNotEmpty ? " — ${e.school}" : ""}',
                                  style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Text('${e.startDate} - ${e.endDate}',
                                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                            ],
                          ),
                        )),
                    pw.SizedBox(height: 6),
                  ],
                  if (data.skills.isNotEmpty) ...[
                    _heading('SKILLS'),
                    pw.SizedBox(height: 10),
                    pw.Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.skills
                          .map((s) => pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: pw.BoxDecoration(
                                  color: _violetLight,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(s,
                                    style: const pw.TextStyle(fontSize: 9.5, color: _violet)),
                              ))
                          .toList(),
                    ),
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

  static pw.Widget _heading(String text) => pw.Container(
        width: double.infinity,
        color: _violetLight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: pw.Text(
          text,
          style: const pw.TextStyle(
              color: _violet, fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
        ),
      );
}
