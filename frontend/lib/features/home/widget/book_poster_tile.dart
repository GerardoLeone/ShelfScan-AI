import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widget/auto_sliding_tag_row.dart';
import '../../../shared/widget/marquee_fade_text.dart';

class BookPosterTile extends StatefulWidget {
  final String title;
  final String author;
  final String? coverUrl;
  final String status;
  final List<String> tags;
  final VoidCallback? onTap;

  const BookPosterTile({
    super.key,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.status,
    required this.tags,
    this.onTap,
  });

  @override
  State<BookPosterTile> createState() => _BookPosterTileState();
}

class _BookPosterTileState extends State<BookPosterTile> {
  bool _pressed = false;
  Timer? _releaseTimer;

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (!mounted) return;
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  void _handleTapDown(TapDownDetails _) {
    _releaseTimer?.cancel();
    _setPressed(true);
  }

  void _handleTapUp(TapUpDetails _) {
    _releaseWithDelay();
  }

  void _handleTapCancel() {
    _releaseWithDelay();
  }

  void _releaseWithDelay() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 140), () {
      _setPressed(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusData = _statusInfo(widget.status);

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      scale: _pressed ? 0.982 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          onTap: widget.onTap,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BookCoverImage(
                    coverUrl: widget.coverUrl,
                    title: widget.title,
                    author: widget.author,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _StatusBadge(statusData: statusData),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 156,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x99000000),
                              Color(0xE0000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarqueeFadeText(
                          text: widget.title,
                          height: 24,
                          fadeWidth: 10,
                          forwardDuration: const Duration(seconds: 8),
                          backwardDuration: const Duration(seconds: 8),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AutoSlidingTagRow(tags: widget.tags),
                        ],
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      color: _pressed
                          ? Colors.black.withValues(alpha: 0.14)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _StatusData _statusInfo(String status) {
    switch (status) {
      case 'READ':
        return const _StatusData(
          label: 'Letto',
          icon: Icons.check_rounded,
          backgroundColor: Color(0xCC111827),
          foregroundColor: Colors.white,
        );
      case 'READING':
        return const _StatusData(
          label: 'In lettura',
          icon: Icons.auto_stories_rounded,
          backgroundColor: Color(0xCCE68A00),
          foregroundColor: Colors.white,
        );
      case 'TO_READ':
      default:
        return const _StatusData(
          label: 'Da leggere',
          icon: Icons.bookmark_outline_rounded,
          backgroundColor: Color(0xCC4F46E5),
          foregroundColor: Colors.white,
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusData statusData;

  const _StatusBadge({required this.statusData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: statusData.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusData.icon,
              size: 14,
              color: statusData.foregroundColor,
            ),
            const SizedBox(width: 6),
            Text(
              statusData.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusData.foregroundColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCoverImage extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String author;

  const _BookCoverImage({
    required this.coverUrl,
    required this.title,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (coverUrl != null && coverUrl!.trim().isNotEmpty) {
      return Image.network(
        coverUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _BookCoverPlaceholder(
          title: title,
          author: author,
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    return _BookCoverPlaceholder(
      title: title,
      author: author,
    );
  }
}

class _BookCoverPlaceholder extends StatelessWidget {
  final String title;
  final String author;

  const _BookCoverPlaceholder({
    required this.title,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.90),
            theme.colorScheme.secondary.withValues(alpha: 0.80),
          ],
        ),
      ),
    );
  }
}

class _StatusData {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _StatusData({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}