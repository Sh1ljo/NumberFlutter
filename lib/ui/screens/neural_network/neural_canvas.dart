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
  late TransformationController _transformCtrl;
  Size? _lastViewport;
  Size? _lastCanvas;

  static const double _layerSpacing = 120.0;
  static const double _neuronSpacing = 80.0;
  static const double _neuronSize = 48.0;
  static const double _canvasPadding = 80.0;
  static const double _minScale = 0.3;
  static const double _maxScale = 3.0;

  @override
  void initState() {
    super.initState();
    // Slow down the connection animation to make the pulse travel more gently.
    // Increased from 2 seconds to 5 seconds per loop.
    _connCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
    _transformCtrl = TransformationController();
  }

  @override
  void dispose() {
    _connCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _fitAndCenter(Size viewport, Size canvas, List<NeuralLayer> layers) {
    if (viewport.width <= 0 || viewport.height <= 0) return;
    if (layers.isEmpty) return;

    final positions = _buildPositions(layers, canvas);
    if (positions.isEmpty) return;

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final pos in positions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dy > maxY) maxY = pos.dy;
    }
    final r = _neuronSize / 2;
    minX -= r;
    maxX += r;
    minY -= r;
    maxY += r;

    const margin = 40.0;
    final contentW = (maxX - minX) + margin * 2;
    final contentH = (maxY - minY) + margin * 2;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    final scaleX = viewport.width / contentW;
    final scaleY = viewport.height / contentH;
    final fitScale = scaleX < scaleY ? scaleX : scaleY;
    final scale = fitScale.clamp(_minScale, _maxScale);

    final dx = viewport.width / 2 - centerX * scale;
    final dy = viewport.height / 2 - centerY * scale;

    _transformCtrl.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  Map<String, Offset> _buildPositions(List<NeuralLayer> layers, Size canvas) {
    final positions = <String, Offset>{};
    final canvasCenterY = canvas.height / 2;

    for (final layer in layers) {
      final x = _canvasPadding + layer.index * _layerSpacing + _neuronSize / 2;
      final n = layer.neurons.length;
      final totalH = (n - 1) * _neuronSpacing;
      final startY = canvasCenterY - totalH / 2;
      for (int i = 0; i < n; i++) {
        positions[layer.neurons[i].id] = Offset(x, startY + i * _neuronSpacing);
      }
    }
    return positions;
  }

  Size _canvasSize(List<NeuralLayer> layers) {
    if (layers.isEmpty) return const Size(600, 600);

    // Width: enough for all layer columns
    final maxLayerIndex =
        layers.map((l) => l.index).reduce((a, b) => a > b ? a : b);
    final w = _canvasPadding * 2 + maxLayerIndex * _layerSpacing + _neuronSize;

    // Height: enough for the layer with the most neurons
    final maxNeurons =
        layers.map((l) => l.neurons.length).reduce((a, b) => a > b ? a : b);
    final h =
        _canvasPadding * 2 + (maxNeurons - 1) * _neuronSpacing + _neuronSize;

    return Size(w.clamp(400, double.infinity), h.clamp(400, double.infinity));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final layers = widget.network.layers;
    final canvasSize = _canvasSize(layers);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final viewportChanged = _lastViewport != viewport;
        final canvasChanged = _lastCanvas != canvasSize;
        if (viewportChanged || canvasChanged) {
          _lastViewport = viewport;
          _lastCanvas = canvasSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitAndCenter(viewport, canvasSize, layers);
          });
        }

        return InteractiveViewer(
          transformationController: _transformCtrl,
          boundaryMargin: const EdgeInsets.all(400),
          constrained: false,
          minScale: _minScale,
          maxScale: _maxScale,
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
                    Positioned.fill(
                      child: CustomPaint(painter: _GridPainter(cs: cs)),
                    ),
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
                    for (final layer in layers)
                      for (final neuron in layer.neurons)
                        if (positions[neuron.id] != null)
                          Positioned(
                            left: positions[neuron.id]!.dx - _neuronSize / 2,
                            top: positions[neuron.id]!.dy - _neuronSize / 2,
                            child: NeuronWidget(
                              neuron: neuron,
                              highlight:
                                  widget.network.canNeuronBranch(neuron.id),
                              onTap: () =>
                                  NeuronDetailSheet.show(context, neuron),
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
        );
      },
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
