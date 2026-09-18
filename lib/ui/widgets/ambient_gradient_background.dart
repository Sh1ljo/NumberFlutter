import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slow, subtle grayscale backdrop for the main tap screen: two soft radial
/// blobs drift gently to add a bit of life without pulling focus from the
/// number or the tap area. Intentionally plain (no particles, no motifs) so
/// it reads as ambience rather than a second visual theme.
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
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _AmbientPainter(t: _controller.value),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final angle1 = t * 2 * math.pi;
    final angle2 = angle1 + math.pi;

    _paintBlob(
      canvas,
      center: Offset(
        size.width * (0.3 + 0.12 * math.cos(angle1)),
        size.height * (0.26 + 0.08 * math.sin(angle1)),
      ),
      radius: size.shortestSide * 0.55,
      color: Colors.white.withValues(alpha: 0.05),
    );

    _paintBlob(
      canvas,
      center: Offset(
        size.width * (0.72 + 0.1 * math.cos(angle2)),
        size.height * (0.76 + 0.09 * math.sin(angle2)),
      ),
      radius: size.shortestSide * 0.6,
      color: Colors.white.withValues(alpha: 0.035),
    );
  }

  void _paintBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t;
}
