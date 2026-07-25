import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../models/resume_data.dart';

/// On-device resume translation via ML Kit. Translation itself runs fully
/// offline once a language's model is downloaded — the only network use in
/// this app is that one-time per-language model download.
///
/// Scoped to Latin-script languages for now: the bundled PDF font (Lato)
/// can't render Arabic/Hindi/CJK/Cyrillic glyphs, so offering those languages
/// here would silently produce a broken-looking PDF. Non-Latin scripts need
/// extra bundled fonts (and RTL layout for Arabic/Urdu/Hebrew) as a follow-up.
class TranslationService {
  static const supportedLanguages = <TranslateLanguage>[
    TranslateLanguage.spanish,
    TranslateLanguage.french,
    TranslateLanguage.german,
    TranslateLanguage.italian,
    TranslateLanguage.portuguese,
    TranslateLanguage.dutch,
    TranslateLanguage.turkish,
    TranslateLanguage.indonesian,
    TranslateLanguage.polish,
    TranslateLanguage.romanian,
    TranslateLanguage.swedish,
    TranslateLanguage.danish,
    TranslateLanguage.norwegian,
    TranslateLanguage.finnish,
    TranslateLanguage.vietnamese,
    TranslateLanguage.czech,
    TranslateLanguage.slovak,
    TranslateLanguage.croatian,
    TranslateLanguage.catalan,
  ];

  static const _labels = <TranslateLanguage, String>{
    TranslateLanguage.spanish: 'Spanish',
    TranslateLanguage.french: 'French',
    TranslateLanguage.german: 'German',
    TranslateLanguage.italian: 'Italian',
    TranslateLanguage.portuguese: 'Portuguese',
    TranslateLanguage.dutch: 'Dutch',
    TranslateLanguage.turkish: 'Turkish',
    TranslateLanguage.indonesian: 'Indonesian',
    TranslateLanguage.polish: 'Polish',
    TranslateLanguage.romanian: 'Romanian',
    TranslateLanguage.swedish: 'Swedish',
    TranslateLanguage.danish: 'Danish',
    TranslateLanguage.norwegian: 'Norwegian',
    TranslateLanguage.finnish: 'Finnish',
    TranslateLanguage.vietnamese: 'Vietnamese',
    TranslateLanguage.czech: 'Czech',
    TranslateLanguage.slovak: 'Slovak',
    TranslateLanguage.croatian: 'Croatian',
    TranslateLanguage.catalan: 'Catalan',
  };

  static String labelFor(TranslateLanguage language) => _labels[language] ?? language.name;

  static final _modelManager = OnDeviceTranslatorModelManager();

  /// Whether both the English and [target] models are already downloaded.
  static Future<bool> areModelsReady(TranslateLanguage target) async {
    final english = await _modelManager.isModelDownloaded(TranslateLanguage.english.bcpCode);
    final other = await _modelManager.isModelDownloaded(target.bcpCode);
    return english && other;
  }

  /// Downloads the English + [target] models if not already present. Only
  /// needs internet the first time for a given language.
  static Future<void> ensureModelsReady(TranslateLanguage target) async {
    for (final bcp in {TranslateLanguage.english.bcpCode, target.bcpCode}) {
      if (!await _modelManager.isModelDownloaded(bcp)) {
        await _modelManager.downloadModel(bcp);
      }
    }
  }

  /// Returns a translated copy of [data]; the original is left untouched so
  /// the caller can revert to it.
  static Future<ResumeData> translateResumeData(ResumeData data, TranslateLanguage target) async {
    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: target,
    );
    try {
      Future<String> t(String text) =>
          text.trim().isEmpty ? Future.value(text) : translator.translateText(text);

      final translated = ResumeData.fromJson(data.toJson());
      translated.personalInfo.jobTitle = await t(data.personalInfo.jobTitle);
      translated.personalInfo.summary = await t(data.personalInfo.summary);
      for (var i = 0; i < translated.experience.length; i++) {
        translated.experience[i].role = await t(data.experience[i].role);
        translated.experience[i].company = await t(data.experience[i].company);
        translated.experience[i].description = await t(data.experience[i].description);
      }
      for (var i = 0; i < translated.education.length; i++) {
        translated.education[i].degree = await t(data.education[i].degree);
        translated.education[i].school = await t(data.education[i].school);
      }
      for (var i = 0; i < translated.skills.length; i++) {
        translated.skills[i] = await t(data.skills[i]);
      }
      return translated;
    } finally {
      await translator.close();
    }
  }
}
