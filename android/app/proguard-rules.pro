# pdfbox-android (used transitively by the printing/read_pdf_text plugins)
# references an optional JPEG2000 decoder class that isn't actually bundled
# or used by this app (no .jp2 images anywhere in the PDF pipeline) — R8
# fails release minification without this, since it can't resolve the
# class to verify it's genuinely unreachable at runtime.
-dontwarn com.gemalto.jp2.JP2Decoder

# google_mlkit_text_recognition's plugin bridge references the optional
# Chinese/Devanagari/Japanese/Korean script recognizer classes generically
# (to support whichever script the caller requests), even though this app
# only uses TextRecognitionScript.latin (see OcrService) and never pulled in
# those script-specific ML Kit artifacts. R8 can't verify they're
# unreachable at runtime without these.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
