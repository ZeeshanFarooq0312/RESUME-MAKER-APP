import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Loads a Unicode-capable font (Lato) for PDF generation so characters
/// like em dash (—) and bullet (•) render instead of falling back to the
/// base Helvetica font, which only supports plain ASCII.
class PdfFonts {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    final cached = _theme;
    if (cached != null) return cached;

    final regularData = await rootBundle.load('assets/fonts/Lato-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Lato-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);

    final built = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [regular, bold],
    );
    _theme = built;
    return built;
  }
}
