import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/neural_network.dart';

class NeuralPainter extends CustomPainter {
  final List<NeuralLayer> layers;
  final Map<String, Offset> neuronPositions;
  final double animationValue; // 0.0 → 1.0, looping
  final ColorScheme cs;

  NeuralPainter({
    required this.layers,
    required this.neuronPositions,
    required this.animationValue,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (layers.length < 2) return;

    final linePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    int lineIndex = 0;
    int totalLines = 0;
    for (int l = 0; l < layers.length - 1; l++) {
      totalLines += layers[l].neurons.length * layers[l + 1].neurons.length;
    }

    for (int l = 0; l < layers.length - 1; l++) {
      final fromLayer = layers[l];
      final toLayer = layers[l + 1];

      for (final fromNeuron in fromLayer.neurons) {
        final from = neuronPositions[fromNeuron.id];
        if (from == null) continue;

        for (final toNeuron in toLayer.neurons) {
          final to = neuronPositions[toNeuron.id];
          if (to == null) continue;

          // Base connection line
          linePaint.color = cs.primary.withValues(alpha: 0.12);
          canvas.drawLine(from, to, linePaint);

          // Animated pulse dot travelling along the line
          final phase =
              (lineIndex / math.max(totalLines, 1) + animationValue) % 1.0;
          final pulsePos = Offset(
            from.dx + (to.dx - from.dx) * phase,
            from.dy + (to.dy - from.dy) * phase,
          );
          dotPaint.color = cs.primary.withValues(alpha: 0.55);
          canvas.drawCircle(pulsePos, 2.0, dotPaint);

          lineIndex++;
        }
      }
    }
  }

  @override
  bool shouldRepaint(NeuralPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.layers != layers ||
      oldDelegate.neuronPositions != neuronPositions;
}
