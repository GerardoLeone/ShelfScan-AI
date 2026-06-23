import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AutoSlidingTagRow extends StatefulWidget {
  final List<String> tags;
  final Duration pause;
  final double pixelsPerSecond;
  final double height;

  const AutoSlidingTagRow({
    super.key,
    required this.tags,
    this.pause = const Duration(milliseconds: 450),
    this.pixelsPerSecond = 48,
    this.height = 28,
  });

  @override
  State<AutoSlidingTagRow> createState() => _AutoSlidingTagRowState();
}

class _AutoSlidingTagRowState extends State<AutoSlidingTagRow> {
  final ScrollController _scrollController = ScrollController();

  bool _isOverflowing = false;
  bool _disposed = false;
  int _animationToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflowAndStart());
  }

  @override
  void didUpdateWidget(covariant AutoSlidingTagRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tags.join('|') != widget.tags.join('|')) {
      _animationToken++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflowAndStart());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _animationToken++;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  void _checkOverflowAndStart() {
    if (!mounted || !_scrollController.hasClients) return;

    final overflowing = _scrollController.position.maxScrollExtent > 1;

    if (_isOverflowing != overflowing) {
      setState(() => _isOverflowing = overflowing);
    }

    if (!overflowing) {
      if (_scrollController.offset != 0) _scrollController.jumpTo(0);
      return;
    }

    _startLoop();
  }

  Future<void> _startLoop() async {
    final token = ++_animationToken;

    if (!_canContinue(token)) return;

    await Future<void>.delayed(widget.pause);
    if (!_canContinue(token)) return;

    while (_canContinue(token)) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 1) break;

      final ms = math.max(
        1200,
        ((maxExtent / widget.pixelsPerSecond) * 1000).round(),
      );

      await _scrollController.animateTo(
        maxExtent,
        duration: Duration(milliseconds: ms),
        curve: Curves.linear,
      );

      if (!_canContinue(token)) break;
      await Future<void>.delayed(widget.pause);

      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: ms),
        curve: Curves.linear,
      );

      if (!_canContinue(token)) break;
      await Future<void>.delayed(widget.pause);
    }
  }

  bool _canContinue(int token) {
    return mounted &&
        !_disposed &&
        _animationToken == token &&
        _scrollController.hasClients;
  }

  LinearGradient _buildGradient(Rect rect) {
    if (!_isOverflowing || rect.width <= 0) {
      return const LinearGradient(colors: [Colors.white, Colors.white]);
    }

    final maxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    if (maxExtent <= 0) {
      return const LinearGradient(colors: [Colors.white, Colors.white]);
    }

    final progress = (offset / maxExtent).clamp(0.0, 1.0);
    const fadeFraction = 0.10;

    final leftFade = fadeFraction * Curves.easeOut.transform(progress);
    final rightFade = fadeFraction * Curves.easeOut.transform(1 - progress);

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [
        0.0,
        leftFade.clamp(0.0, 0.25),
        (1.0 - rightFade).clamp(0.75, 1.0),
        1.0,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: ShaderMask(
        shaderCallback: (rect) => _buildGradient(rect).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.tags.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            return _TagBadge(label: '#${widget.tags[index]}');
          },
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String label;

  const _TagBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC0F172A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}