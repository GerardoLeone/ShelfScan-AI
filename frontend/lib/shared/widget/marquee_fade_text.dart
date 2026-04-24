import 'dart:math' as math;

import 'package:flutter/material.dart';

class MarqueeFadeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double height;
  final Duration pause;
  final Duration forwardDuration;
  final Duration backwardDuration;
  final double fadeWidth;

  const MarqueeFadeText({
    super.key,
    required this.text,
    this.style,
    this.height = 22,
    this.pause = const Duration(milliseconds: 900),
    this.forwardDuration = const Duration(seconds: 6),
    this.backwardDuration = const Duration(seconds: 6),
    this.fadeWidth = 18,
  });

  @override
  State<MarqueeFadeText> createState() => _MarqueeFadeTextState();
}

class _MarqueeFadeTextState extends State<MarqueeFadeText> {
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
  void didUpdateWidget(covariant MarqueeFadeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.height != widget.height ||
        oldWidget.fadeWidth != widget.fadeWidth ||
        oldWidget.pause != widget.pause ||
        oldWidget.forwardDuration != widget.forwardDuration ||
        oldWidget.backwardDuration != widget.backwardDuration) {
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
        (widget.forwardDuration.inMilliseconds * (maxExtent / 80)).round(),
      );

      final backwardMs = math.max(
        1800,
        (widget.backwardDuration.inMilliseconds * (maxExtent / 80)).round(),
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
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    if (maxExtent <= 0) {
      return const LinearGradient(
        colors: [Colors.white, Colors.white],
      );
    }

    final progress = (offset / maxExtent).clamp(0.0, 1.0);
    final fadeFraction = (widget.fadeWidth / rect.width).clamp(0.0, 0.18);

    final leftStrength = Curves.easeOut.transform(progress);
    final rightStrength = Curves.easeOut.transform(1 - progress);

    final leftFade = fadeFraction * leftStrength;
    final rightFade = fadeFraction * rightStrength;

    final leftOpaqueStop = leftFade.clamp(0.0, 0.30);
    final rightOpaqueStart = (1.0 - rightFade).clamp(0.70, 1.0);

    if (rightOpaqueStart <= leftOpaqueStop) {
      return const LinearGradient(
        colors: [Colors.white, Colors.white],
      );
    }

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
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return SizedBox(
      height: widget.height,
      child: ShaderMask(
        shaderCallback: (rect) => _buildGradient(rect).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: textStyle,
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}