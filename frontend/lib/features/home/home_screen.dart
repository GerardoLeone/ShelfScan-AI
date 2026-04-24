import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/home/widget/book_poster_tile.dart';
import 'package:frontend/features/library/library_provider.dart';
import 'package:frontend/models/user_book_dto.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String selectedFilter = 'ALL';
  String searchQuery = '';
  bool isSearchVisible = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<UserBookDto> _applyFilters(List<UserBookDto> items) {
    final rawQuery = searchQuery.trim().toLowerCase();

    if (rawQuery.isEmpty) {
      return items.where((book) {
        return selectedFilter == 'ALL' || book.status == selectedFilter;
      }).toList();
    }

    final parts = rawQuery
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final normalTerms = parts.where((e) => !e.startsWith('#')).toList();

    final tagTerms = parts
        .where((e) => e.startsWith('#'))
        .map((e) => e.substring(1))
        .where((e) => e.isNotEmpty)
        .toList();

    return items.where((book) {
      final matchesFilter =
          selectedFilter == 'ALL' || book.status == selectedFilter;

      if (!matchesFilter) return false;

      final titleLower = book.title.toLowerCase();
      final authorLower = book.author.toLowerCase();
      final tagsLower = book.tags.map((t) => t.toLowerCase()).toList();

      final matchesNormalTerms = normalTerms.every(
            (term) => titleLower.contains(term) || authorLower.contains(term),
      );

      final matchesTagTerms = tagTerms.every(
            (term) => tagsLower.any((tag) => tag.contains(term)),
      );

      return matchesNormalTerms && matchesTagTerms;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: libraryAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => _LibraryErrorView(
            error: error,
            onRetry: () {
              ref.invalidate(libraryProvider);
            },
          ),
          data: (items) {
            final books = _applyFilters(items);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HomeHeader(
                          totalBooks: items.length,
                          isSearchVisible: isSearchVisible,
                          onRefresh: () {
                            ref.invalidate(libraryProvider);
                          },
                          onToggleSearch: _toggleSearch,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sfoglia la tua collezione',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cerca per titolo o autore. Per i tag usa #tag.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRect(
                          child: AnimatedAlign(
                            alignment: Alignment.topCenter,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOutCubic,
                            heightFactor: isSearchVisible ? 1 : 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: isSearchVisible ? 1 : 0,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _LibrarySearchField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value;
                                    });
                                  },
                                  onClear: () {
                                    _searchController.clear();
                                    setState(() {
                                      searchQuery = '';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _LibraryFilterChip(
                                label: 'Tutti',
                                selected: selectedFilter == 'ALL',
                                onTap: () => _setFilter('ALL'),
                              ),
                              const SizedBox(width: 8),
                              _LibraryFilterChip(
                                label: 'Da leggere',
                                selected: selectedFilter == 'TO_READ',
                                onTap: () => _setFilter('TO_READ'),
                              ),
                              const SizedBox(width: 8),
                              _LibraryFilterChip(
                                label: 'In lettura',
                                selected: selectedFilter == 'READING',
                                onTap: () => _setFilter('READING'),
                              ),
                              const SizedBox(width: 8),
                              _LibraryFilterChip(
                                label: 'Letti',
                                selected: selectedFilter == 'READ',
                                onTap: () => _setFilter('READ'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${books.length} risultati',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyLibraryView(
                      hasSearchOrFilter:
                      searchQuery.trim().isNotEmpty || selectedFilter != 'ALL',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                            (context, i) {
                          final b = books[i];
                          debugPrint('BOOK: ${b.title}');
                          debugPrint('COVER URL: ${b.coverUrl}');

                          return BookPosterTile(
                            title: b.title,
                            author: b.author,
                            coverUrl: b.coverUrl,
                            status: b.status,
                            tags: b.tags,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Apri dettaglio libro id=${b.bookId}',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        childCount: books.length,
                      ),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 22,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.54,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _setFilter(String filter) {
    setState(() {
      selectedFilter = filter;
    });
  }

  void _toggleSearch() {
    final willShow = !isSearchVisible;

    setState(() {
      isSearchVisible = willShow;

      if (!willShow) {
        _searchController.clear();
        searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });

    if (willShow) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }
}

class _HomeHeader extends StatelessWidget {
  final int totalBooks;
  final VoidCallback onRefresh;
  final VoidCallback onToggleSearch;
  final bool isSearchVisible;

  const _HomeHeader({
    required this.totalBooks,
    required this.onRefresh,
    required this.onToggleSearch,
    required this.isSearchVisible,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La tua libreria',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalBooks libri salvati',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: isSearchVisible
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: IconButton(
            onPressed: onToggleSearch,
            icon: Icon(
              isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
              color: isSearchVisible ? theme.colorScheme.primary : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }
}

class _LibrarySearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _LibrarySearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cerca titolo, autore o #tag',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

class _LibraryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.22)
              : theme.colorScheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  final bool hasSearchOrFilter;

  const _EmptyLibraryView({
    required this.hasSearchOrFilter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title =
    hasSearchOrFilter ? 'Nessun libro trovato' : 'La libreria è vuota';

    final message = hasSearchOrFilter
        ? 'Prova a cambiare filtro oppure cerca con un altro titolo, autore o tag.'
        : 'Scansiona un libro per aggiungerlo alla tua libreria personale.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearchOrFilter
                  ? Icons.search_off_rounded
                  : Icons.menu_book_rounded,
              size: 54,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _LibraryErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Errore nel caricamento della libreria',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}