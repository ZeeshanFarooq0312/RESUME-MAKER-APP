import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/template_style_spec.dart';
import '../pdf_fonts.dart';

/// The shared visual language of the design-spec engine: palette, type,
/// heading styles and spacing, resolved from one [TemplateStyleSpec].
/// Resume, cover letter and proposal renderers all build on this, which is
/// what makes a resume and its letter/proposal read as a matching set.
class DesignKit {
  static const palette = <TemplateAccentColor, PdfColor>{
    TemplateAccentColor.violet: PdfColor.fromInt(0xFF6C5DD3),
    TemplateAccentColor.forestGreen: PdfColor.fromInt(0xFF1F6F54),
    TemplateAccentColor.navyBlue: PdfColor.fromInt(0xFF2C5C8A),
    TemplateAccentColor.burgundy: PdfColor.fromInt(0xFFB0413E),
    TemplateAccentColor.gold: PdfColor.fromInt(0xFFB8862F),
    TemplateAccentColor.charcoal: PdfColor.fromInt(0xFF2A2A33),
    TemplateAccentColor.teal: PdfColor.fromInt(0xFF1A6B70),
    TemplateAccentColor.slate: PdfColor.fromInt(0xFF1B2430),
    TemplateAccentColor.plum: PdfColor.fromInt(0xFF6B2F5E),
    TemplateAccentColor.rust: PdfColor.fromInt(0xFFB4532A),
    TemplateAccentColor.ocean: PdfColor.fromInt(0xFF1F5FA8),
    TemplateAccentColor.black: PdfColor.fromInt(0xFF111111),
  };

  static const fonts = <TemplateFont, PdfFontFamily>{
    TemplateFont.lato: PdfFontFamily.lato,
    TemplateFont.poppins: PdfFontFamily.poppins,
    TemplateFont.ptSerif: PdfFontFamily.ptSerif,
    TemplateFont.ptSans: PdfFontFamily.ptSans,
    TemplateFont.crimsonText: PdfFontFamily.crimsonText,
    TemplateFont.plexSerif: PdfFontFamily.plexSerif,
  };

  static const ink = PdfColor.fromInt(0xFF222222);
  static const muted = PdfColor.fromInt(0xFF666666);

  /// [c] blended toward white by [amount] (0 = c, 1 = white).
  static PdfColor mix(PdfColor c, double amount) => PdfColor(
        c.red + (1 - c.red) * amount,
        c.green + (1 - c.green) * amount,
        c.blue + (1 - c.blue) * amount,
      );

  /// The font families [spec] needs, so callers load only those bytes.
  static Set<PdfFontFamily> fontsFor(TemplateStyleSpec spec) => {fonts[spec.headingFont]!, fonts[spec.bodyFont]!};

  /// Document theme (body font, with Lato as a glyph fallback) and the kit.
  /// Fonts must already be primed via [PdfFonts.primeFromBytes].
  static Future<(pw.ThemeData, DesignKit)> load(TemplateStyleSpec spec) async {
    final base = await PdfFonts.theme();
    final head = PdfFonts.family(fonts[spec.headingFont]!);
    final body = PdfFonts.family(fonts[spec.bodyFont]!);
    final theme = pw.ThemeData.withFont(
      base: body.regular,
      bold: body.bold,
      fontFallback: [base.defaultTextStyle.font!],
    );
    return (theme, DesignKit(spec, palette[spec.accentColor]!, head.bold, head.regular));
  }

  final TemplateStyleSpec spec;
  final PdfColor accent;
  final pw.Font headBold;
  final pw.Font headRegular;

  DesignKit(this.spec, this.accent, this.headBold, this.headRegular);

  PdfColor get tint => mix(accent, 0.88);

  double get scale => switch (spec.density) {
        TemplateDensity.compact => 0.82,
        TemplateDensity.comfortable => 1.0,
        TemplateDensity.spacious => 1.22,
      };
  double sp(double v) => v * scale;

  /// A section heading drawn in the spec's heading style.
  pw.Widget heading(String text, {bool onDark = false}) {
    final label = text.toUpperCase();
    final color = onDark ? PdfColors.white : accent;
    final pad = pw.EdgeInsets.only(bottom: sp(8));
    switch (spec.headingStyle) {
      case TemplateHeadingStyle.caps:
        return pw.Padding(
          padding: pad,
          child: pw.Text(label, style: pw.TextStyle(font: headBold, fontSize: 10.5, letterSpacing: 1.6, color: color)),
        );
      case TemplateHeadingStyle.underline:
        return pw.Container(
          margin: pad,
          padding: const pw.EdgeInsets.only(bottom: 3),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: color, width: 1.2))),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(font: headBold, fontSize: 10.5, letterSpacing: 1.2, color: color)),
            ),
          ]),
        );
      case TemplateHeadingStyle.bar:
        return pw.Padding(
          padding: pad,
          child: pw.Row(children: [
            pw.Container(width: 3, height: 12, color: color),
            pw.SizedBox(width: 8),
            pw.Text(label,
                style: pw.TextStyle(
                    font: headBold, fontSize: 10.5, letterSpacing: 1.2, color: onDark ? PdfColors.white : ink)),
          ]),
        );
      case TemplateHeadingStyle.pill:
        return pw.Padding(
          padding: pad,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: onDark ? mix(accent, 0.25) : tint,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: headBold, fontSize: 9.5, letterSpacing: 1.2, color: onDark ? PdfColors.white : accent)),
          ),
        );
    }
  }

  /// Splits free text into paragraphs (blank lines), keeping single line
  /// breaks inside a paragraph.
  static List<String> paragraphs(String text) => text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  /// Non-empty trimmed lines of [text].
  static List<String> lines(String text) =>
      text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}
