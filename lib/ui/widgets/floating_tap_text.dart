import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Owns the "+N" particles for the tap area and paints all of them from one
/// ticker in a single [CustomPaint].
///
/// Each particle's text is laid out and rasterized to an image exactly once,
/// when it spawns. Every frame after that is one image draw per particle,
/// with its fade applied through the paint's alpha.
///
/// That matters most for Probability Strikes. A strike's text carries a
/// blurred glow, and the old per-particle widgets faded it with an
/// [Opacity]: a glow under the text can't take the cheap per-draw alpha
/// path, so every frame of every strike rendered an offscreen layer and
/// re-ran the blur, at a new scale each frame. That per-frame cost is what
/// made strikes hitch. Now the blur runs once per strike, at spawn.
///
/// Particles ignore pointers: a fast tap landing on the "+N" still rising
/// from the previous tap used to be swallowed by it and never counted.
class FloatingTapTextLayer extends StatefulWidget {
  const FloatingTapTextLayer({super.key});

  @override
  State<FloatingTapTextLayer> createState() => FloatingTapTextLayerState();
}

class FloatingTapTextLayerState extends State<FloatingTapTextLayer>
    with SingleTickerProviderStateMixin {
  static const int _maxFloatingTexts = 18;

  final List<_Particle> _particles = [];
  final _Frame _frame = _Frame();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastElapsed = Duration.zero;

  /// Number of live particles. For tests.
  @visibleForTesting
  int get activeCount => _particles.length;

  void add({
    required String text,
    required bool isProbabilityStrike,
    required Offset position,
  }) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final style = _FloatingTextStyle.resolve(theme, isProbabilityStrike);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final box = context.findRenderObject() as RenderBox?;
    // Callers pass global coordinates; the layer need not sit at the origin.
    final local = (box != null && box.hasSize)
        ? box.globalToLocal(position)
        : position;

    if (_particles.length >= _maxFloatingTexts) {
      _particles.removeAt(0).dispose();
    }
    _particles.add(_Particle.spawn(
      text: text,
      style: style,
      strike: isProbabilityStrike,
      anchor: local,
      devicePixelRatio: dpr,
    ));
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
    _frame.tick();
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    for (var i = _particles.length - 1; i >= 0; i--) {
      final particle = _particles[i];
      particle.age += dt;
      if (particle.age >= particle.lifetime) {
        _particles.removeAt(i).dispose();
      }
    }
    if (_particles.isEmpty) _ticker.stop();
    _frame.tick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final particle in _particles) {
      particle.dispose();
    }
    _particles.clear();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(_particles, repaint: _frame),
        ),
      ),
    );
  }
}

/// Repaint signal for the painter; bumped once per frame while particles
/// are alive.
class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _FloatingTextStyle {
  static TextStyle resolve(ThemeData theme, bool strike) {
    return (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      color: strike ? const Color(0xFFFFD166) : theme.colorScheme.primary,
      fontSize: strike ? 34 : 24,
      fontWeight: strike ? FontWeight.w700 : FontWeight.w500,
      shadows: strike
          ? const [
              Shadow(
                color: Color(0x66FFD166),
                blurRadius: 16,
                offset: Offset(0, 2),
              ),
            ]
          : null,
    );
  }
}

class _Particle {
  _Particle._({
    required this.anchor,
    required this.textSize,
    required this.lifetime,
    required this.rise,
    required this.peakScale,
    required this.pad,
    this.image,
    this.fallback,
  });

  /// Top-left of the text at spawn, in layer coordinates.
  final Offset anchor;
  final Size textSize;
  final Duration lifetime;
  final double rise;
  final double peakScale;

  /// Room around the text for the glow, in logical pixels.
  final double pad;

  /// The text rasterized once. Null only if rasterizing failed, in which
  /// case [fallback] is painted directly.
  ui.Image? image;
  TextPainter? fallback;
  Duration age = Duration.zero;

  static final Animatable<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
  ]).chain(CurveTween(curve: Curves.easeOutCubic));

  static final Animatable<double> _riseCurve =
      CurveTween(curve: Curves.easeOutCubic);

  factory _Particle.spawn({
    required String text,
    required TextStyle style,
    required bool strike,
    required Offset anchor,
    required double devicePixelRatio,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final peakScale = strike ? 1.26 : 1.08;
    final pad = strike ? 24.0 : 2.0;
    final size = painter.size;

    ui.Image? image;
    try {
      // Rasterized at the largest size it will be drawn, so scaling never
      // enlarges the bitmap past its own resolution.
      final pixelScale = devicePixelRatio * peakScale;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(pixelScale);
      painter.paint(canvas, Offset(pad, pad));
      final picture = recorder.endRecording();
      image = picture.toImageSync(
        ((size.width + pad * 2) * pixelScale).ceil(),
        ((size.height + pad * 2) * pixelScale).ceil(),
      );
      picture.dispose();
    } catch (_) {
      image = null;
    }

    final particle = _Particle._(
      anchor: anchor,
      textSize: size,
      lifetime: Duration(milliseconds: strike ? 760 : 680),
      rise: strike ? 72.0 : 52.0,
      peakScale: peakScale,
      pad: pad,
      image: image,
      fallback: image == null ? painter : null,
    );
    if (image != null) painter.dispose();
    return particle;
  }

  double get _t =>
      (age.inMicroseconds / lifetime.inMicroseconds).clamp(0.0, 1.0);

  double get opacity => _opacity.transform(_t);

  double get dy => -rise * _riseCurve.transform(_t);

  /// Up to [peakScale] over the first 35%, then back to 1.
  late final Animatable<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.92, end: peakScale), weight: 35),
    TweenSequenceItem(tween: Tween(begin: peakScale, end: 1.0), weight: 65),
  ]).chain(CurveTween(curve: Curves.easeOut));

  double get scale => _scale.transform(_t);

  void dispose() {
    image?.dispose();
    image = null;
    fallback?.dispose();
    fallback = null;
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, {required Listenable repaint})
      : super(repaint: repaint);

  final List<_Particle> particles;
  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final opacity = p.opacity;
      if (opacity <= 0) continue;
      final center = p.anchor +
          Offset(p.textSize.width / 2, p.textSize.height / 2 + p.dy);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(p.scale);
      final image = p.image;
      final topLeft =
          Offset(-p.textSize.width / 2 - p.pad, -p.textSize.height / 2 - p.pad);
      if (image != null) {
        // Alpha through the paint: no offscreen layer, no re-blur.
        _paint.color = Color.fromRGBO(255, 255, 255, opacity);
        final src = Rect.fromLTWH(
            0, 0, image.width.toDouble(), image.height.toDouble());
        final dst = topLeft &
            Size(p.textSize.width + p.pad * 2, p.textSize.height + p.pad * 2);
        canvas.drawImageRect(image, src, dst, _paint);
      } else if (p.fallback != null) {
        canvas.saveLayer(null, _paint..color = Color.fromRGBO(0, 0, 0, opacity));
        p.fallback!.paint(canvas, topLeft + Offset(p.pad, p.pad));
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.particles != particles;
}
