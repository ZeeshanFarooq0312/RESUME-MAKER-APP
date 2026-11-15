import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../services/document_duplication.dart';
import '../services/documents_repository.dart';
import '../widgets/app_feedback.dart';
import '../widgets/auth/auth_kit.dart';
import 'cover_letter_form_screen.dart';
import 'form_screen.dart';
import 'proposal_form_screen.dart';

/// Document actions shared by every list that shows documents (Home, Saved,
/// All documents), so they behave identically everywhere. Lists refresh
/// themselves through [DocumentsRepository.revision], so none of these need
/// a reload callback.

String documentDisplayName(DocumentEntry e) => e.title.isEmpty ? e.kind.label : e.title;

Future<void> openDocument(BuildContext context, DocumentEntry entry) {
  final Widget screen = switch (entry.kind) {
    DocumentKind.resume => FormScreen(entry: entry),
    DocumentKind.coverLetter => CoverLetterFormScreen(entry: entry),
    DocumentKind.proposal => ProposalFormScreen(entry: entry),
  };
  return Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

Future<void> toggleDocumentFavorite(BuildContext context, DocumentEntry entry) async {
  final wasFavorite = entry.isFavorite;
  await DocumentsRepository.toggleFavorite(entry.id);
  if (!context.mounted) return;
  showToast(
    context,
    wasFavorite ? 'Removed from Saved' : 'Added to Saved',
    tone: wasFavorite ? ToastTone.info : ToastTone.success,
    actionLabel: 'Undo',
    onAction: () => DocumentsRepository.toggleFavorite(entry.id),
  );
}

Future<void> duplicateDocument(BuildContext context, DocumentEntry entry) =>
    duplicateDocumentEntry(context, entry);

Future<void> deleteDocument(BuildContext context, DocumentEntry entry) async {
  final name = documentDisplayName(entry);
  final confirmed = await showPromptSheet(
    context,
    tone: PromptTone.error,
    destructive: true,
    icon: LucideIcons.trash2,
    title: 'Delete this document?',
    message: '"$name" will be deleted from this device.',
    primaryLabel: 'Delete',
    secondaryLabel: 'Cancel',
  );
  if (confirmed != true) return;
  await DocumentsRepository.delete(entry.id);
  if (!context.mounted) return;
  showToast(context, '"$name" deleted', actionLabel: 'Undo', onAction: () => DocumentsRepository.save(entry));
}
