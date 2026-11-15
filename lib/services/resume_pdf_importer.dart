import 'package:file_picker/file_picker.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import '../models/resume_data.dart';
import 'groq_service.dart';
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
  ///
  /// [onPicked] runs once a file is chosen, before it's read, so callers can
  /// show progress only after the picker closes instead of behind it.
  static Future<String?> pickAndExtractText({void Function()? onPicked}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    onPicked?.call();

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

  /// Lets the user pick a PDF and parses it into [ResumeData] via the AI
  /// extraction path ([GroqService.extractProfileFromResumeText]) instead of
  /// the regex-based [ResumeTextParser]. Intended for exports whose layout
  /// doesn't resemble a typical resume (e.g. a LinkedIn "Save to PDF" profile
  /// export), where the fixed section-header heuristics in
  /// [ResumeTextParser] are unlikely to line up. Returns null if the user
  /// cancels the file picker. Throws [ResumeImportException] under the same
  /// conditions as [pickAndExtractText], or [AiServiceException] if the AI
  /// call itself fails.
  static Future<ResumeData?> pickAndImportWithAi() async {
    final text = await pickAndExtractText();
    if (text == null) return null;
    return GroqService.extractProfileFromResumeText(text);
  }
}
