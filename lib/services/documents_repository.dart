import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/cover_letter_data.dart';
import '../models/document_entry.dart';
import '../models/proposal_data.dart';
import '../models/resume_data.dart';

const _uuid = Uuid();

/// Single source of truth for saved documents (resumes, cover letters,
/// proposals) shown across the Home dashboard and Favorites tab. Replaces
/// the old single-slot storage (one resume_data_v1 key, one per document
/// kind) with one JSON-array key so a user can keep multiple documents of
/// each kind.
class DocumentsRepository {
  static const _key = 'documents_v1';
  static const _migratedKey = 'migrated_v1';

  // Legacy single-slot keys from before multi-document support existed.
  static const _legacyResumeKey = 'resume_data_v1';
  static const _legacyCoverLetterKey = 'cover_letter_data_v1';
  static const _legacyProposalKey = 'proposal_data_v1';

  static Future<List<DocumentEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final entries = raw.map(DocumentEntry.decode).toList();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  static Future<void> save(DocumentEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadAll();
    entries.removeWhere((e) => e.id == entry.id);
    entries.add(entry);
    await prefs.setStringList(_key, entries.map((e) => e.encode()).toList());
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadAll();
    entries.removeWhere((e) => e.id == id);
    await prefs.setStringList(_key, entries.map((e) => e.encode()).toList());
  }

  static Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadAll();
    final index = entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    entries[index].isFavorite = !entries[index].isFavorite;
    await prefs.setStringList(_key, entries.map((e) => e.encode()).toList());
  }

  /// Wraps any pre-existing single-slot resume/cover-letter/proposal into
  /// the new multi-document list. One-time (guarded by [_migratedKey]) so
  /// it never re-runs and never re-adds documents the user already deleted.
  static Future<void> migrateLegacyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    final now = DateTime.now();
    final migrated = <DocumentEntry>[];

    final resumeJson = prefs.getString(_legacyResumeKey);
    if (resumeJson != null) {
      final data = ResumeData.decode(resumeJson);
      migrated.add(DocumentEntry(
        id: _uuid.v4(),
        kind: DocumentKind.resume,
        title: data.personalInfo.fullName.isEmpty ? 'My Resume' : data.personalInfo.fullName,
        templateId: 'classic',
        updatedAt: now,
        completionPercent: data.completionPercent,
        payload: data.toJson(),
      ));
    }

    final coverLetterJson = prefs.getString(_legacyCoverLetterKey);
    if (coverLetterJson != null) {
      final data = CoverLetterData.decode(coverLetterJson);
      migrated.add(DocumentEntry(
        id: _uuid.v4(),
        kind: DocumentKind.coverLetter,
        title: data.jobTitle.isEmpty ? 'My Cover Letter' : data.jobTitle,
        templateId: 'classic',
        updatedAt: now,
        completionPercent: data.completionPercent,
        payload: data.toJson(),
      ));
    }

    final proposalJson = prefs.getString(_legacyProposalKey);
    if (proposalJson != null) {
      final data = ProposalData.decode(proposalJson);
      migrated.add(DocumentEntry(
        id: _uuid.v4(),
        kind: DocumentKind.proposal,
        title: data.title.isEmpty ? 'My Proposal' : data.title,
        templateId: 'classic',
        updatedAt: now,
        completionPercent: data.completionPercent,
        payload: data.toJson(),
      ));
    }

    if (migrated.isNotEmpty) {
      final existing = await loadAll();
      existing.addAll(migrated);
      await prefs.setStringList(_key, existing.map((e) => e.encode()).toList());
    }

    await prefs.remove(_legacyResumeKey);
    await prefs.remove(_legacyCoverLetterKey);
    await prefs.remove(_legacyProposalKey);
    await prefs.setBool(_migratedKey, true);
  }
}
