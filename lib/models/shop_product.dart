/// One SKU in the real-money shop. Effects are applied by [GameState]; this
/// type is the catalog entry only (id, copy, price label, kind).
enum ShopProductKind { consumable, permanent }

enum ShopEffect {
  /// ×1.5 all production for 5 minutes.
  sparkSurge,

  /// Instant Overclock burst (uses current overclock stats).
  overclockCharge,

  /// Clear Temporal Collapse cooldown once.
  collapseReady,

  /// Claim 1 hour of current idle as Number instantly.
  quickResume,

  /// +3% click power permanently.
  clickPrimer,

  /// +3% idle generation permanently.
  idlePrimer,

  /// +2h offline earnings cap permanently.
  chronoChip,

  /// Neural Sparks spawn 25% more often permanently.
  sparkMagnet,

  /// +12% click power permanently.
  kineticAmplifier,

  /// +15% idle generation permanently.
  idleAmplifier,

  /// +6h offline cap and +15% offline gains permanently.
  chronoLensPro,

  /// Temporal Collapse cooldown −20% permanently.
  collapseEfficiency,

  /// Carry +2% of net worth through each prestige permanently.
  surgeProtocol,

  /// −10% neural network costs permanently.
  neuralPatron,

  /// +15% prestige points earned permanently.
  prestigeDividend,
}

class ShopProduct {
  final String id;
  final String name;
  final String description;
  final String priceLabel;
  final ShopProductKind kind;
  final ShopEffect effect;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.priceLabel,
    required this.kind,
    required this.effect,
  });

  bool get isPermanent => kind == ShopProductKind.permanent;
  bool get isConsumable => kind == ShopProductKind.consumable;
}
