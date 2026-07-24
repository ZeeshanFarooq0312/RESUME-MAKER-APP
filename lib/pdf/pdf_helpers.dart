import 'package:pdf/widgets.dart' as pw;

/// Renders a free-text description as plain bullet lines (one per
/// non-empty input line). Plain text bullets — not tables or columns —
/// so ATS parsers can read the content in order.
List<pw.Widget> bulletLines(String description, {double fontSize = 9.5}) {
  final lines = description
      .split('\n')
      .map((l) => l.trim())
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
