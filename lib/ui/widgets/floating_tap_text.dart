import 'package:flutter/material.dart';

/// Owns the "+N" particles for the tap area, so spawning or finishing one
/// rebuilds only this layer instead of the whole game screen.
///
/// Wrapped in its own RepaintBoundary: while particles are alive they
/// animate every frame, which used to repaint the entire page with them.
/// Hit testing is unchanged: the layer only catches pointers that land on a
/// particle, exactly as the particles did when they sat in the page's Stack.
class FloatingTapTextLayer extends StatefulWidget {
  const FloatingTapTextLayer({super.key});

  @override
  State<FloatingTapTextLayer> createState() => FloatingTapTextLayerState();
}

class FloatingTapTextLayerState extends State<FloatingTapTextLayer> {
  static const int _maxFloatingTexts = 18;
  final List<FloatingTapText> _texts = [];

  void add({
    required String text,
    required bool isProbabilityStrike,
    required Offset position,
  }) {
    final key = UniqueKey();
    setState(() {
      if (_texts.length >= _maxFloatingTexts) {
        _texts.removeAt(0);
      }
      _texts.add(
        FloatingTapText(
          key: key,
          text: text,
          isProbabilityStrike: isProbabilityStrike,
          position: position,
          onComplete: () => _remove(key),
        ),
      );
    });
  }

  void _remove(Key key) {
    if (!mounted) return;
    setState(() => _texts.removeWhere((widget) => widget.key == key));
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(children: List<Widget>.of(_texts)),
    );
  }
}

class FloatingTapText extends StatefulWidget {
  final String text;
  final Offset position;
  final VoidCallback onComplete;
  final bool isProbabilityStrike;

  const FloatingTapText({
    super.key,
    required this.text,
    required this.position,
    required this.onComplete,
    this.isProbabilityStrike = false,
  });

  @override
  State<FloatingTapText> createState() => _FloatingTapTextState();
}

class _FloatingTapTextState extends State<FloatingTapText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isProbabilityStrike ? 760 : 680),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 45),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _positionAnimation = Tween<Offset>(
      begin: widget.position,
      end:
          widget.position - Offset(0, widget.isProbabilityStrike ? 72.0 : 52.0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
            begin: 0.92, end: widget.isProbabilityStrike ? 1.26 : 1.08),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
            begin: widget.isProbabilityStrike ? 1.26 : 1.08, end: 1.0),
        weight: 65,
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCrit = widget.isProbabilityStrike;

    // Built once and handed to the AnimatedBuilder as its child, so the text
    // isn't rebuilt and re-laid out on every frame.
    final text = Text(
      widget.text,
      style: theme.textTheme.titleLarge?.copyWith(
        color: isCrit ? const Color(0xFFFFD166) : theme.colorScheme.primary,
        fontSize: isCrit ? 34 : 24,
        fontWeight: isCrit ? FontWeight.w700 : FontWeight.w500,
        shadows: isCrit
            ? const [
                Shadow(
                  color: Color(0x66FFD166),
                  blurRadius: 16,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
    );

    // Anchored at the start position and moved with a paint-time translate.
    // Animating Positioned's left/top instead forced the Stack to lay out
    // again every frame for every live particle.
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: AnimatedBuilder(
        animation: _controller,
        child: text,
        builder: (context, child) {
          return Transform.translate(
            offset: _positionAnimation.value - widget.position,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
