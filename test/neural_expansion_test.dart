import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/models/neural_network.dart';

/// The hand-written eligibility rule the generalized formula replaced.
bool _legacyEligible(int layerIndex, int i) {
  if (layerIndex < 0 || layerIndex >= 6) return false;
  if (layerIndex < 3) return true;
  if (layerIndex == 3) return i <= 1;
  if (layerIndex == 4) return i == 0;
  if (layerIndex == 5) return i == 0;
  return false;
}

Future<GameState> _unlockedGame({required int prestigeCount}) async {
  SharedPreferences.setMockInitialValues({});
  final gs = GameState();
  await gs.ready;
  gs.prestigeCount = prestigeCount;
  gs.researchNodes.firstWhere((n) => n.id == 'neural_genesis').level = 1;
  gs.neuralNetwork = NeuralNetwork(
    layers: [
      NeuralLayer(index: 0, neurons: [NeuralNeuron(id: 'layer_0_neuron_0')]),
    ],
    unlocked: true,
  );
  gs.number = BigInt.from(10).pow(40);
  return gs;
}

/// Branches every branchable neuron, wave by wave, until nothing can.
void _expandFully(GameState gs) {
  for (var guard = 0; guard < 100; guard++) {
    final candidates = [
      for (final l in gs.neuralNetwork.layers)
        for (final n in l.neurons)
          if (gs.canBranchNeuron(n.id)) n.id,
    ];
    if (candidates.isEmpty) return;
    for (final id in candidates) {
      expect(gs.branchNeuron(id), isTrue);
    }
  }
}

List<int> _layerCounts(NeuralNetwork n) =>
    [for (final l in n.layers) l.neurons.length];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('topology', () {
    test('generalized eligibility equals the legacy pyramid rules', () {
      // Only real slots: the legacy rule said "true" for indices past a
      // layer's size, which never exist.
      for (var layer = -1; layer <= 7; layer++) {
        final slots = NeuralNetwork.targetNeuronCountForLayer(layer);
        for (var i = 0; i < slots; i++) {
          expect(
            NeuralNetwork.isEligibleParentIndex(layer, i),
            _legacyEligible(layer, i),
            reason: 'layer $layer, index $i',
          );
        }
      }
    });

    test('pyramid is 22 neurons, full network is 31', () {
      final pyramid = NeuralNetwork.layerTargets
          .take(NeuralNetwork.pyramidLayerCount)
          .fold<int>(0, (a, b) => a + b);
      final full = NeuralNetwork.layerTargets.fold<int>(0, (a, b) => a + b);
      expect(pyramid, 22);
      expect(full, 31);
    });

    test('below the first deep gate the network stops at the pyramid',
        () async {
      final gs = await _unlockedGame(prestigeCount: 17);
      addTearDown(gs.dispose);
      _expandFully(gs);
      expect(_layerCounts(gs.neuralNetwork), [1, 2, 4, 8, 4, 2, 1]);
      final output = gs.neuralNetwork.layers.last.neurons.single;
      expect(
          gs.neuronBranchBlockReason(output.id), NeuronBranchBlock.depthLocked);
      expect(gs.nextDeepLayerGate, 18);
    });

    test('each deep gate unlocks exactly one more layer', () async {
      final gs = await _unlockedGame(prestigeCount: 22);
      addTearDown(gs.dispose);
      _expandFully(gs);
      expect(_layerCounts(gs.neuralNetwork), [1, 2, 4, 8, 4, 2, 1, 2, 4]);
    });

    test('at the last gate every layer fills to its target', () async {
      final gs = await _unlockedGame(prestigeCount: 30);
      addTearDown(gs.dispose);
      _expandFully(gs);
      expect(_layerCounts(gs.neuralNetwork), NeuralNetwork.layerTargets);
      final last = gs.neuralNetwork.layers.last.neurons.single;
      expect(gs.neuronBranchBlockReason(last.id), NeuronBranchBlock.terminal);
    });

    test('deep layers raise the multiplier ceiling', () async {
      final gs = await _unlockedGame(prestigeCount: 30);
      addTearDown(gs.dispose);
      gs.neuralNetwork.loss = 0.001;
      final pyramidRaw = gs.neuralLossRawMultiplier;
      _expandFully(gs);
      gs.neuralNetwork.loss = 0.001;
      expect(gs.neuralLossRawMultiplier, greaterThan(pyramidRaw + 30));
    });

    test('deep gradient levels cost more than pyramid ones', () {
      final shallow = NeuralNeuron(id: 'layer_6_neuron_0');
      final deep = NeuralNeuron(id: 'layer_8_neuron_0');
      expect(
          deep.baseGradientCost, shallow.baseGradientCost * BigInt.from(100));
    });
  });

  group('epochs', () {
    test('an epoch resets training and gradients but keeps topology', () async {
      final gs = await _unlockedGame(prestigeCount: 20);
      addTearDown(gs.dispose);
      _expandFully(gs);
      for (final l in gs.neuralNetwork.layers) {
        for (final n in l.neurons) {
          n.gradientLevel = 5;
          n.activationFn = 'relu';
        }
      }
      final shape = _layerCounts(gs.neuralNetwork);

      gs.neuralNetwork.loss = 0.5;
      expect(gs.canStartEpoch, isFalse);
      expect(gs.startEpoch(), isFalse);

      gs.neuralNetwork.loss = 0.005;
      gs.neuralNetwork.lowestLossEver = 0.005;
      expect(gs.startEpoch(), isTrue);

      final nn = gs.neuralNetwork;
      expect(nn.epochs, 1);
      expect(nn.loss, 1.0);
      expect(nn.lowestLossEver, 0.005);
      expect(_layerCounts(nn), shape);
      for (final l in nn.layers) {
        for (final n in l.neurons) {
          expect(n.gradientLevel, 0);
          expect(n.activationFn, 'relu');
        }
      }
      expect(nn.gradientCap, NeuralNetwork.baseGradientCap + 1);
      expect(gs.epochProductionMultiplier, closeTo(1.1, 1e-9));
      expect(gs.unlockedAchievements, contains('epoch_1'));
    });

    test('each epoch trains slower than the last', () async {
      final gs = await _unlockedGame(prestigeCount: 0);
      addTearDown(gs.dispose);
      final k0 = gs.neuralDecayRate / gs.neuralNetworkStrength;
      gs.neuralNetwork.loss = 0.001;
      gs.startEpoch();
      final k1 = gs.neuralDecayRate / gs.neuralNetworkStrength;
      expect(k1, closeTo(k0 * 0.85, 1e-12));
    });

    test('gradient cap stops growing at 15', () {
      final nn = NeuralNetwork(layers: [], unlocked: true, epochs: 40);
      expect(nn.gradientCap, NeuralNetwork.maxGradientCap);
    });
  });

  group('save format', () {
    test('a v4 save without epochs loads at epoch 0', () {
      final nn = NeuralNetwork.fromJson({
        'version': 4,
        'layers': [
          {
            'index': 0,
            'neurons': [
              {'id': 'layer_0_neuron_0', 'gradientLevel': 3},
            ],
          },
        ],
        'unlocked': true,
        'loss': 0.4,
        'lowestLossEver': 0.3,
      });
      expect(nn.epochs, 0);
      expect(nn.layers.single.neurons.single.gradientLevel, 3);
    });

    test('epochs survive a round trip', () {
      final nn = NeuralNetwork(layers: [], unlocked: true, epochs: 3);
      expect(NeuralNetwork.fromJsonString(nn.toJsonString()).epochs, 3);
    });
  });
}
