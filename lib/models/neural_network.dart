import 'dart:convert';
import 'dart:math' as math;

enum NeuronBranchBlock {
  alreadyBranched,
  terminal,
  depthLocked,
  previousLayerIncomplete,
  networkComplete,
  unknown,
}

const List<String> activationFunctions = [
  'linear',
  'relu',
  'sigmoid',
  'tanh',
];

const Map<String, String> activationFunctionDescriptions = {
  'linear':
      'Output equals input unchanged. Zero overhead — ideal for output layers where raw magnitudes matter.',
  'relu':
      'Zeroes out negatives, passes positives through. Fights vanishing gradients — the standard pick for deep hidden layers.',
  'sigmoid':
      'Squashes any value to 0–1. Smooth and bounded, best for binary decisions or probability outputs.',
  'tanh':
      'Squashes values to −1–1. Stronger gradients than sigmoid, excellent when data oscillates around zero.',
};

class NeuralNeuron {
  final String id;
  int gradientLevel; // 0..maxGradientLevel
  String activationFn; // 'linear' | 'relu' | 'sigmoid' | 'tanh'
  bool hasBranched;

  /// Activation functions the player has already paid for on this neuron.
  /// 'linear' is free and always implicitly unlocked. Once an activation is
  /// in this set, switching back to it costs nothing.
  final Set<String> unlockedActivations;

  NeuralNeuron({
    required this.id,
    this.gradientLevel = 0,
    this.activationFn = 'linear',
    this.hasBranched = false,
    Set<String>? unlockedActivations,
  }) : unlockedActivations = unlockedActivations ?? <String>{};

  /// Layer index parsed from the id (`layer_<L>_neuron_<slot>`).
  int get layerIndex {
    final parts = id.split('_');
    return parts.length >= 2 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  /// Price of the next gradient level, ignoring the cap. Deep layers (past
  /// the original pyramid) cost 15x more per layer of depth.
  BigInt get baseGradientCost {
    final depth = layerIndex - (NeuralNetwork.pyramidLayerCount - 1);
    final deepFactor = depth > 0 ? BigInt.from(15).pow(depth) : BigInt.one;
    return BigInt.from(50000) * BigInt.from(12).pow(gradientLevel) * deepFactor;
  }

  BigInt activationChangeCost(String targetFn) {
    if (targetFn == activationFn) return BigInt.zero;
    if (targetFn == 'linear') return BigInt.zero;
    if (unlockedActivations.contains(targetFn)) return BigInt.zero;
    return BigInt.from(5000000);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gradientLevel': gradientLevel,
        'activationFn': activationFn,
        'hasBranched': hasBranched,
        'unlockedActivations': unlockedActivations.toList(),
      };

  factory NeuralNeuron.fromJson(Map<String, dynamic> j) {
    final activationFn = j['activationFn'] as String? ?? 'linear';
    final rawUnlocked = j['unlockedActivations'];
    final unlocked = <String>{};
    if (rawUnlocked is List) {
      for (final v in rawUnlocked) {
        if (v is String) unlocked.add(v);
      }
    } else if (activationFn != 'linear') {
      // Pre-v4 save: grandfather the currently selected non-linear function
      // so the player isn't asked to re-buy what they already configured.
      unlocked.add(activationFn);
    }
    return NeuralNeuron(
      id: j['id'] as String,
      gradientLevel: (j['gradientLevel'] as num?)?.toInt() ?? 0,
      activationFn: activationFn,
      hasBranched: (j['hasBranched'] as bool?) ?? false,
      unlockedActivations: unlocked,
    );
  }
}

class NeuralLayer {
  final int index;
  final List<NeuralNeuron> neurons;

  NeuralLayer({required this.index, required this.neurons});

  Map<String, dynamic> toJson() => {
        'index': index,
        'neurons': neurons.map((n) => n.toJson()).toList(),
      };

  factory NeuralLayer.fromJson(Map<String, dynamic> j) => NeuralLayer(
        index: (j['index'] as num).toInt(),
        neurons: (j['neurons'] as List<dynamic>)
            .map((n) => NeuralNeuron.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
}

/// Preferred activation function per layer index. Tuning a neuron's activation
/// to match its layer's preferred role grants a small strength bonus, giving
/// players an "optimal" build to reach for.
///   0 (input)        → linear (raw passthrough)
///   1–4 (hidden)     → relu
///   5 (deep hidden)  → tanh (squash before output)
///   6 (output)       → linear
///   7–9 (deep)       → sigmoid, relu, tanh
///   10 (deep output) → linear
const Map<int, String> preferredActivationByLayer = {
  0: 'linear',
  1: 'relu',
  2: 'relu',
  3: 'relu',
  4: 'relu',
  5: 'tanh',
  6: 'linear',
  7: 'sigmoid',
  8: 'relu',
  9: 'tanh',
  10: 'linear',
};

class NeuralNetwork {
  // v4: per-neuron unlockedActivations set so paid activation buys persist
  // across switches. Older saves seed the set from the current activationFn.
  // v5: epochs.
  static const int _saveVersion = 5;

  /// Full-expansion neuron count per layer: the original 1-2-4-8-4-2-1
  /// pyramid, then a prestige-gated deep block.
  static const List<int> layerTargets = [1, 2, 4, 8, 4, 2, 1, 2, 4, 2, 1];
  static const int pyramidLayerCount = 7;
  static int get maxLayerCount => layerTargets.length;

  static const int baseGradientCap = 9;
  static const int maxGradientCap = 15;
  static const double basePreferredBonus = 1.10;

  /// Loss at or below which the network can be sent into a new Epoch.
  static const double epochLossThreshold = 0.01;

  List<NeuralLayer> layers;
  bool unlocked;

  /// Current training loss in (0, 1]. Decays over time based on network
  /// strength. Persists across prestige; only resets on hard reset.
  double loss;

  /// Best (lowest) loss this network has ever achieved. Used as the metric
  /// for the neural leaderboard. Persists across prestige.
  double lowestLossEver;

  /// Completed Epochs. Each one resets training and gradients in exchange
  /// for permanent bonuses (see GameState).
  int epochs;

  NeuralNetwork({
    required this.layers,
    this.unlocked = false,
    this.loss = 1.0,
    this.lowestLossEver = 1.0,
    this.epochs = 0,
  });

  /// Highest gradient level reachable right now; each Epoch adds one.
  int get gradientCap => math.min(baseGradientCap + epochs, maxGradientCap);

  bool isGradientMaxed(NeuralNeuron neuron) =>
      neuron.gradientLevel >= gradientCap;

  BigInt gradientUpgradeCost(NeuralNeuron neuron) =>
      isGradientMaxed(neuron) ? BigInt.zero : neuron.baseGradientCost;

  bool get canStartEpoch => unlocked && loss <= epochLossThreshold;

  /// Resets training and every gradient level. Topology, activations and
  /// lowestLossEver are kept.
  void startEpoch() {
    epochs++;
    loss = 1.0;
    for (final layer in layers) {
      for (final neuron in layer.neurons) {
        neuron.gradientLevel = 0;
      }
    }
  }

  /// Existing layers past the original pyramid.
  int get deepLayerCount =>
      layers.where((l) => l.index >= pyramidLayerCount).length;

  /// Strength is computed from the current network state every tick. Higher
  /// strength → faster loss decay. Log-shaped so late-game decay slows down
  /// gracefully instead of falling off a cliff.
  ///
  /// contribution(neuron) = (gradientLevel + 1)
  ///                     × layerDepthBonus(layer.index)
  ///                     × activationBonus(layer.index, fn)
  /// strength = ln(1 + Σ contributions)
  double computeStrength({double preferredBonus = basePreferredBonus}) =>
      math.log(1.0 + contributionSum(preferredBonus: preferredBonus));

  double contributionSum({double preferredBonus = basePreferredBonus}) {
    double sum = 0.0;
    for (final layer in layers) {
      for (final neuron in layer.neurons) {
        sum += neuronContribution(layer.index, neuron,
            preferredBonus: preferredBonus);
      }
    }
    return sum;
  }

  static double neuronContribution(
    int layerIndex,
    NeuralNeuron neuron, {
    double preferredBonus = basePreferredBonus,
  }) {
    final depthBonus = 1.0 + 0.25 * layerIndex;
    final preferred = preferredActivationByLayer[layerIndex];
    final activationBonus =
        (preferred != null && neuron.activationFn == preferred)
            ? preferredBonus
            : 1.0;
    return (neuron.gradientLevel + 1) * depthBonus * activationBonus;
  }

  /// Log-shaped accuracy for display: fast early gains, asymptotes toward 1.0
  /// but can never actually reach it. Uses log(1 + x*9)/log(10) to remap
  /// the raw (1-loss) value so early upgrades feel impactful and the curve
  /// always approaches 100% without ever touching it.
  double get accuracy {
    final x = (1.0 - loss).clamp(0.0, 1.0);
    return math.log(1.0 + x * 9.0) / math.log(10.0);
  }

  // Exponential layer cost: 4M for first branch, ×10 per additional layer.
  // 4M → 40M → 400M → 4B → 40B → 400B
  BigInt addLayerCost(int currentLayerCount) {
    const base = 4000000.0;
    const growth = 10.0;
    final scaled = base * math.pow(growth, currentLayerCount - 1);
    return BigInt.from(scaled.floor());
  }

  /// Maximum number of neurons that should exist in [layerIndex] when fully
  /// expanded.
  static int targetNeuronCountForLayer(int layerIndex) {
    if (layerIndex < 0 || layerIndex >= layerTargets.length) return 0;
    return layerTargets[layerIndex];
  }

  /// True if the neuron at array index [i] in [layerIndex] is eligible to
  /// branch (independent of whether it has already branched), given that
  /// only the first [layerLimit] layers may exist.
  ///
  /// Growing into a bigger layer every neuron branches; shrinking, only the
  /// first ceil(next/2) do. For the original pyramid this is exactly the old
  /// hand-written rule (layer 3: i<=1, layers 4-5: i==0, layer 6 terminal).
  static bool isEligibleParentIndex(
    int layerIndex,
    int i, {
    int layerLimit = pyramidLayerCount,
  }) {
    final limit = math.min(layerLimit, maxLayerCount);
    if (layerIndex < 0 || layerIndex + 1 >= limit || i < 0) return false;
    final current = layerTargets[layerIndex];
    final next = layerTargets[layerIndex + 1];
    if (next >= current) return i < current;
    return i < (next + 1) ~/ 2;
  }

  /// True once every eligible parent in [layerIndex] has branched AND the
  /// layer holds its full target count of neurons.
  bool isLayerComplete(int layerIndex, {int layerLimit = pyramidLayerCount}) {
    final layer = layers.where((l) => l.index == layerIndex).firstOrNull;
    if (layer == null) return false;
    if (layer.neurons.length < targetNeuronCountForLayer(layerIndex)) {
      return false;
    }
    for (int i = 0; i < layer.neurons.length; i++) {
      if (!isEligibleParentIndex(layerIndex, i, layerLimit: layerLimit)) {
        continue;
      }
      if (!layer.neurons[i].hasBranched) return false;
    }
    return true;
  }

  /// The index of the leftmost layer that still has eligible neurons to
  /// branch. Returns -1 once the network is expanded as far as [layerLimit]
  /// allows.
  int activeExpansionLayerIndex({int layerLimit = pyramidLayerCount}) {
    for (final layer in layers) {
      for (int i = 0; i < layer.neurons.length; i++) {
        if (!isEligibleParentIndex(layer.index, i, layerLimit: layerLimit)) {
          continue;
        }
        if (layer.neurons[i].hasBranched) continue;
        return layer.index;
      }
    }
    return -1;
  }

  bool canNeuronBranch(String neuronId, {int layerLimit = pyramidLayerCount}) =>
      branchBlockReason(neuronId, layerLimit: layerLimit) == null;

  /// Reason a neuron cannot branch right now, for UI messaging.
  /// Returns null if the neuron CAN branch.
  NeuronBranchBlock? branchBlockReason(
    String neuronId, {
    int layerLimit = pyramidLayerCount,
  }) {
    final neuron = findNeuron(neuronId);
    final layer = findNeuronLayer(neuronId);
    if (neuron == null || layer == null) return NeuronBranchBlock.unknown;
    if (neuron.hasBranched) return NeuronBranchBlock.alreadyBranched;

    final i = layer.neurons.indexOf(neuron);
    // Structural check against the full design first, then the prestige gate.
    if (!isEligibleParentIndex(layer.index, i, layerLimit: maxLayerCount)) {
      return NeuronBranchBlock.terminal;
    }
    if (!isEligibleParentIndex(layer.index, i, layerLimit: layerLimit)) {
      return NeuronBranchBlock.depthLocked;
    }

    final activeIdx = activeExpansionLayerIndex(layerLimit: layerLimit);
    if (activeIdx < 0) return NeuronBranchBlock.networkComplete;
    if (layer.index != activeIdx) {
      return NeuronBranchBlock.previousLayerIncomplete;
    }
    return null;
  }

  factory NeuralNetwork.initial() {
    return NeuralNetwork(layers: [], unlocked: false);
  }

  NeuralNeuron? findNeuron(String neuronId) {
    for (final layer in layers) {
      for (final neuron in layer.neurons) {
        if (neuron.id == neuronId) return neuron;
      }
    }
    return null;
  }

  NeuralLayer? findNeuronLayer(String neuronId) {
    for (final layer in layers) {
      for (final neuron in layer.neurons) {
        if (neuron.id == neuronId) return layer;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'version': _saveVersion,
        'layers': layers.map((l) => l.toJson()).toList(),
        'unlocked': unlocked,
        'loss': loss,
        'lowestLossEver': lowestLossEver,
        'epochs': epochs,
      };

  factory NeuralNetwork.fromJson(Map<String, dynamic> j) {
    final version = (j['version'] as int?) ?? 0;
    final layers = (j['layers'] as List<dynamic>)
        .map((l) => NeuralLayer.fromJson(l as Map<String, dynamic>))
        .toList();

    // v3+: loss / lowestLossEver are persisted. Older saves default to 1.0.
    final loadedLoss = (j['loss'] as num?)?.toDouble() ?? 1.0;
    final loadedLowest = (j['lowestLossEver'] as num?)?.toDouble() ?? loadedLoss;

    final network = NeuralNetwork(
      layers: layers,
      unlocked: (j['unlocked'] as bool?) ?? false,
      loss: loadedLoss.clamp(0.0, 1.0),
      lowestLossEver: loadedLowest.clamp(0.0, 1.0),
      epochs: ((j['epochs'] as num?)?.toInt() ?? 0).clamp(0, 1000000),
    );

    // Migrate v0 saves: non-last-layer neurons were implicitly fully branched
    if (version == 0 && network.layers.length > 1) {
      for (int i = 0; i < network.layers.length - 1; i++) {
        for (final neuron in network.layers[i].neurons) {
          neuron.hasBranched = true;
        }
      }
    }

    // v1 → v2: the new branching rule only allows a layer to exist at its
    // full target neuron count. Top up any partial layer that was created
    // incrementally under the old rule, and mark the corresponding parents
    // in the previous layer as branched so the rules stay consistent.
    if (version < 2) {
      _normalizePartialLayers(network);
    }

    return network;
  }

  static void _normalizePartialLayers(NeuralNetwork network) {
    network.layers.sort((a, b) => a.index.compareTo(b.index));
    for (int li = 0; li < network.layers.length; li++) {
      final layer = network.layers[li];
      final target = targetNeuronCountForLayer(layer.index);
      if (layer.neurons.length >= target) continue;

      final existingIds = layer.neurons.map((n) => n.id).toSet();
      for (int i = 0; i < target; i++) {
        final id = 'layer_${layer.index}_neuron_$i';
        if (!existingIds.contains(id)) {
          layer.neurons.add(NeuralNeuron(id: id));
        }
      }
      if (li > 0) {
        final prev = network.layers[li - 1];
        for (int i = 0; i < prev.neurons.length; i++) {
          if (isEligibleParentIndex(prev.index, i)) {
            prev.neurons[i].hasBranched = true;
          }
        }
      }
    }
  }

  String toJsonString() => jsonEncode(toJson());

  factory NeuralNetwork.fromJsonString(String s) =>
      NeuralNetwork.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
