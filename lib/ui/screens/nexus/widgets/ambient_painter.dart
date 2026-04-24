import 'package:flutter/material.dart';
import 'dart:math' as math;

class AmbientPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color surface;
  final Color outline;

  const AmbientPainter({
    required this.progress,
    required this.primary,
    required this.surface,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final t = progress * math.pi * 2;

    // Base gradient
    final baseRect = Offset.zero & size;
    final base = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.15,
        colors: [
          surface.withValues(alpha: 0.10),
          surface.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(baseRect);
    canvas.drawRect(baseRect, base);

    // Drifting glow blobs
    const glowSeeds = <(double x, double y, double r, double phase)>[
      (0.18, 0.22, 0.22, 0.3),
      (0.82, 0.30, 0.25, 1.1),
      (0.42, 0.74, 0.30, 2.2),
      (0.68, 0.60, 0.18, 2.9),
    ];
    for (final seed in glowSeeds) {
      final cx = w * seed.$1 + math.sin(t * 0.45 + seed.$4) * 24;
      final cy = h * seed.$2 + math.cos(t * 0.37 + seed.$4 * 1.2) * 18;
      final radius = math.min(w, h) * seed.$3;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawCircle(Offset(cx, cy), radius, glow);
    }

    // Drifting particles
    const particleCount = 36;
    for (int i = 0; i < particleCount; i++) {
      final baseX = ((i * 73) % 100) / 100.0;
      final baseY = ((i * 37 + 17) % 100) / 100.0;
      final phase = i * 0.61;
      final speed = 0.35 + (i % 7) * 0.08;

      final x = w * ((baseX + 0.04 * math.sin(t * speed + phase) + 1.0) % 1.0);
      final y = h *
          ((baseY + 0.05 * math.cos(t * (speed * 0.85) + phase * 1.2) + 1.0) %
              1.0);

      final pulse = 0.5 + 0.5 * math.sin(t * (0.9 + (i % 5) * 0.12) + phase);
      final r = 0.9 + pulse * 1.9;
      final alpha = 0.10 + pulse * 0.22;

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = primary.withValues(alpha: alpha),
      );

      if (i % 4 == 0) {
        canvas.drawCircle(
          Offset(x, y),
          r + 3.0 + pulse * 4.0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = outline.withValues(alpha: 0.07 + pulse * 0.04),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AmbientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.surface != surface ||
        oldDelegate.outline != outline;
  }
}
