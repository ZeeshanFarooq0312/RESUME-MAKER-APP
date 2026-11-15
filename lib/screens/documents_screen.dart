import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/document_entry.dart';
import '../services/documents_repository.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/pill_search_field.dart';
import '../widgets/responsive_scaffold.dart';
import 'document_actions.dart';

enum _Sort { recent, name }

/// Every document on the device: search, filter by type, sort.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentEntry>? _entries;
  final _search = TextEditingController();
  String _query = '';
  DocumentKind? _filter;
  _Sort _sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    _load();
    DocumentsRepository.revision.addListener(_load);
  }

  @override
  void dispose() {
    DocumentsRepository.revision.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await DocumentsRepository.loadAll();
    if (mounted) setState(() => _entries = all);
  }

  bool _matches(DocumentEntry e) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [e.title, e.kind.label, e.companyLabel ?? '', e.roleLabel ?? '']
        .any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final entries = _entries;

    Widget body;
    if (entries == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (entries.isEmpty) {
      body = EmptyState(
        icon: LucideIcons.fileText,
        title: 'No documents yet',
        message: 'Resumes, cover letters and proposals you create will appear here.',
        actionLabel: 'Back to Home',
        onAction: () => Navigator.pop(context),
      );
    } else {
      final searched = entries.where(_matches).toList();
      final shown = searched.where((e) => _filter == null || e.kind == _filter).toList();
      if (_sort == _Sort.name) {
        shown.sort((a, b) => documentDisplayName(a).toLowerCase().compareTo(documentDisplayName(b).toLowerCase()));
      }
      body = ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          PillSearchField(
            controller: _search,
            hintText: 'Search by name, company or role',
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 12),
          FilterChipRow<DocumentKind?>(
            options: const [null, DocumentKind.resume, DocumentKind.coverLetter, DocumentKind.proposal],
            selected: _filter,
            labelFor: (k) => k == null ? 'All' : k.label,
            countFor: (k) => searched.where((e) => k == null || e.kind == k).length,
            onSelected: (k) => setState(() => _filter = k),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(
                icon: LucideIcons.searchX,
                title: 'No matches',
                message: 'Try a different search or filter.',
                actionLabel: 'Clear filters',
                onAction: () {
                  _search.clear();
                  setState(() {
                    _query = '';
                    _filter = null;
                  });
                },
              ),
            )
          else
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
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('All documents${entries == null || entries.isEmpty ? '' : '  ·  ${entries.length}'}'),
        actions: [
          if (entries != null && entries.length > 1)
            PopupMenuButton<_Sort>(
              tooltip: 'Sort',
              icon: const Icon(LucideIcons.arrowUpDown, size: 20),
              initialValue: _sort,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Sort.recent, child: Text('Most recent')),
                PopupMenuItem(value: _Sort.name, child: Text('Name A–Z')),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContentBound(maxWidth: 720, child: body),
      ),
    );
  }
}
