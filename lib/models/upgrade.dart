class Upgrade {
  final String id;
  final String name;
  final String description;
  final BigInt baseCost;
  final double costMultiplier;
  final String effectType; // 'click' or 'idle'
  final dynamic effectValue; // BigInt for click, double for idle
  final int maxLevel;
  int level;

  Upgrade({
    required this.id,
    required this.name,
    required this.description,
    required this.baseCost,
    required this.costMultiplier,
    required this.effectType,
    required this.effectValue,
    this.maxLevel = -1,
    this.level = 0,
  });

  bool get isMaxed => maxLevel != -1 && level >= maxLevel;

  BigInt get currentCost {
    // Basic cost formula: baseCost * (costMultiplier ^ level)
    // Since we use BigInt, we approximate exponentiation
    double multiplier = 1.0;
    for (int i = 0; i < level; i++) {
      multiplier *= costMultiplier;
    }
    return BigInt.from(baseCost.toDouble() * multiplier);
  }

  Map<String, dynamic> toJson() => {
        'level': level,
      };
}
