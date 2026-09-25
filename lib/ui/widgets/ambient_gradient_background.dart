import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ambient backdrop for the main tap screen: soft radial blobs drift in
/// wide, visible orbits and a scattering of faint particles drifts and
/// pulses over them, so the screen behind the number reads as alive without
/// pulling focus from it. Grayscale/primary-tinted only, matching the app's
/// monochrome theme — no color motifs.
class AmbientGradientBackground extends StatefulWidget {
  const AmbientGradientBackground({super.key});

  @override
  State<AmbientGradientBackground> createState() =>
      _AmbientGradientBackgroundState();
}

class _AmbientGradientBackgroundState extends State<AmbientGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AmbientPainter(progress: _controller, primary: primary),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.progress, required this.primary})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color primary;

  final Paint _particlePaint = Paint();

  // Wide, slow-orbiting glow blobs. Amplitudes are a fraction of the
  // shorter side so the drift stays visible on both phone and tablet
  // aspect ratios.
  static const _blobs = <(double cx, double cy, double orbit, double radius,
      double alpha, double speed, double phase)>[
    (0.30, 0.24, 0.30, 0.58, 0.055, 1.0, 0.0),
    (0.72, 0.72, 0.26, 0.62, 0.042, 0.8, math.pi),
    (0.78, 0.20, 0.18, 0.34, 0.035, 1.3, 2.1),
  ];

  Size? _blobPaintsSize;
  List<Paint> _blobPaints = const [];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.value * 2 * math.pi;

    if (size != _blobPaintsSize) {
      _blobPaintsSize = size;
      _blobPaints = [
        for (final blob in _blobs)
          _blobPaint(
            radius: size.shortestSide * blob.$4,
            color: primary.withValues(alpha: blob.$5),
          ),
      ];
    }
    for (var i = 0; i < _blobs.length; i++) {
      final blob = _blobs[i];
      final angle = t * blob.$6 + blob.$7;
      final cx =
          size.width * blob.$1 + size.shortestSide * blob.$3 * math.cos(angle);
      final cy =
          size.height * blob.$2 + size.shortestSide * blob.$3 * math.sin(angle);
      // The gradient is built once around the origin and moved with the
      // canvas, instead of allocating a new shader per blob every frame.
      canvas.save();
      canvas.translate(cx, cy);
      canvas.drawCircle(
          Offset.zero, size.shortestSide * blob.$4, _blobPaints[i]);
      canvas.restore();
    }

    // Faint drifting particles for texture and a sense of motion up close.
    const particleCount = 22;
    for (var i = 0; i < particleCount; i++) {
      final baseX = ((i * 73) % 100) / 100.0;
      final baseY = ((i * 37 + 17) % 100) / 100.0;
      final phase = i * 0.61;
      final speed = 0.3 + (i % 7) * 0.07;

      final x =
          size.width * ((baseX + 0.05 * math.sin(t * speed + phase) + 1.0) % 1.0);
      final y = size.height *
          ((baseY + 0.06 * math.cos(t * (speed * 0.8) + phase * 1.2) + 1.0) %
              1.0);

      final pulse = 0.5 + 0.5 * math.sin(t * (0.8 + (i % 5) * 0.1) + phase);
      final r = 0.8 + pulse * 1.4;
      final alpha = 0.03 + pulse * 0.06;

      canvas.drawCircle(
        Offset(x, y),
        r,
        _particlePaint..color = primary.withValues(alpha: alpha),
      );
    }
  }

  static Paint _blobPaint({required double radius, required Color color}) {
    return Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.primary != primary;
}
