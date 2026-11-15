import 'package:flutter/material.dart';
import '../widgets/app_feedback.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../models/document_entry.dart';
import 'documents_repository.dart';

const _uuid = Uuid();

/// Shows a small dialog asking for optional company/role labels, then saves
/// a duplicate of [entry] under a new id — so a resume/cover letter tailored
/// for different job applications can be saved as distinguishable variants
/// without overwriting the original. Returns true if a duplicate was saved.
Future<bool> duplicateDocumentEntry(BuildContext context, DocumentEntry entry) async {
  final companyController = TextEditingController(text: entry.companyLabel ?? '');
  final roleController = TextEditingController(text: entry.roleLabel ?? '');
  final confirmed = await showInputSheet(
    context,
    icon: LucideIcons.copy,
    title: 'Duplicate as a new version',
    message: 'Label the copy so you can tell versions apart, e.g. one tailored for each job. Both are optional.',
    fields: [
      SheetField(label: 'Company', hint: 'Careem', icon: LucideIcons.building2, controller: companyController),
      SheetField(label: 'Role', hint: 'Senior Designer', icon: LucideIcons.briefcase, controller: roleController),
    ],
    primaryLabel: 'Duplicate',
    primaryIcon: LucideIcons.copy,
  );
  if (!confirmed) return false;

  final copy = DocumentEntry(
    id: _uuid.v4(),
    kind: entry.kind,
    title: entry.title,
    templateId: entry.templateId,
    updatedAt: DateTime.now(),
    completionPercent: entry.completionPercent,
    payload: Map<String, dynamic>.from(entry.payload),
    companyLabel: companyController.text.trim().isEmpty ? null : companyController.text.trim(),
    roleLabel: roleController.text.trim().isEmpty ? null : roleController.text.trim(),
    customStyleSpec: entry.customStyleSpec != null ? Map<String, dynamic>.from(entry.customStyleSpec!) : null,
  );
  await DocumentsRepository.save(copy);
  if (context.mounted) showToast(context, 'Copy created', tone: ToastTone.success);
  return true;
}
