import 'package:flutter/material.dart';
import 'dart:math' as math;

class NexusDispersePainter extends CustomPainter {
  final double stabilizeT;
  final double sphereAngle;
  final double ambientT;
  final Color primary;
  final Color outline;

  static const int _nSphere = 100;
  static const int _nParticles = 36;
  static const double _goldenAngle = 2.399963229728653;
  // Sphere widget is 180x180, r = 90 * 0.82
  static const double _sphereR = 90.0 * 0.82;

  const NexusDispersePainter({
    required this.stabilizeT,
    required this.sphereAngle,
    required this.ambientT,
    required this.primary,
    required this.outline,
  });

  List<Offset> _spherePositions(double cx, double cy) {
    final positions = <Offset>[];
    for (int i = 0; i < _nSphere; i++) {
      final t = i / (_nSphere - 1);
      final inclination = math.acos(1 - 2 * t);
      final azimuth = _goldenAngle * i;

      final sx = math.sin(inclination) * math.cos(azimuth);
      final sy = math.sin(inclination) * math.sin(azimuth);
      final sz = math.cos(inclination);

      final osc = 1.0 + 0.045 * math.sin(sphereAngle * 3.2 + i * 0.31);
      final cosA = math.cos(sphereAngle);
      final sinA = math.sin(sphereAngle);
      final rx = sx * cosA + sz * sinA;

      positions.add(Offset(cx + rx * _sphereR * osc, cy + sy * _sphereR * osc));
    }
    return positions;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // disperseT: 0→1 over stabilizeT range [0.45, 0.83]
    final disperseT = ((stabilizeT - 0.45) / 0.38).clamp(0.0, 1.0);
    final easedDisperse = Curves.easeInOut.transform(disperseT);

    // ambient drift fades in during latter half of disperse
    final driftBlend = ((stabilizeT - 0.67) / 0.28).clamp(0.0, 1.0);

    final spherePos = _spherePositions(cx, cy);

    // Which sphere dot indices are claimed by the 36 ambient particles
    final mappedIndices = <int>{};
    for (int i = 0; i < _nParticles; i++) {
      mappedIndices.add((i * _nSphere) ~/ _nParticles);
    }

    // --- 36 ambient-bound particles ---
    for (int i = 0; i < _nParticles; i++) {
      final baseX = ((i * 73) % 100) / 100.0;
      final baseY = ((i * 37 + 17) % 100) / 100.0;
      final phase = i * 0.61;
      final speed = 0.35 + (i % 7) * 0.08;

      final driftX = 0.04 * math.sin(ambientT * speed + phase) * driftBlend;
      final driftY =
          0.05 * math.cos(ambientT * (speed * 0.85) + phase * 1.2) * driftBlend;

      final ambX = size.width * ((baseX + driftX + 1.0) % 1.0);
      final ambY = size.height * ((baseY + driftY + 1.0) % 1.0);

      final dotIndex = (i * _nSphere) ~/ _nParticles;
      final start = spherePos[dotIndex];

      final curX = start.dx + (ambX - start.dx) * easedDisperse;
      final curY = start.dy + (ambY - start.dy) * easedDisperse;

      final pulse =
          0.5 + 0.5 * math.sin(ambientT * (0.9 + (i % 5) * 0.12) + phase);
      final r = 1.5 + (0.9 + pulse * 1.9 - 1.5) * easedDisperse;
      final depth = (dotIndex / _nSphere);
      final sphereAlpha = 0.08 + depth * 0.72;
      final ambientAlpha = 0.10 + pulse * 0.22;
      final alpha =
          (sphereAlpha * (1 - easedDisperse) + ambientAlpha * easedDisperse)
              .clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(curX, curY),
        r,
        Paint()..color = primary.withValues(alpha: alpha * 0.75),
      );

      if (i % 4 == 0 && disperseT > 0.6) {
        final ringAlpha =
            (0.07 + pulse * 0.04) * ((disperseT - 0.6) / 0.4).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(curX, curY),
          r + 3.0 + pulse * 4.0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = outline.withValues(alpha: ringAlpha),
        );
      }
    }

    // --- 64 scatter dots: burst outward and fade ---
    for (int i = 0; i < _nSphere; i++) {
      if (mappedIndices.contains(i)) continue;

      final start = spherePos[i];
      final dirX = start.dx - cx;
      final dirY = start.dy - cy;
      final len = math.sqrt(dirX * dirX + dirY * dirY);
      if (len < 0.001) continue;

      final scatter = 1.8 + (i % 5) * 0.4;
      final flyX = start.dx + (dirX / len) * easedDisperse * _sphereR * scatter;
      final flyY = start.dy + (dirY / len) * easedDisperse * _sphereR * scatter;
      final alpha = (0.4 * (1.0 - easedDisperse * 1.3)).clamp(0.0, 1.0);

      if (alpha < 0.01) continue;

      canvas.drawCircle(
        Offset(flyX, flyY),
        1.0 + easedDisperse * 0.8,
        Paint()..color = primary.withValues(alpha: alpha * 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(NexusDispersePainter old) =>
      old.stabilizeT != stabilizeT ||
      old.ambientT != ambientT ||
      old.sphereAngle != sphereAngle;
}
