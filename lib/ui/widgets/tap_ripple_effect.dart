import 'package:flutter/material.dart';

/// Owns the tap ripples the same way [FloatingTapTextLayer] owns the "+N"
/// particles: spawning or finishing one rebuilds only this layer, not the
/// whole game screen.
class TapRippleLayer extends StatefulWidget {
  const TapRippleLayer({super.key});

  @override
  State<TapRippleLayer> createState() => TapRippleLayerState();
}

class TapRippleLayerState extends State<TapRippleLayer> {
  static const int _maxRipples = 10;
  final List<TapRippleEffect> _ripples = [];

  void add(Offset position) {
    final key = UniqueKey();
    setState(() {
      if (_ripples.length >= _maxRipples) {
        _ripples.removeAt(0);
      }
      _ripples.add(
        TapRippleEffect(
          key: key,
          position: position,
          onComplete: () => _remove(key),
        ),
      );
    });
  }

  void _remove(Key key) {
    if (!mounted) return;
    setState(() => _ripples.removeWhere((widget) => widget.key == key));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(children: List<Widget>.of(_ripples)),
      ),
    );
  }
}

/// A short-lived expanding, fading ring centered on a tap. Purely cosmetic
/// "juice" for the tap area — mirrors [FloatingTapText]'s lifecycle pattern
/// (self-removing via [onComplete]).
class TapRippleEffect extends StatefulWidget {
  const TapRippleEffect({
    super.key,
    required this.position,
    required this.onComplete,
  });

  final Offset position;
  final VoidCallback onComplete;

  @override
  State<TapRippleEffect> createState() => _TapRippleEffectState();
}

class _TapRippleEffectState extends State<TapRippleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _radius;
  late final Animation<double> _opacity;

  static const double _startRadius = 6.0;
  static const double _endRadius = 46.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _radius = Tween<double>(begin: _startRadius, end: _endRadius).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Laid out once at the ring's final size; the growth and fade happen at
    // paint time. Animating Positioned's rect instead re-laid out the whole
    // Stack every frame for every live ripple, and the Opacity wrapper
    // added a compositing layer per ripple.
    return Positioned(
      left: widget.position.dx - _endRadius,
      top: widget.position.dy - _endRadius,
      width: _endRadius * 2,
      height: _endRadius * 2,
      child: CustomPaint(
        painter: _RipplePainter(
          controller: _controller,
          radius: _radius,
          opacity: _opacity,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required Listenable controller,
    required this.radius,
    required this.opacity,
  }) : super(repaint: controller);

  final Animation<double> radius;
  final Animation<double> opacity;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    _paint.color = Colors.white.withValues(alpha: opacity.value);
    // Border.all drew its stroke inside the box; match that.
    final r = radius.value - _paint.strokeWidth / 2;
    if (r > 0) canvas.drawCircle(size.center(Offset.zero), r, _paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.opacity != opacity;
}
