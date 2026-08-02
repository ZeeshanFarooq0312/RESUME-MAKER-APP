# pdfbox-android (used transitively by the printing/read_pdf_text plugins)
# references an optional JPEG2000 decoder class that isn't actually bundled
# or used by this app (no .jp2 images anywhere in the PDF pipeline) — R8
# fails release minification without this, since it can't resolve the
# class to verify it's genuinely unreachable at runtime.
-dontwarn com.gemalto.jp2.JP2Decoder
