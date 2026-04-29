import 'dart:convert';
import 'dart:math' as math;

enum NeuronBranchBlock {
  alreadyBranched,
  terminal,
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
  int gradientLevel; // 0–5
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

  bool get isGradientMaxed => gradientLevel >= 9;

  BigInt get gradientUpgradeCost {
    if (isGradientMaxed) return BigInt.zero;
    // 9 levels: 10K, 100K, 1M, 10M, 100M, 1B, 10B, 100B, 1T
    return BigInt.from(10000) * BigInt.from(10).pow(gradientLevel);
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
const Map<int, String> preferredActivationByLayer = {
  0: 'linear',
  1: 'relu',
  2: 'relu',
  3: 'relu',
  4: 'relu',
  5: 'tanh',
  6: 'linear',
};

class NeuralNetwork {
  // v4: per-neuron unlockedActivations set so paid activation buys persist
  // across switches. Older saves seed the set from the current activationFn.
  static const int _saveVersion = 4;

  List<NeuralLayer> layers;
  bool unlocked;

  /// Current training loss in (0, 1]. Decays over time based on network
  /// strength. Persists across prestige; only resets on hard reset.
  double loss;

  /// Best (lowest) loss this network has ever achieved. Used as the metric
  /// for the neural leaderboard. Persists across prestige.
  double lowestLossEver;

  NeuralNetwork({
    required this.layers,
    this.unlocked = false,
    this.loss = 1.0,
    this.lowestLossEver = 1.0,
  });

  /// Strength is computed from the current network state every tick. Higher
  /// strength → faster loss decay. Log-shaped so late-game decay slows down
  /// gracefully instead of falling off a cliff.
  ///
  /// contribution(neuron) = (gradientLevel + 1)
  ///                     × layerDepthBonus(layer.index)
  ///                     × activationBonus(layer.index, fn)
  /// strength = ln(1 + Σ contributions)
  double computeStrength() {
    double sum = 0.0;
    for (final layer in layers) {
      final depthBonus = 1.0 + 0.25 * layer.index;
      final preferred = preferredActivationByLayer[layer.index];
      for (final neuron in layer.neurons) {
        final activationBonus =
            (preferred != null && neuron.activationFn == preferred) ? 1.10 : 1.0;
        sum += (neuron.gradientLevel + 1) * depthBonus * activationBonus;
      }
    }
    return math.log(1.0 + sum);
  }

  /// Convenience accessor for the UI: 0.0 .. 1.0
  double get accuracy => (1.0 - loss).clamp(0.0, 1.0);

  // Exponential layer cost: 1M for first branch, ×8 per additional layer.
  // 1M → 8M → 64M → 512M → ~4.1B → ~32.8B
  BigInt addLayerCost(int currentLayerCount) {
    const base = 1000000.0;
    const growth = 8.0;
    final scaled = base * math.pow(growth, currentLayerCount - 1);
    return BigInt.from(scaled.floor());
  }

  /// Maximum number of neurons that should exist in [layerIndex] when fully
  /// expanded. Encodes the pyramid: 1 → 2 → 4 → 8 → 4 → 2 → 1.
  static int targetNeuronCountForLayer(int layerIndex) {
    switch (layerIndex) {
      case 0:
        return 1;
      case 1:
        return 2;
      case 2:
        return 4;
      case 3:
        return 8;
      case 4:
        return 4;
      case 5:
        return 2;
      case 6:
        return 1;
      default:
        return 0;
    }
  }

  /// True if the neuron at array index [i] in [layerIndex] is eligible to
  /// branch (independent of whether it has already branched).
  static bool isEligibleParentIndex(int layerIndex, int i) {
    if (layerIndex < 0 || layerIndex >= 6) return false;
    if (layerIndex < 3) return true;
    // Pyramid shrinking: only the leading neurons branch.
    // Layer 3: neurons 0, 1 (creates 4 in layer 4).
    // Layer 4: neuron 0 (creates 2 in layer 5).
    // Layer 5: neuron 0 (creates 1 in layer 6).
    if (layerIndex == 3) return i <= 1;
    if (layerIndex == 4) return i == 0;
    if (layerIndex == 5) return i == 0;
    return false;
  }

  /// True once every eligible parent in [layerIndex] has branched AND the
  /// layer holds its full target count of neurons.
  bool isLayerComplete(int layerIndex) {
    final layer = layers.where((l) => l.index == layerIndex).firstOrNull;
    if (layer == null) return false;
    if (layer.neurons.length < targetNeuronCountForLayer(layerIndex)) {
      return false;
    }
    for (int i = 0; i < layer.neurons.length; i++) {
      if (!isEligibleParentIndex(layerIndex, i)) continue;
      if (!layer.neurons[i].hasBranched) return false;
    }
    return true;
  }

  /// The index of the leftmost layer that still has eligible neurons to branch.
  /// Returns -1 once the network is fully expanded.
  int get activeExpansionLayerIndex {
    for (final layer in layers) {
      if (layer.index >= 6) continue;
      for (int i = 0; i < layer.neurons.length; i++) {
        if (!isEligibleParentIndex(layer.index, i)) continue;
        if (layer.neurons[i].hasBranched) continue;
        return layer.index;
      }
    }
    return -1;
  }

  bool canNeuronBranch(String neuronId) {
    final activeIdx = activeExpansionLayerIndex;
    if (activeIdx < 0) return false;
    if (activeIdx >= 6) return false;

    for (final layer in layers) {
      if (layer.index != activeIdx) continue;
      for (int i = 0; i < layer.neurons.length; i++) {
        final neuron = layer.neurons[i];
        if (neuron.id != neuronId) continue;
        if (neuron.hasBranched) return false;
        return isEligibleParentIndex(activeIdx, i);
      }
    }
    return false;
  }

  /// Reason a neuron cannot branch right now, for UI messaging.
  /// Returns null if the neuron CAN branch.
  NeuronBranchBlock? branchBlockReason(String neuronId) {
    final neuron = findNeuron(neuronId);
    final layer = findNeuronLayer(neuronId);
    if (neuron == null || layer == null) return NeuronBranchBlock.unknown;
    if (neuron.hasBranched) return NeuronBranchBlock.alreadyBranched;
    if (layer.index >= 6) return NeuronBranchBlock.terminal;

    final i = layer.neurons.indexOf(neuron);
    if (!isEligibleParentIndex(layer.index, i)) {
      return NeuronBranchBlock.terminal;
    }

    final activeIdx = activeExpansionLayerIndex;
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
