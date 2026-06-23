import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/library/library_provider.dart';
import 'package:frontend/models/user_book_dto.dart';
import '../../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final libraryAsync = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (books) {
          final stats = _ProfileStats.fromBooks(books);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _AccountCard(),
              const SizedBox(height: 18),
              _StatsGrid(stats: stats),
              const SizedBox(height: 18),
              _ProgressCard(stats: stats),
              const SizedBox(height: 18),
              if (stats.latestBook != null)
                _LatestBookCard(book: stats.latestBook!),
              const SizedBox(height: 18),
              _BadgeCard(stats: stats),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileStats {
  final int total;
  final int toRead;
  final int reading;
  final int read;
  final double percentRead;
  final UserBookDto? latestBook;

  const _ProfileStats({
    required this.total,
    required this.toRead,
    required this.reading,
    required this.read,
    required this.percentRead,
    required this.latestBook,
  });

  factory _ProfileStats.fromBooks(List<UserBookDto> books) {
    final total = books.length;
    final toRead = books.where((b) => b.status == 'TO_READ').length;
    final reading = books.where((b) => b.status == 'READING').length;
    final read = books.where((b) => b.status == 'READ').length;

    return _ProfileStats(
      total: total,
      toRead: toRead,
      reading: reading,
      read: read,
      percentRead: total == 0 ? 0 : read / total,
      latestBook: books.isEmpty ? null : books.first,
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);

    final email = auth.valueOrNull?.userName ?? 'Email non disponibile';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.person_rounded,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account collegato',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accesso tramite Microsoft Easy Auth',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final _ProfileStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _StatCard(title: 'Totale', value: '${stats.total}'),
            const SizedBox(width: 12),
            _StatCard(title: 'Letti', value: '${stats.read}'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(title: 'In lettura', value: '${stats.reading}'),
            const SizedBox(width: 12),
            _StatCard(title: 'Da leggere', value: '${stats.toRead}'),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final _ProfileStats stats;

  const _ProgressCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final percent = stats.percentRead;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completamento libreria',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 10),
          Text(
            '${(percent * 100).toStringAsFixed(0)}% dei libri segnati come letti',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LatestBookCard extends StatelessWidget {
  final UserBookDto book;

  const _LatestBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                book.coverUrl!,
                width: 58,
                height: 82,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 58,
              height: 82,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_book_rounded),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ultimo libro aggiunto',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final _ProfileStats stats;

  const _BadgeCard({required this.stats});

  String get title {
    if (stats.total == 0) return 'Libreria da iniziare';
    if (stats.read >= 10) return 'Lettore accanito';
    if (stats.reading > 0) return 'Lettura in corso';
    if (stats.total >= 5) return 'Collezionista';
    return 'Nuovo lettore';
  }

  String get subtitle {
    if (stats.total == 0) {
      return 'Scansiona il tuo primo libro per iniziare.';
    }
    if (stats.read >= 10) {
      return 'Hai già segnato molti libri come letti.';
    }
    if (stats.reading > 0) {
      return 'Hai almeno un libro attualmente in lettura.';
    }
    if (stats.total >= 5) {
      return 'La tua libreria sta prendendo forma.';
    }
    return 'Continua ad aggiungere libri alla tua libreria.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: cs.onPrimaryContainer,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}