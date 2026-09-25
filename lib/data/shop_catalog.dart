import '../models/shop_product.dart';

/// Canonical shop SKUs. Prices are display labels until real IAP product IDs
/// are wired; keep [ShopProduct.id] stable — they are persisted ownership keys.
class ShopCatalog {
  ShopCatalog._();

  static const String sparkSurge = 'spark_surge';
  static const String overclockCharge = 'overclock_charge';
  static const String collapseReady = 'collapse_ready';
  static const String quickResume = 'quick_resume_pack';
  static const String clickPrimer = 'click_primer';
  static const String idlePrimer = 'idle_primer';
  static const String chronoChip = 'chrono_chip';
  static const String sparkMagnet = 'spark_magnet';
  static const String kineticAmplifier = 'kinetic_amplifier';
  static const String idleAmplifier = 'idle_amplifier';
  static const String chronoLensPro = 'chrono_lens_pro';
  static const String collapseEfficiency = 'collapse_efficiency';
  static const String surgeProtocol = 'surge_protocol_shop';
  static const String neuralPatron = 'neural_patron';
  static const String prestigeDividend = 'prestige_dividend';

  static const List<ShopProduct> quickBoosts = [
    ShopProduct(
      id: sparkSurge,
      name: 'Spark Surge',
      description: '×1.5 all production for 5 minutes',
      priceLabel: '€0.29',
      kind: ShopProductKind.consumable,
      effect: ShopEffect.sparkSurge,
    ),
    ShopProduct(
      id: overclockCharge,
      name: 'Overclock Charge',
      description: 'Instant Overclock burst for 60 seconds',
      priceLabel: '€0.39',
      kind: ShopProductKind.consumable,
      effect: ShopEffect.overclockCharge,
    ),
    ShopProduct(
      id: collapseReady,
      name: 'Collapse Ready',
      description: 'Clear Temporal Collapse cooldown once',
      priceLabel: '€0.49',
      kind: ShopProductKind.consumable,
      effect: ShopEffect.collapseReady,
    ),
    ShopProduct(
      id: quickResume,
      name: 'Quick Resume',
      description: 'Claim 1 hour of your current idle instantly',
      priceLabel: '€0.49',
      kind: ShopProductKind.consumable,
      effect: ShopEffect.quickResume,
    ),
  ];

  static const List<ShopProduct> starterPermanents = [
    ShopProduct(
      id: clickPrimer,
      name: 'Click Primer',
      description: '+3% click power permanently',
      priceLabel: '€0.59',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.clickPrimer,
    ),
    ShopProduct(
      id: idlePrimer,
      name: 'Idle Primer',
      description: '+3% idle generation permanently',
      priceLabel: '€0.79',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.idlePrimer,
    ),
    ShopProduct(
      id: chronoChip,
      name: 'Chrono Chip',
      description: '+2 hours offline earnings cap',
      priceLabel: '€0.89',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.chronoChip,
    ),
    ShopProduct(
      id: sparkMagnet,
      name: 'Spark Magnet',
      description: 'Neural Sparks appear 25% more often',
      priceLabel: '€0.99',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.sparkMagnet,
    ),
  ];

  static const List<ShopProduct> corePermanents = [
    ShopProduct(
      id: kineticAmplifier,
      name: 'Kinetic Amplifier',
      description: '+12% click power permanently',
      priceLabel: '€1.99',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.kineticAmplifier,
    ),
    ShopProduct(
      id: idleAmplifier,
      name: 'Idle Amplifier',
      description: '+15% idle generation permanently',
      priceLabel: '€2.49',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.idleAmplifier,
    ),
    ShopProduct(
      id: chronoLensPro,
      name: 'Chrono Lens Pro',
      description: '+6h offline cap and +15% offline gains',
      priceLabel: '€2.99',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.chronoLensPro,
    ),
    ShopProduct(
      id: collapseEfficiency,
      name: 'Collapse Efficiency',
      description: 'Temporal Collapse cooldown −20% forever',
      priceLabel: '€3.49',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.collapseEfficiency,
    ),
    ShopProduct(
      id: surgeProtocol,
      name: 'Surge Protocol',
      description: 'Carry +2% of net worth through each prestige',
      priceLabel: '€3.99',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.surgeProtocol,
    ),
    ShopProduct(
      id: neuralPatron,
      name: 'Neural Patron',
      description: '−10% neural network costs forever',
      priceLabel: '€4.49',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.neuralPatron,
    ),
    ShopProduct(
      id: prestigeDividend,
      name: 'Prestige Dividend',
      description: '+15% prestige points earned forever',
      priceLabel: '€4.99',
      kind: ShopProductKind.permanent,
      effect: ShopEffect.prestigeDividend,
    ),
  ];

  static List<ShopProduct> get all => [
        ...quickBoosts,
        ...starterPermanents,
        ...corePermanents,
      ];

  static final Map<String, ShopProduct> _byId = {
    for (final p in all) p.id: p,
  };

  static ShopProduct? byId(String id) => _byId[id];
}
