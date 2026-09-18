import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/neural_network.dart';

class NeuralPainter extends CustomPainter {
  final List<NeuralLayer> layers;
  final Map<String, Offset> neuronPositions;
  /// Looping 0.0 → 1.0 driver. Passed as `repaint` so the pulse repaints
  /// straight off the controller without rebuilding any widgets.
  final Animation<double> animation;
  final ColorScheme cs;

  NeuralPainter({
    required this.layers,
    required this.neuronPositions,
    required this.animation,
    required this.cs,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (layers.length < 2) return;

    final animationValue = animation.value;
    final linePaint = Paint()
      ..color = cs.primary.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = cs.primary.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

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
          canvas.drawLine(from, to, linePaint);

          // Animated pulse dot travelling along the line.
          // Introduce a per‑connection random offset so not all dots move in lock‑step.
          // We derive a deterministic pseudo‑random offset from the line index to keep
          // the animation stable across rebuilds without storing extra state.
          // The offset range is [0, 0.5) to keep the variation subtle.
          final lineOffset = ((lineIndex * 73) % 100) / 200.0; // 0‑0.495 step
          final phase = (lineIndex / math.max(totalLines, 1) +
                  animationValue +
                  lineOffset) %
              1.0;
          final pulsePos = Offset(
            from.dx + (to.dx - from.dx) * phase,
            from.dy + (to.dy - from.dy) * phase,
          );
          canvas.drawCircle(pulsePos, 2.0, dotPaint);

          lineIndex++;
        }
      }
    }
  }

  @override
  bool shouldRepaint(NeuralPainter oldDelegate) =>
      // neuronPositions is rebuilt each time the network changes, so an
      // identity comparison on it was always true and made this unconditional.
      oldDelegate.animation != animation ||
      oldDelegate.cs != cs ||
      !identical(oldDelegate.layers, layers) ||
      oldDelegate.neuronPositions.length != neuronPositions.length;
}
