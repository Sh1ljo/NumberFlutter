import 'package:flutter/material.dart';
import 'dart:math' as math;

class DotSpherePainter extends CustomPainter {
  final double angle;
  final Color primaryColor;
  static const int _n = 100;

  const DotSpherePainter({required this.angle, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.82;
    const goldenAngle = 2.399963229728653;

    final dots = <(double, double, double)>[];

    for (int i = 0; i < _n; i++) {
      final t = i / (_n - 1);
      final inclination = math.acos(1 - 2 * t);
      final azimuth = goldenAngle * i;

      final sx = math.sin(inclination) * math.cos(azimuth);
      final sy = math.sin(inclination) * math.sin(azimuth);
      final sz = math.cos(inclination);

      final osc = 1.0 + 0.045 * math.sin(angle * 3.2 + i * 0.31);

      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final rx = sx * cosA + sz * sinA;
      final rz = -sx * sinA + sz * cosA;

      final screenX = cx + rx * r * osc;
      final screenY = cy + sy * r * osc;
      final depth = (rz + 1) / 2;

      dots.add((screenX, screenY, depth));
    }

    dots.sort((a, b) => a.$3.compareTo(b.$3));

    for (final (dx, dy, depth) in dots) {
      final dotR = 1.0 + depth * 2.6;
      final alpha = 0.08 + depth * 0.72;
      canvas.drawCircle(
        Offset(dx, dy),
        dotR,
        Paint()
          ..color = primaryColor.withValues(alpha: alpha * 0.75)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(DotSpherePainter old) =>
      old.angle != angle || old.primaryColor != primaryColor;
}
