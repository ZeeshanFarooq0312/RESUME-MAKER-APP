import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Loads a Unicode-capable font (Lato) for PDF generation so characters
/// like em dash (—) and bullet (•) render instead of falling back to the
/// base Helvetica font, which only supports plain ASCII.
///
/// PDF generation runs inside a background `Isolate.run` isolate (see the
/// preview screens) to keep the UI thread from stuttering. A fresh isolate
/// has no Flutter bindings, so `rootBundle.load` — which needs
/// `ServicesBinding.instance` — throws "binding has not yet been
/// initialized" if called there. The fix: load the raw font bytes on the
/// caller's isolate (where bindings exist) via [loadBytes], then call
/// [primeFromBytes] first thing inside the background isolate to build the
/// theme from those already-loaded bytes without ever touching rootBundle.
/// Extra type families available to the design-spec template engine
/// (see DynamicResumeTemplate). All are static TTFs under the SIL Open Font
/// License (licenses in assets/fonts/pdf/licenses), because the pdf package
/// can't select weights from variable fonts.
enum PdfFontFamily { lato, poppins, ptSerif, ptSans, crimsonText, plexSerif }

const _familyAssets = <PdfFontFamily, (String, String)>{
  PdfFontFamily.lato: ('assets/fonts/Lato-Regular.ttf', 'assets/fonts/Lato-Bold.ttf'),
  PdfFontFamily.poppins: ('assets/fonts/pdf/Poppins-Regular.ttf', 'assets/fonts/pdf/Poppins-Bold.ttf'),
  PdfFontFamily.ptSerif: ('assets/fonts/pdf/PT_Serif-Web-Regular.ttf', 'assets/fonts/pdf/PT_Serif-Web-Bold.ttf'),
  PdfFontFamily.ptSans: ('assets/fonts/pdf/PT_Sans-Web-Regular.ttf', 'assets/fonts/pdf/PT_Sans-Web-Bold.ttf'),
  PdfFontFamily.crimsonText: ('assets/fonts/pdf/CrimsonText-Regular.ttf', 'assets/fonts/pdf/CrimsonText-Bold.ttf'),
  PdfFontFamily.plexSerif: ('assets/fonts/pdf/IBMPlexSerif-Regular.ttf', 'assets/fonts/pdf/IBMPlexSerif-Bold.ttf'),
};

/// Raw font bytes to hand into a background isolate: the base (Lato) pair,
/// plus any extra families a design needs.
typedef PdfFontBytes = ({
  Uint8List regular,
  Uint8List bold,
  Map<PdfFontFamily, (Uint8List, Uint8List)> extras,
});

class PdfFonts {
  static pw.ThemeData? _theme;
  static ({Uint8List regular, Uint8List bold})? _bytesCache;
  static final _extraBytesCache = <PdfFontFamily, (Uint8List, Uint8List)>{};
  static final _families = <PdfFontFamily, ({pw.Font regular, pw.Font bold})>{};

  /// Loads the base font bytes, plus the bytes for [extra] families. Only
  /// load what a document needs, since every byte is copied into the
  /// rendering isolate.
  static Future<PdfFontBytes> loadBytes({Iterable<PdfFontFamily> extra = const []}) async {
    final base = await _loadBaseBytes();
    final extras = <PdfFontFamily, (Uint8List, Uint8List)>{};
    for (final family in extra) {
      if (family == PdfFontFamily.lato) continue;
      extras[family] = _extraBytesCache[family] ??= await _loadFamilyBytes(family);
    }
    return (regular: base.regular, bold: base.bold, extras: extras);
  }

  static Future<(Uint8List, Uint8List)> _loadFamilyBytes(PdfFontFamily family) async {
    final (regularPath, boldPath) = _familyAssets[family]!;
    final regular = await rootBundle.load(regularPath);
    final bold = await rootBundle.load(boldPath);
    return (Uint8List.sublistView(regular), Uint8List.sublistView(bold));
  }

  static Future<({Uint8List regular, Uint8List bold})> _loadBaseBytes() async {
    final cached = _bytesCache;
    if (cached != null) return cached;

    final regularData = await rootBundle.load('assets/fonts/Lato-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Lato-Bold.ttf');
    final bytes = (
      regular: Uint8List.sublistView(regularData),
      bold: Uint8List.sublistView(boldData),
    );
    _bytesCache = bytes;
    return bytes;
  }

  static pw.ThemeData primeFromBytes(
    Uint8List regularBytes,
    Uint8List boldBytes, [
    Map<PdfFontFamily, (Uint8List, Uint8List)> extras = const {},
  ]) {
    extras.forEach((family, bytes) {
      _families[family] ??= (
        regular: pw.Font.ttf(ByteData.sublistView(bytes.$1)),
        bold: pw.Font.ttf(ByteData.sublistView(bytes.$2)),
      );
    });
    final cached = _theme;
    if (cached != null) return cached;

    final regular = pw.Font.ttf(ByteData.sublistView(regularBytes));
    final bold = pw.Font.ttf(ByteData.sublistView(boldBytes));
    final built = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [regular, bold],
    );
    _theme = built;
    return built;
  }

  /// Only safe to call on an isolate with Flutter bindings initialized
  /// (i.e. not inside `Isolate.run`) — see [primeFromBytes] for that case.
  static Future<pw.ThemeData> theme() async {
    final cached = _theme;
    if (cached != null) return cached;
    final bytes = await loadBytes();
    return primeFromBytes(bytes.regular, bytes.bold);
  }

  /// The regular/bold pair for [family], falling back to the base font if
  /// it wasn't primed (so a missing family degrades, never crashes).
  static ({pw.Font regular, pw.Font bold}) family(PdfFontFamily family) {
    final primed = _families[family];
    if (primed != null) return primed;
    final base = _theme!;
    return (regular: base.defaultTextStyle.font!, bold: base.defaultTextStyle.fontBold!);
  }
}
