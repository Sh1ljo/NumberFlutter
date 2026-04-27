import 'dart:convert';

const List<String> activationFunctions = [
  'linear',
  'relu',
  'sigmoid',
  'tanh',
];

class NeuralNeuron {
  final String id;
  int gradientLevel; // 0–5
  String activationFn; // 'linear' | 'relu' | 'sigmoid' | 'tanh'

  NeuralNeuron({
    required this.id,
    this.gradientLevel = 0,
    this.activationFn = 'linear',
  });

  bool get isGradientMaxed => gradientLevel >= 5;

  BigInt get gradientUpgradeCost {
    if (isGradientMaxed) return BigInt.zero;
    return BigInt.from(1000) *
        BigInt.from(10).pow(gradientLevel); // 1k, 10k, 100k, 1M, 10M
  }

  BigInt activationChangeCost(String targetFn) {
    if (targetFn == activationFn) return BigInt.zero;
    if (targetFn == 'linear') return BigInt.zero; // switching to linear is free
    return BigInt.from(5000); // switching to non-linear costs 5k
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gradientLevel': gradientLevel,
        'activationFn': activationFn,
      };

  factory NeuralNeuron.fromJson(Map<String, dynamic> j) => NeuralNeuron(
        id: j['id'] as String,
        gradientLevel: (j['gradientLevel'] as num?)?.toInt() ?? 0,
        activationFn: j['activationFn'] as String? ?? 'linear',
      );
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

class NeuralNetwork {
  List<NeuralLayer> layers;
  bool unlocked;

  NeuralNetwork({required this.layers, this.unlocked = false});

  BigInt addLayerCost(int currentLayerCount) =>
      BigInt.from(5000) * BigInt.from(currentLayerCount);

  factory NeuralNetwork.initial() {
    return NeuralNetwork(
      layers: [],
      unlocked: false,
    );
  }

  NeuralNeuron? findNeuron(String neuronId) {
    for (final layer in layers) {
      for (final neuron in layer.neurons) {
        if (neuron.id == neuronId) return neuron;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'layers': layers.map((l) => l.toJson()).toList(),
        'unlocked': unlocked,
      };

  factory NeuralNetwork.fromJson(Map<String, dynamic> j) => NeuralNetwork(
        layers: (j['layers'] as List<dynamic>)
            .map((l) => NeuralLayer.fromJson(l as Map<String, dynamic>))
            .toList(),
        unlocked: (j['unlocked'] as bool?) ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory NeuralNetwork.fromJsonString(String s) =>
      NeuralNetwork.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
