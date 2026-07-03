import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/library/library_provider.dart';
import 'package:frontend/models/user_book_dto.dart';
import 'package:go_router/go_router.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final int bookId;
  final UserBookDto? initialBook;

  const BookDetailScreen({
    super.key,
    required this.bookId,
    this.initialBook,
  });

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  UserBookDto? _book;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  final _title = TextEditingController();
  final _tags = TextEditingController();

  @override
  void initState() {
    super.initState();
    _book = widget.initialBook;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(shelfScanApiProvider);
      final book = await api.getLibraryItem(widget.bookId);

      if (!mounted) return;

      setState(() {
        _book = book;
        _title.text = book.title;
        _tags.text = book.tags.join(', ');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final book = _book;
    if (book == null || _saving) return;

    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Il titolo non può essere vuoto.');
      return;
    }

    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = ref.read(shelfScanApiProvider);

      await api.updateLibraryItem(
        bookId: book.bookId,
        customTitle: title,
        customTags: tags,
      );

      ref.invalidate(libraryProvider);
      await _load();

      if (!mounted) return;
      setState(() => _editing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final book = _book;
    if (book == null || _saving) return;

    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rimuovere libro?'),
        content: Text('Vuoi rimuovere "${book.title}" dalla tua libreria?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = ref.read(shelfScanApiProvider);
      await api.removeFromLibrary(book.bookId);

      ref.invalidate(libraryProvider);

      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _openStatusPicker() async {
    final book = _book;
    if (book == null || _saving) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stato lettura',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _StatusOptionTile(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Da leggere',
                  selected: book.status == 'TO_READ',
                  onTap: () => Navigator.of(sheetContext).pop('TO_READ'),
                ),
                _StatusOptionTile(
                  icon: Icons.menu_book_rounded,
                  title: 'In lettura',
                  selected: book.status == 'READING',
                  onTap: () => Navigator.of(sheetContext).pop('READING'),
                ),
                _StatusOptionTile(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Letto',
                  selected: book.status == 'READ',
                  onTap: () => Navigator.of(sheetContext).pop('READ'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == book.status) return;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _changeStatus(selected);
  }

  Future<void> _changeStatus(String status) async {
    final book = _book;
    if (book == null || _saving) return;

    FocusManager.instance.primaryFocus?.unfocus();

    int? currentPage = book.currentPage;

    if (status == 'READING') {
      currentPage = await _askCurrentPage(initialValue: book.currentPage);
      if (!mounted || currentPage == null) return;
    } else {
      currentPage = null;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = ref.read(shelfScanApiProvider);

      await api.updateStatus(
        bookId: book.bookId,
        status: status,
        currentPage: currentPage,
      );

      ref.invalidate(libraryProvider);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<int?> _askCurrentPage({int? initialValue}) async {
    return showDialog<int>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _PageInputDialog(initialValue: initialValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: _loading && book == null
          ? const Center(child: CircularProgressIndicator())
          : book == null
          ? Center(child: Text(_error ?? 'Libro non trovato'))
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _GlassIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.pop(),
              ),
            ),
            actions: [
              _GlassIconButton(
                icon: _editing
                    ? Icons.close_rounded
                    : Icons.edit_rounded,
                onPressed: _saving
                    ? null
                    : () => setState(() => _editing = !_editing),
              ),
              const SizedBox(width: 8),
              _GlassIconButton(
                icon: Icons.delete_outline_rounded,
                onPressed: _saving ? null : _remove,
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (book.coverUrl != null &&
                      book.coverUrl!.isNotEmpty)
                    Image.network(
                      book.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                        child: const Icon(
                          Icons.menu_book_rounded,
                          size: 72,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: cs.surfaceContainerHighest,
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 72,
                      ),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x33000000),
                          Color(0xDD000000),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_editing)
                    _EditForm(
                      title: _title,
                      tags: _tags,
                      saving: _saving,
                      onSave: _save,
                    )
                  else
                    _ReadView(
                      book: book,
                      saving: _saving,
                      onStatusTap: _openStatusPicker,
                      onBookmarkTap: () => _changeStatus('READING'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadView extends StatelessWidget {
  final UserBookDto book;
  final bool saving;
  final VoidCallback onStatusTap;
  final VoidCallback onBookmarkTap;

  const _ReadView({
    required this.book,
    required this.saving,
    required this.onStatusTap,
    required this.onBookmarkTap,
  });

  String get _statusLabel {
    switch (book.status) {
      case 'READING':
        return 'In lettura';
      case 'READ':
        return 'Letto';
      case 'TO_READ':
      default:
        return 'Da leggere';
    }
  }

  IconData get _statusIcon {
    switch (book.status) {
      case 'READING':
        return Icons.menu_book_rounded;
      case 'READ':
        return Icons.check_circle_outline_rounded;
      case 'TO_READ':
      default:
        return Icons.bookmark_border_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          book.author.isEmpty ? 'Autore non disponibile' : book.author,
          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: saving ? null : onStatusTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Icon(_statusIcon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stato lettura', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                saving
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
        if (book.status == 'READING' && book.currentPage != null) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: saving ? null : onBookmarkTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pagina ${book.currentPage}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Descrizione',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book.description.isEmpty
              ? 'Nessuna descrizione disponibile.'
              : book.description,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 24),
        Text(
          'Tag',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (book.tags.isEmpty)
          Text(
            'Nessun tag disponibile.',
            style: theme.textTheme.bodyMedium,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: book.tags
                .map(
                  (tag) => Chip(
                label: Text('#$tag'),
                side: BorderSide(
                  color: cs.outline.withValues(alpha: 0.18),
                ),
              ),
            )
                .toList(),
          ),
      ],
    );
  }
}

class _StatusOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOptionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      trailing: selected
          ? Icon(
        Icons.check_rounded,
        color: cs.primary,
      )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  final TextEditingController title;
  final TextEditingController tags;
  final bool saving;
  final VoidCallback onSave;

  const _EditForm({
    required this.title,
    required this.tags,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Puoi personalizzare titolo e tag per la tua libreria. Autore e descrizione restano dati del catalogo globale.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Titolo personale',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: tags,
          decoration: const InputDecoration(
            labelText: 'Tag personali',
            helperText: 'Separali con una virgola',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save_rounded),
            label: Text(saving ? 'Salvataggio...' : 'Salva modifiche'),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PageInputDialog extends StatefulWidget {
  final int? initialValue;

  const _PageInputDialog({
    this.initialValue,
  });

  @override
  State<_PageInputDialog> createState() => _PageInputDialogState();
}

class _PageInputDialogState extends State<_PageInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_controller.text.trim());
    if (page == null || page < 0) return;

    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Segnalibro'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Pagina raggiunta',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}