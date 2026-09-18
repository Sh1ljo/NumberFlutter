import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import '../../../models/neural_network.dart';
import 'neural_painter.dart';
import 'neuron_widget.dart';
import 'neuron_detail_sheet.dart';

/// Pure layout maths for the neural canvas, kept out of the State so it can be
/// tested directly — this is where the "network drifts off-centre as it grows"
/// bug lived.
class NeuralLayout {
  const NeuralLayout();

  static const double layerSpacing = 120.0;
  static const double neuronSpacing = 80.0;
  static const double neuronSize = 48.0;
  static const double canvasPadding = 80.0;
  static const double minScale = 0.3;
  static const double maxScale = 3.0;
  static const double fitMargin = 40.0;

  /// Canvas is sized for each layer's *target* capacity so it doesn't resize
  /// every time a neuron is branched in.
  Size canvasSize(List<NeuralLayer> layers) {
    if (layers.isEmpty) return const Size(600, 600);

    final maxLayerIndex =
        layers.map((l) => l.index).reduce((a, b) => a > b ? a : b);
    final w = canvasPadding * 2 + maxLayerIndex * layerSpacing + neuronSize;

    int maxSlots = 0;
    for (final l in layers) {
      final target = NeuralNetwork.targetNeuronCountForLayer(l.index);
      final slots = target > 0 ? target : l.neurons.length;
      if (slots > maxSlots) maxSlots = slots;
    }
    if (maxSlots < 1) maxSlots = 1;
    final h = canvasPadding * 2 + (maxSlots - 1) * neuronSpacing + neuronSize;

    return Size(w.clamp(400, double.infinity), h.clamp(400, double.infinity));
  }

  /// Position a neuron by its *slot* (parsed from the id) within the layer's
  /// *target* neuron count, not its current count. This keeps existing
  /// neurons anchored as siblings appear, and makes new children of a
  /// branched parent show up directly under that parent's column rather
  /// than drifting through the centre of the canvas.
  Map<String, Offset> positions(List<NeuralLayer> layers, Size canvas) {
    final result = <String, Offset>{};
    final canvasCenterY = canvas.height / 2;

    for (final layer in layers) {
      final x = canvasPadding + layer.index * layerSpacing + neuronSize / 2;
      final target = NeuralNetwork.targetNeuronCountForLayer(layer.index);
      final slots = target > 0 ? target : layer.neurons.length;
      final totalH = (slots - 1) * neuronSpacing;
      final startY = canvasCenterY - totalH / 2;
      for (int i = 0; i < layer.neurons.length; i++) {
        final neuron = layer.neurons[i];
        final parsed = int.tryParse(neuron.id.split('_').last);
        final slot =
            (parsed != null && parsed >= 0 && parsed < slots) ? parsed : i;
        result[neuron.id] = Offset(x, startY + slot * neuronSpacing);
      }
    }
    return result;
  }

  /// Bounding box of the neurons that **actually exist**, inflated by the
  /// neuron radius.
  ///
  /// This used to be derived from `targetNeuronCountForLayer` — the hardcoded
  /// 1,2,4,8,4,2,1 pyramid — rather than from real positions. Since a layer
  /// fills one parent at a time, a partly-populated layer left the box far
  /// larger than the content: with layers 0(1), 1(2), 2(4), 3(2-of-8) the
  /// neurons spanned y 104..504 (centre 304) while the box spanned 80..688
  /// (centre 384). The network rendered 80px high and over-zoomed, and only
  /// self-corrected once every slot happened to fill.
  Rect? contentBounds(Map<String, Offset> positions) {
    if (positions.isEmpty) return null;
    final r = neuronSize / 2;
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final p in positions.values) {
      if (p.dx - r < minX) minX = p.dx - r;
      if (p.dx + r > maxX) maxX = p.dx + r;
      if (p.dy - r < minY) minY = p.dy - r;
      if (p.dy + r > maxY) maxY = p.dy + r;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Transform that fits [positions] into [viewport], centred.
  ///
  /// [viewport] must exclude any chrome drawn over the canvas — notably the
  /// bottom nav bar, which is a sibling painted on top of the active screen.
  Matrix4? fitTransform(Size viewport, Map<String, Offset> positions) {
    if (viewport.width <= 0 || viewport.height <= 0) return null;
    final bounds = contentBounds(positions);
    if (bounds == null) return null;

    final contentW = bounds.width + fitMargin * 2;
    final contentH = bounds.height + fitMargin * 2;
    if (contentW <= 0 || contentH <= 0) return null;

    final scaleX = viewport.width / contentW;
    final scaleY = viewport.height / contentH;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(minScale, maxScale);

    final dx = viewport.width / 2 - bounds.center.dx * scale;
    final dy = viewport.height / 2 - bounds.center.dy * scale;

    return Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }
}

class NeuralCanvas extends StatefulWidget {
  final NeuralNetwork network;
  final GlobalKey? neuralNeuronKey;

  /// Id of the neuron [neuralNeuronKey] attaches to, so the tutorial can
  /// spotlight it. Defaults to the input neuron.
  final String tutorialNeuronId;

  const NeuralCanvas({
    super.key,
    required this.network,
    this.neuralNeuronKey,
    this.tutorialNeuronId = 'layer_0_neuron_0',
  });

  @override
  State<NeuralCanvas> createState() => _NeuralCanvasState();
}

class _NeuralCanvasState extends State<NeuralCanvas>
    with SingleTickerProviderStateMixin {
  static const NeuralLayout _layout = NeuralLayout();

  late final AnimationController _connCtrl;
  late final AnimationController _pulseCtrl;
  late TransformationController _transformCtrl;
  Size? _lastViewport;
  Size? _lastCanvas;
  String? _lastNetworkSignature;

  @override
  void initState() {
    super.initState();
    // Slow connection pulse so it reads as signal travel, not a strobe.
    _connCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
    // One shared breathing controller for every neuron. Each NeuronWidget
    // used to own its own, which meant up to 22 concurrent controllers all
    // ticking at 60fps for a single visual effect.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _transformCtrl = TransformationController();
  }

  @override
  void dispose() {
    _connCtrl.dispose();
    _pulseCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  /// Changes whenever the set of neurons changes, so the view re-fits when a
  /// neuron is added — not only when a whole layer is. The canvas is sized
  /// from target capacity, so neuron additions alone never resized it and the
  /// old size-change-only trigger simply never fired for them.
  String _signatureFor(List<NeuralLayer> layers) =>
      layers.map((l) => '${l.index}:${l.neurons.length}').join(',');

  void _applyFit(Size viewport, Map<String, Offset> positions) {
    final transform = _layout.fitTransform(viewport, positions);
    if (transform != null) _transformCtrl.value = transform;
  }

  void _recenter() {
    final viewport = _lastViewport;
    if (viewport == null) return;
    final layers = widget.network.layers;
    final canvas = _layout.canvasSize(layers);
    _applyFit(viewport, _layout.positions(layers, canvas));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final layers = widget.network.layers;
    final canvasSize = _layout.canvasSize(layers);
    // Hoisted out of the AnimatedBuilder: this used to be rebuilt, along with
    // every Positioned/NeuronWidget child, on all 60 animation frames.
    final positions = _layout.positions(layers, canvasSize);
    final signature = _signatureFor(layers);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastViewport != viewport ||
            _lastCanvas != canvasSize ||
            _lastNetworkSignature != signature) {
          _lastViewport = viewport;
          _lastCanvas = canvasSize;
          _lastNetworkSignature = signature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyFit(viewport, positions);
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                boundaryMargin: const EdgeInsets.all(400),
                constrained: false,
                minScale: NeuralLayout.minScale,
                maxScale: NeuralLayout.maxScale,
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _GridPainter(cs: cs)),
                        ),
                      ),
                      // Only the connection pulse is animated per-frame, so
                      // only it sits under the AnimatedBuilder.
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _connCtrl,
                            builder: (_, __) => CustomPaint(
                              painter: NeuralPainter(
                                layers: layers,
                                neuronPositions: positions,
                                animationValue: _connCtrl.value,
                                cs: cs,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final layer in layers)
                        for (final neuron in layer.neurons)
                          if (positions[neuron.id] != null)
                            Positioned(
                              left: positions[neuron.id]!.dx - NeuralLayout.neuronSize / 2,
                              top: positions[neuron.id]!.dy - NeuralLayout.neuronSize / 2,
                              child: NeuronWidget(
                                key: neuron.id == widget.tutorialNeuronId
                                    ? widget.neuralNeuronKey
                                    : null,
                                neuron: neuron,
                                pulse: _pulseCtrl,
                                highlight:
                                    widget.network.canNeuronBranch(neuron.id),
                                onTap: () {
                                  context.read<GameState>().onNeuronTapped();
                                  NeuronDetailSheet.show(context, neuron);
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
            // Without this there is no way back from a pan that pushes the
            // network off-screen.
            Positioned(
              right: 8,
              top: 8,
              child: Tooltip(
                message: 'Re-center network',
                child: Material(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: InkWell(
                    onTap: _recenter,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.center_focus_strong_outlined,
                        size: 18,
                        color: cs.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.cs != cs;
}
