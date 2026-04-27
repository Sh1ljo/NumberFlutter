import 'package:flutter/material.dart';
import '../../../models/neural_network.dart';
import 'neural_painter.dart';
import 'neuron_widget.dart';
import 'neuron_detail_sheet.dart';

class NeuralCanvas extends StatefulWidget {
  final NeuralNetwork network;

  const NeuralCanvas({super.key, required this.network});

  @override
  State<NeuralCanvas> createState() => _NeuralCanvasState();
}

class _NeuralCanvasState extends State<NeuralCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _connCtrl;

  static const double _layerSpacing = 120.0;
  static const double _neuronSpacing = 80.0;
  static const double _neuronSize = 48.0;
  static const double _canvasPadding = 80.0;

  @override
  void initState() {
    super.initState();
    _connCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _connCtrl.dispose();
    super.dispose();
  }

  Map<String, Offset> _buildPositions(List<NeuralLayer> layers, Size canvas) {
    final positions = <String, Offset>{};
    final canvasCenterY = canvas.height / 2;

    for (final layer in layers) {
      final x = _canvasPadding + layer.index * _layerSpacing + _neuronSize / 2;
      final totalH = (layer.neurons.length - 1) * _neuronSpacing;
      final startY = canvasCenterY - totalH / 2;
      for (int i = 0; i < layer.neurons.length; i++) {
        final neuron = layer.neurons[i];
        positions[neuron.id] = Offset(x, startY + i * _neuronSpacing);
      }
    }
    return positions;
  }

  Size _canvasSize(List<NeuralLayer> layers) {
    final maxNeurons =
        layers.fold<int>(0, (m, l) => l.neurons.length > m ? l.neurons.length : m);
    final w = _canvasPadding * 2 + (layers.length - 1) * _layerSpacing + _neuronSize;
    final h = _canvasPadding * 2 + (maxNeurons - 1) * _neuronSpacing + _neuronSize;
    return Size(w.clamp(300, double.infinity), h.clamp(250, double.infinity));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final layers = widget.network.layers;
    final canvasSize = _canvasSize(layers);

    return ClipRect(
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.4,
        maxScale: 3.0,
        child: SizedBox(
          width: canvasSize.width,
          height: canvasSize.height,
          child: AnimatedBuilder(
            animation: _connCtrl,
            builder: (_, __) {
              final positions = _buildPositions(layers, canvasSize);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Subtle dot-grid background
                  Positioned.fill(
                    child: CustomPaint(painter: _GridPainter(cs: cs)),
                  ),
                  // Animated connection lines
                  Positioned.fill(
                    child: CustomPaint(
                      painter: NeuralPainter(
                        layers: layers,
                        neuronPositions: positions,
                        animationValue: _connCtrl.value,
                        cs: cs,
                      ),
                    ),
                  ),
                  // Neuron widgets
                  for (final layer in layers)
                    for (final neuron in layer.neurons)
                      if (positions[neuron.id] != null)
                        Positioned(
                          left: positions[neuron.id]!.dx - _neuronSize / 2,
                          top: positions[neuron.id]!.dy - _neuronSize / 2,
                          child: NeuronWidget(
                            neuron: neuron,
                            onTap: () =>
                                NeuronDetailSheet.show(context, neuron),
                          ),
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final ColorScheme cs;
  _GridPainter({required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cs.outlineVariant.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.0;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
