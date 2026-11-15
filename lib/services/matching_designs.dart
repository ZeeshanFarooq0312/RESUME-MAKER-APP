import '../models/document_entry.dart';
import '../pdf/resume_design_presets.dart';
import 'documents_repository.dart';

/// Names of the matching-set designs the user's saved resumes use, newest
/// first. Letter and proposal pickers lead with these so a matching set is
/// one tap away. Matching is only a suggestion: any design can be chosen.
Future<List<String>> resumeDesignsInUse() async {
  final entries = await DocumentsRepository.loadAll();
  final resumes = entries.where((e) => e.kind == DocumentKind.resume).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final names = <String>[];
  for (final e in resumes) {
    final match = resumeDesignPresets.keys.where((t) => t.name == e.templateId).firstOrNull;
    if (match != null && !names.contains(match.name)) names.add(match.name);
  }
  return names;
}

/// [templates] reordered so designs matching [inUse] come first.
List<T> matchingFirst<T extends Enum>(List<T> templates, List<String> inUse) {
  final matched = [
    for (final n in inUse) ...templates.where((t) => t.name == n),
  ];
  return [...matched, ...templates.where((t) => !matched.contains(t))];
}
