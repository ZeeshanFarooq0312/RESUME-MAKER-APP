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
class PdfFonts {
  static pw.ThemeData? _theme;
  static ({Uint8List regular, Uint8List bold})? _bytesCache;

  static Future<({Uint8List regular, Uint8List bold})> loadBytes() async {
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

  static pw.ThemeData primeFromBytes(Uint8List regularBytes, Uint8List boldBytes) {
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
}
