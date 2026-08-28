import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Extracts text from a photo entirely on-device via Google ML Kit — same
/// on-device family as TranslationService, so nothing in the photo ever
/// leaves the phone. Used to let the user photograph a job posting (a
/// printout, a screen, a poster) instead of retyping it into the AI resume
/// generator's job-description field.
class OcrService {
  const OcrService._();

  static Future<String> extractText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      // Collapse the occasional run of blank lines ML Kit leaves between
      // paragraphs so the pasted-in text reads cleanly.
      return result.text.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    } finally {
      await recognizer.close();
    }
  }
}
