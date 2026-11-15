import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../services/documents_repository.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/responsive_scaffold.dart';
import 'document_actions.dart';

/// The "Saved" tab: every hearted document, filterable by type. Listens to
/// [DocumentsRepository.revision] so hearting a document anywhere shows up
/// here immediately (this tab stays alive in the app shell's IndexedStack).
class FavoritesTabScreen extends StatefulWidget {
  /// Switches the app shell back to Home (used by the empty state).
  final VoidCallback? onGoHome;
  const FavoritesTabScreen({super.key, this.onGoHome});

  @override
  State<FavoritesTabScreen> createState() => _FavoritesTabScreenState();
}

class _FavoritesTabScreenState extends State<FavoritesTabScreen> {
  List<DocumentEntry>? _favorites;
  DocumentKind? _filter;

  @override
  void initState() {
    super.initState();
    _load();
    DocumentsRepository.revision.addListener(_load);
  }

  @override
  void dispose() {
    DocumentsRepository.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final all = await DocumentsRepository.loadAll();
    if (mounted) setState(() => _favorites = all.where((e) => e.isFavorite).toList());
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final favorites = _favorites;

    Widget body;
    if (favorites == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (favorites.isEmpty) {
      body = EmptyState(
        icon: LucideIcons.heart,
        title: 'Nothing saved yet',
        message: 'Tap the heart on any document to keep it here for quick access.',
        actionLabel: widget.onGoHome != null ? 'Go to Home' : null,
        onAction: widget.onGoHome,
      );
    } else {
      final shown = favorites.where((e) => _filter == null || e.kind == _filter).toList();
      final kinds = [null, ...DocumentKind.values.where((k) => favorites.any((e) => e.kind == k))];
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            if (kinds.length > 2) ...[
              FilterChipRow<DocumentKind?>(
                options: kinds,
                selected: _filter,
                labelFor: (k) => k == null ? 'All' : k.label,
                countFor: (k) => favorites.where((e) => k == null || e.kind == k).length,
                onSelected: (k) => setState(() => _filter = k),
              ),
              const SizedBox(height: 16),
            ],
            DocumentGroup(
              children: [
                for (final e in shown)
                  DocumentCard(
                    key: ValueKey(e.id),
                    entry: e,
                    onTap: () => openDocument(context, e),
                    onToggleFavorite: () => toggleDocumentFavorite(context, e),
                    onDelete: () => deleteDocument(context, e),
                    onDuplicate: () => duplicateDocument(context, e),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final count = favorites?.length ?? 0;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: ResponsiveContentBound(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 28,
                        height: 1.15,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w600,
                        color: p.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'Your favorite documents, one tap away.'
                          : '$count ${count == 1 ? 'document' : 'documents'} you have hearted.',
                      style: TextStyle(fontSize: 14.5, color: p.body),
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
