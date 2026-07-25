import 'package:flutter/material.dart';
import '../models/document_entry.dart';
import '../theme/app_theme.dart';
import 'progress_bar.dart';

class DocumentCard extends StatelessWidget {
  final DocumentEntry entry;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  IconData get _kindIcon {
    switch (entry.kind) {
      case DocumentKind.resume:
        return Icons.badge_outlined;
      case DocumentKind.coverLetter:
        return Icons.mail_outline;
      case DocumentKind.proposal:
        return Icons.handshake_outlined;
    }
  }

  String get _updatedLabel {
    final d = entry.updatedAt;
    return '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';
  }

  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E5F3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_kindIcon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? entry.kind.label : entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.kind.label} · $_updatedLabel',
                    style: const TextStyle(color: AppColors.slate600, fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: ProgressBar(percent: entry.completionPercent)),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.completionPercent.round()}%',
                        style: const TextStyle(
                            color: AppColors.slate600, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: entry.isFavorite ? AppColors.danger : AppColors.slate400,
                size: 20,
              ),
              onPressed: onToggleFavorite,
              visualDensity: VisualDensity.compact,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.slate400, size: 20),
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
