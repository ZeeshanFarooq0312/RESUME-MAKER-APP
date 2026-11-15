import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';

/// "Just now", "5m ago", "2h ago", "Yesterday", "3d ago", else "12 Mar 2025".
String relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${when.day} ${months[when.month - 1]} ${when.year}';
}

/// Icon per document type, shared by Home's cards and tiles. Deliberately
/// one neutral color for every type — the icon shape is what tells them
/// apart, so tiles don't turn into a row of colored blobs.
({IconData icon}) documentKindStyle(DocumentKind kind) {
  switch (kind) {
    case DocumentKind.resume:
      return (icon: LucideIcons.fileText);
    case DocumentKind.coverLetter:
      return (icon: LucideIcons.mail);
    case DocumentKind.proposal:
      return (icon: LucideIcons.filePenLine);
  }
}

/// Groups [DocumentCard] rows into one rounded list with hairline dividers.
class DocumentGroup extends StatelessWidget {
  final List<Widget> children;
  const DocumentGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 72, color: p.fieldBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One document row: a progress ring around the type icon, title, a
/// "Resume · 2h ago · Company" line, a heart and a ⋮ menu. Meant to sit in a
/// [DocumentGroup].
class DocumentCard extends StatelessWidget {
  final DocumentEntry entry;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;

  const DocumentCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final style = documentKindStyle(entry.kind);
    final pct = entry.completionPercent.clamp(0, 100).toDouble();
    // Company is the most useful tag at a glance (e.g. which application a
    // tailored resume is for); fall back to the role.
    final label = (entry.companyLabel ?? '').isNotEmpty ? entry.companyLabel! : (entry.roleLabel ?? '');
    final meta = [entry.kind.label, relativeTime(entry.updatedAt), if (label.isNotEmpty) label].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 2, 12),
          child: Row(
            children: [
              Semantics(
                label: '${pct.round()}% complete',
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                        backgroundColor: p.fieldBorder,
                        color: pct >= 80 ? AppColors.success : p.title,
                      ),
                      Center(child: Icon(style.icon, size: 19, color: p.title)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isEmpty ? entry.kind.label : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.title),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.body, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: entry.isFavorite ? 'Remove from Saved' : 'Save',
                icon: Icon(
                  entry.isFavorite ? Icons.favorite_rounded : LucideIcons.heart,
                  color: entry.isFavorite ? AppColors.danger : p.muted,
                  size: 20,
                ),
                onPressed: onToggleFavorite,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(LucideIcons.ellipsisVertical, color: p.muted, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (value) {
                  if (value == 'open') onTap();
                  if (value == 'delete') onDelete();
                  if (value == 'duplicate') onDuplicate?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(children: [Icon(LucideIcons.squarePen, size: 18), SizedBox(width: 10), Text('Edit')]),
                  ),
                  if (onDuplicate != null)
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(children: [Icon(LucideIcons.copy, size: 18), SizedBox(width: 10), Text('Duplicate')]),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(LucideIcons.trash2, size: 18, color: AppColors.danger),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
