import 'package:flutter/material.dart';

/// Briefly highlights a child once when [highlight] becomes true.
class OneShotHighlight extends StatefulWidget {
  const OneShotHighlight({
    super.key,
    required this.highlight,
    required this.child,
  });

  final bool highlight;
  final Widget child;

  @override
  State<OneShotHighlight> createState() => _OneShotHighlightState();
}

class _OneShotHighlightState extends State<OneShotHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _intensity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _intensity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 75,
      ),
    ]).animate(_controller);
    if (widget.highlight) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant OneShotHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _intensity,
      child: widget.child,
      builder: (context, child) {
        final intensity = _intensity.value;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            if (intensity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: intensity * 0.14),
                      border: Border.all(
                        color: color.withValues(alpha: intensity * 0.9),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
