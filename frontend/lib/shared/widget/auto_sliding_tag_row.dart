import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AutoSlidingTagRow extends StatefulWidget {
  final List<String> tags;
  final Duration pause;
  final Duration forwardDuration;
  final Duration backwardDuration;
  final double height;

  const AutoSlidingTagRow({
    super.key,
    required this.tags,
    this.pause = const Duration(milliseconds: 900),
    this.forwardDuration = const Duration(seconds: 10),
    this.backwardDuration = const Duration(seconds: 10),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflowAndStart();
    });
  }

  @override
  void didUpdateWidget(covariant AutoSlidingTagRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tags.join('|') != widget.tags.join('|')) {
      _animationToken++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverflowAndStart();
      });
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
    if (mounted) {
      setState(() {});
    }
  }

  void _checkOverflowAndStart() {
    if (!mounted || !_scrollController.hasClients) return;

    final overflowing = _scrollController.position.maxScrollExtent > 1;

    if (_isOverflowing != overflowing) {
      setState(() {
        _isOverflowing = overflowing;
      });
    }

    if (!overflowing) {
      if (_scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    _startLoop();
  }

  Future<void> _startLoop() async {
    final token = ++_animationToken;

    if (!mounted || !_scrollController.hasClients || _disposed) return;

    await Future<void>.delayed(widget.pause);
    if (!_canContinue(token)) return;

    while (_canContinue(token)) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 1) break;

      final forwardMs = math.max(
        1800,
        (widget.forwardDuration.inMilliseconds * (maxExtent / 120)).round(),
      );

      final backwardMs = math.max(
        1800,
        (widget.backwardDuration.inMilliseconds * (maxExtent / 120)).round(),
      );

      await _scrollController.animateTo(
        maxExtent,
        duration: Duration(milliseconds: forwardMs),
        curve: Curves.easeInOutCubic,
      );

      if (!_canContinue(token)) break;
      await Future<void>.delayed(widget.pause);

      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: backwardMs),
        curve: Curves.easeInOutCubic,
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
      return const LinearGradient(
        colors: [Colors.white, Colors.white],
      );
    }

    final maxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final offset =
    _scrollController.hasClients ? _scrollController.offset : 0.0;

    if (maxExtent <= 0) {
      return const LinearGradient(
        colors: [Colors.white, Colors.white],
      );
    }

    final progress = (offset / maxExtent).clamp(0.0, 1.0);
    const fadeFraction = 0.10;

    final leftStrength = Curves.easeOut.transform(progress);
    final rightStrength = Curves.easeOut.transform(1 - progress);

    final leftFade = fadeFraction * leftStrength;
    final rightFade = fadeFraction * rightStrength;

    final leftOpaqueStop = leftFade.clamp(0.0, 0.25);
    final rightOpaqueStart = (1.0 - rightFade).clamp(0.75, 1.0);

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
        leftOpaqueStop,
        rightOpaqueStart,
        1.0,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
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
      ),
    );
  }
}