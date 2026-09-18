import 'package:flutter/material.dart';
import 'dart:math' as math;

class DotSpherePainter extends CustomPainter {
  final double angle;
  final Color primaryColor;

  /// Radius multiplier; the stabilize spin-up compresses the sphere below 1.
  final double scale;

  /// Radians between successive motion-blur ghosts. 0 disables the trail.
  final double trailSpread;

  /// 0..1 strength of the halo behind the sphere.
  final double glow;

  /// 0..1 opacity of the orbiting energy rings.
  final double ringStrength;

  static const int _n = 100;
  static const int _trailGhosts = 4;

  const DotSpherePainter({
    required this.angle,
    required this.primaryColor,
    this.scale = 1.0,
    this.trailSpread = 0.0,
    this.glow = 0.0,
    this.ringStrength = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.82 * scale;

    if (glow > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * (1.05 + glow * 0.35),
        Paint()
          ..color = primaryColor.withValues(alpha: 0.10 + glow * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + glow * 22),
      );
    }

    if (ringStrength > 0) _paintRings(canvas, cx, cy, r, behind: true);

    // Oldest ghost first so the live sphere draws on top.
    if (trailSpread > 0) {
      for (int g = _trailGhosts; g >= 1; g--) {
        final fade = 1.0 - g / (_trailGhosts + 1);
        _paintDots(canvas, cx, cy, r, angle - trailSpread * g, fade * 0.35);
      }
    }
    _paintDots(canvas, cx, cy, r, angle, 1.0);

    if (ringStrength > 0) _paintRings(canvas, cx, cy, r, behind: false);
  }

  void _paintDots(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double rot,
    double opacity,
  ) {
    const goldenAngle = 2.399963229728653;
    final cosA = math.cos(rot);
    final sinA = math.sin(rot);
    final dots = <(double, double, double)>[];

    for (int i = 0; i < _n; i++) {
      final t = i / (_n - 1);
      final inclination = math.acos(1 - 2 * t);
      final azimuth = goldenAngle * i;

      final sx = math.sin(inclination) * math.cos(azimuth);
      final sy = math.sin(inclination) * math.sin(azimuth);
      final sz = math.cos(inclination);

      final osc = 1.0 + 0.045 * math.sin(rot * 3.2 + i * 0.31);

      final rx = sx * cosA + sz * sinA;
      final rz = -sx * sinA + sz * cosA;

      dots.add((cx + rx * r * osc, cy + sy * r * osc, (rz + 1) / 2));
    }

    dots.sort((a, b) => a.$3.compareTo(b.$3));

    final paint = Paint()..style = PaintingStyle.fill;
    for (final (dx, dy, depth) in dots) {
      final dotR = 1.0 + depth * 2.6;
      final alpha = (0.08 + depth * 0.72) * 0.75 * opacity;
      paint.color = primaryColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), dotR, paint);
    }
  }

  /// Two tilted ellipses whipping around the sphere. Each is split into a back
  /// half (drawn before the dots) and a front half (drawn after), which sells
  /// the depth.
  void _paintRings(
    Canvas canvas,
    double cx,
    double cy,
    double r, {
    required bool behind,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int k = 0; k < 2; k++) {
      final tilt = (k == 0 ? 0.55 : -0.9) + angle * 0.05;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: r * (2.5 + k * 0.3),
        height: r * (0.55 + k * 0.15),
      );
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(tilt);
      // Arc sweep start rotates with the sphere so the rings visibly spin.
      final spin = angle * (k == 0 ? 1.6 : -1.3);
      final start = behind ? math.pi : 0.0;
      paint
        ..strokeWidth = behind ? 1.0 : 1.6
        ..color = primaryColor.withValues(
            alpha: ringStrength * (behind ? 0.25 : 0.6));
      canvas.drawArc(rect, start, math.pi, false, paint);
      // A bright comet segment travelling along the ring.
      final cometStart = spin % (2 * math.pi);
      final cometInFront = cometStart < math.pi;
      if (cometInFront != behind) {
        paint
          ..strokeWidth = 2.4
          ..color = primaryColor.withValues(alpha: ringStrength * 0.9);
        canvas.drawArc(rect, cometStart, 0.6, false, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DotSpherePainter old) =>
      old.angle != angle ||
      old.primaryColor != primaryColor ||
      old.scale != scale ||
      old.trailSpread != trailSpread ||
      old.glow != glow ||
      old.ringStrength != ringStrength;
}
