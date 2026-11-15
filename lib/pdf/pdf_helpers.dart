import 'package:pdf/widgets.dart' as pw;

/// Matches a leading list marker a line might already carry — a bullet
/// glyph (•, ◦, ▪, ‣, ·), a dash/asterisk bullet ("- ", "* "), or a number/
/// letter marker ("1.", "1)", "(1)", "a)") — so it can be stripped before
/// this function adds its own "•". Without this, AI-generated text (which
/// routinely writes its own "- " or "1. " list items despite being asked
/// not to) or a pasted-in resume that already had bullets ends up doubled:
/// "•  - Did X" or "•  1. Did X" instead of a single, clean marker.
final _leadingMarker = RegExp(r'^[\s]*(?:[•◦▪‣·–—]|[-*])\s+|^[\s]*\(?\d+[.\)]\s+|^[\s]*\([a-zA-Z]\)\s+');

/// Renders a free-text description as plain bullet lines (one per
/// non-empty input line). Plain text bullets — not tables or columns —
/// so ATS parsers can read the content in order.
List<pw.Widget> bulletLines(String description, {double fontSize = 9.5}) {
  final lines = description
      .split('\n')
      .map((l) => l.trim().replaceFirst(_leadingMarker, ''))
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return [];

  return lines
      .map((line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text('•  $line', style: pw.TextStyle(fontSize: fontSize)),
          ))
      .toList();
}
