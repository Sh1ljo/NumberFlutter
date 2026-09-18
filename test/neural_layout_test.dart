import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_flutter/models/neural_network.dart';
import 'package:number_flutter/ui/screens/neural_network/neural_canvas.dart';

/// Builds a network with [counts] neurons in layer i, using the same slot-based
/// ids `branchNeuron` produces.
List<NeuralLayer> _layers(List<int> counts) {
  final layers = <NeuralLayer>[];
  for (var i = 0; i < counts.length; i++) {
    layers.add(NeuralLayer(
      index: i,
      neurons: List.generate(
        counts[i],
        (slot) => NeuralNeuron(id: 'layer_${i}_neuron_$slot'),
      ),
    ));
  }
  return layers;
}

/// The old, buggy bounds: derived from the hardcoded target pyramid rather
/// than from the neurons that actually exist. Kept here so the regression
/// test can prove the new behaviour differs where it mattered.
Rect _targetBasedBounds(List<NeuralLayer> layers, Size canvas) {
  final canvasCenterY = canvas.height / 2;
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final layer in layers) {
    final x = NeuralLayout.canvasPadding +
        layer.index * NeuralLayout.layerSpacing +
        NeuralLayout.neuronSize / 2;
    final target = NeuralNetwork.targetNeuronCountForLayer(layer.index);
    final slots = target > 0
        ? target
        : (layer.neurons.isEmpty ? 1 : layer.neurons.length);
    final totalH = (slots - 1) * NeuralLayout.neuronSpacing;
    final topY = canvasCenterY - totalH / 2;
    final bottomY = topY + totalH;
    minX = x < minX ? x : minX;
    maxX = x > maxX ? x : maxX;
    minY = topY < minY ? topY : minY;
    maxY = bottomY > maxY ? bottomY : maxY;
  }
  final r = NeuralLayout.neuronSize / 2;
  return Rect.fromLTRB(minX - r, minY - r, maxX + r, maxY + r);
}

void main() {
  const layout = NeuralLayout();

  /// Every state the network passes through as the player branches from a
  /// single input neuron to the full 22-neuron pyramid, one branch at a time.
  const growthSequence = <List<int>>[
    [1],
    [1, 1],
    [1, 2],
    [1, 2, 1],
    [1, 2, 2],
    [1, 2, 3],
    [1, 2, 4],
    [1, 2, 4, 2],
    [1, 2, 4, 4],
    [1, 2, 4, 6],
    [1, 2, 4, 8],
    [1, 2, 4, 8, 2],
    [1, 2, 4, 8, 4],
    [1, 2, 4, 8, 4, 1],
    [1, 2, 4, 8, 4, 2],
    [1, 2, 4, 8, 4, 2, 1],
  ];

  group('content bounds', () {
    test('is centred on the real neurons at every growth step', () {
      for (final counts in growthSequence) {
        final layers = _layers(counts);
        final canvas = layout.canvasSize(layers);
        final positions = layout.positions(layers, canvas);
        final bounds = layout.contentBounds(positions)!;

        final ys = positions.values.map((p) => p.dy).toList();
        final trueCentre =
            (ys.reduce((a, b) => a < b ? a : b) +
                    ys.reduce((a, b) => a > b ? a : b)) /
                2;

        expect(bounds.center.dy, closeTo(trueCentre, 0.01),
            reason: 'off-centre for $counts');
      }
    });

    test('tightly encloses the neurons, radius included', () {
      final layers = _layers([1, 2, 4, 2]);
      final canvas = layout.canvasSize(layers);
      final positions = layout.positions(layers, canvas);
      final bounds = layout.contentBounds(positions)!;
      const r = NeuralLayout.neuronSize / 2;

      for (final p in positions.values) {
        expect(bounds.contains(p), isTrue);
        expect(p.dy - r, greaterThanOrEqualTo(bounds.top - 0.01));
        expect(p.dy + r, lessThanOrEqualTo(bounds.bottom + 0.01));
      }
      // No slack beyond one radius on any edge.
      final ys = positions.values.map((p) => p.dy).toList();
      expect(bounds.top,
          closeTo(ys.reduce((a, b) => a < b ? a : b) - r, 0.01));
      expect(bounds.bottom,
          closeTo(ys.reduce((a, b) => a > b ? a : b) + r, 0.01));
    });

    test('returns null for an empty network instead of an infinite rect', () {
      expect(layout.contentBounds(const {}), isNull);
    });
  });

  group('regression: partly-filled layers used to render off-centre', () {
    test('the reported 2-of-8 case was 80px out and now is not', () {
      // Layers 0(1), 1(2), 2(4), 3(2 of 8) — the state right after the first
      // two parents in layer 2 branch.
      final layers = _layers([1, 2, 4, 2]);
      final canvas = layout.canvasSize(layers);
      final positions = layout.positions(layers, canvas);

      final ys = positions.values.map((p) => p.dy).toList();
      final trueCentre =
          (ys.reduce((a, b) => a < b ? a : b) +
                  ys.reduce((a, b) => a > b ? a : b)) /
              2;

      final oldBounds = _targetBasedBounds(layers, canvas);
      final newBounds = layout.contentBounds(positions)!;

      expect((oldBounds.center.dy - trueCentre).abs(), closeTo(80.0, 0.01),
          reason: 'this is the bug the user reported');
      expect((newBounds.center.dy - trueCentre).abs(), lessThan(0.01));
      // The old box was also far taller than the content, so the view
      // zoomed out over empty canvas.
      expect(oldBounds.height, greaterThan(newBounds.height));
    });

    test('old bounds drifted on many steps; new bounds never do', () {
      var stepsOldWasWrong = 0;
      for (final counts in growthSequence) {
        final layers = _layers(counts);
        final canvas = layout.canvasSize(layers);
        final positions = layout.positions(layers, canvas);
        final ys = positions.values.map((p) => p.dy).toList();
        final trueCentre =
            (ys.reduce((a, b) => a < b ? a : b) +
                    ys.reduce((a, b) => a > b ? a : b)) /
                2;

        if ((_targetBasedBounds(layers, canvas).center.dy - trueCentre).abs() >
            0.01) {
          stepsOldWasWrong++;
        }
        expect(
            (layout.contentBounds(positions)!.center.dy - trueCentre).abs(),
            lessThan(0.01),
            reason: 'new bounds off-centre for $counts');
      }
      expect(stepsOldWasWrong, greaterThan(4),
          reason: 'the old behaviour should be demonstrably broken');
    });
  });

  group('fit transform', () {
    test('lands the content centre on the viewport centre', () {
      const viewport = Size(390, 520);
      for (final counts in growthSequence) {
        final layers = _layers(counts);
        final canvas = layout.canvasSize(layers);
        final positions = layout.positions(layers, canvas);
        final m = layout.fitTransform(viewport, positions)!;
        final bounds = layout.contentBounds(positions)!;

        final mapped = MatrixUtils.transformPoint(m, bounds.center);
        expect(mapped.dx, closeTo(viewport.width / 2, 0.01),
            reason: 'x off for $counts');
        expect(mapped.dy, closeTo(viewport.height / 2, 0.01),
            reason: 'y off for $counts');
      }
    });

    test('a shorter viewport shifts the content up, not off the bottom', () {
      // This is what the bottom nav bar inset changes: the canvas viewport
      // used to include the ~85px hidden behind the bar.
      final layers = _layers([1, 2, 4, 8, 4, 2, 1]);
      final canvas = layout.canvasSize(layers);
      final positions = layout.positions(layers, canvas);
      final bounds = layout.contentBounds(positions)!;

      const full = Size(390, 605);
      final honest =
          Size(full.width, full.height - 85); // minus nav bar chrome

      final withBar = layout.fitTransform(full, positions)!;
      final without = layout.fitTransform(honest, positions)!;

      final centreWithBar =
          MatrixUtils.transformPoint(withBar, bounds.center);
      final centreWithout =
          MatrixUtils.transformPoint(without, bounds.center);

      expect(centreWithout.dy, lessThan(centreWithBar.dy),
          reason: 'honest viewport must pull content up above the nav bar');
      expect(centreWithout.dy, closeTo(honest.height / 2, 0.01));
    });

    test('respects the scale clamp', () {
      final single = _layers([1]);
      final canvas = layout.canvasSize(single);
      final positions = layout.positions(single, canvas);
      // A single 48px neuron in a large viewport would want a huge scale.
      final m = layout.fitTransform(const Size(2000, 2000), positions)!;
      final scale = m.getMaxScaleOnAxis();
      expect(scale, lessThanOrEqualTo(NeuralLayout.maxScale + 0.001));
      expect(scale, greaterThanOrEqualTo(NeuralLayout.minScale - 0.001));
    });

    test('degenerate viewports yield no transform rather than NaN', () {
      final layers = _layers([1, 2]);
      final canvas = layout.canvasSize(layers);
      final positions = layout.positions(layers, canvas);
      expect(layout.fitTransform(Size.zero, positions), isNull);
      expect(layout.fitTransform(const Size(0, 500), positions), isNull);
      expect(layout.fitTransform(const Size(390, 520), const {}), isNull);
    });
  });

  group('positions', () {
    test('a neuron never moves as siblings fill in around it', () {
      // Slot-based placement is what makes this true; it is also what made
      // the target-based fit box wrong, so pin the behaviour down.
      final partial = _layers([1, 2, 4, 2]);
      final full = _layers([1, 2, 4, 8]);
      final pPartial =
          layout.positions(partial, layout.canvasSize(partial));
      final pFull = layout.positions(full, layout.canvasSize(full));

      for (final id in pPartial.keys) {
        expect(pFull[id], pPartial[id], reason: '$id moved');
      }
    });

    test('canvas size is stable while a layer fills up', () {
      // If it were not, the size-change trigger would mask the missing
      // neuron-count trigger.
      final sizes = [
        layout.canvasSize(_layers([1, 2, 4, 2])),
        layout.canvasSize(_layers([1, 2, 4, 4])),
        layout.canvasSize(_layers([1, 2, 4, 8])),
      ];
      expect(sizes.toSet().length, 1);
    });
  });
}
