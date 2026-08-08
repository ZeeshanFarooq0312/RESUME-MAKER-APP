import 'package:file_picker/file_picker.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import '../models/resume_data.dart';
import 'resume_text_parser.dart';

class ResumeImportException implements Exception {
  final String message;
  ResumeImportException(this.message);
}

class ResumePdfImporter {
  /// Lets the user pick a PDF and returns its raw extracted text. Returns
  /// null if the user cancels the file picker. Throws
  /// [ResumeImportException] if the PDF has no extractable text (e.g. a
  /// scanned/image-only PDF) or can't be read.
  static Future<String?> pickAndExtractText() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;

    String text;
    try {
      text = await ReadPdfText.getPDFtext(path);
    } catch (_) {
      throw ResumeImportException(
          "We couldn't read that PDF. Please make sure it isn't password-protected and try again.");
    }

    if (text.trim().isEmpty) {
      throw ResumeImportException(
          "We couldn't find any text in that PDF. It may be a scanned image — try entering your details manually.");
    }

    return text;
  }

  /// Lets the user pick a PDF and parses it into [ResumeData] via the local
  /// regex-based [ResumeTextParser]. Returns null if the user cancels the
  /// file picker. Throws [ResumeImportException] under the same conditions
  /// as [pickAndExtractText].
  static Future<ResumeData?> pickAndImport() async {
    final text = await pickAndExtractText();
    if (text == null) return null;
    return ResumeTextParser.parse(text);
  }
}
