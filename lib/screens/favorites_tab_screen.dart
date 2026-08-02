import 'package:flutter/material.dart';
import '../models/document_entry.dart';
import '../services/documents_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state.dart';
import 'cover_letter_form_screen.dart';
import 'form_screen.dart';
import 'proposal_form_screen.dart';

class FavoritesTabScreen extends StatefulWidget {
  const FavoritesTabScreen({super.key});

  @override
  State<FavoritesTabScreen> createState() => _FavoritesTabScreenState();
}

class _FavoritesTabScreenState extends State<FavoritesTabScreen> {
  List<DocumentEntry>? _favorites;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DocumentsRepository.loadAll();
    if (mounted) setState(() => _favorites = all.where((e) => e.isFavorite).toList());
  }

  Future<void> _openExisting(DocumentEntry entry) async {
    Widget screen;
    switch (entry.kind) {
      case DocumentKind.resume:
        screen = FormScreen(entry: entry);
        break;
      case DocumentKind.coverLetter:
        screen = CoverLetterFormScreen(entry: entry);
        break;
      case DocumentKind.proposal:
        screen = ProposalFormScreen(entry: entry);
        break;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _toggleFavorite(DocumentEntry entry) async {
    await DocumentsRepository.toggleFavorite(entry.id);
    _load();
  }

  Future<void> _delete(DocumentEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this document?'),
        content: Text('"${entry.title}" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DocumentsRepository.delete(entry.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favorites;
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: SafeArea(
        child: favorites == null
            ? const Center(child: CircularProgressIndicator())
            : favorites.isEmpty
                ? const EmptyState(
                    icon: Icons.favorite_border,
                    title: 'No favorites yet',
                    message: "Tap the heart icon on a document to favorite it — it'll show up here.",
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: favorites
                          .map((e) => DocumentCard(
                                entry: e,
                                onTap: () => _openExisting(e),
                                onToggleFavorite: () => _toggleFavorite(e),
                                onDelete: () => _delete(e),
                              ))
                          .toList(),
                    ),
                  ),
      ),
    );
  }
}
