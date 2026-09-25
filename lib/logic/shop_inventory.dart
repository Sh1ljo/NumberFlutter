import '../data/shop_catalog.dart';

/// Owned permanents + expiry timestamps for timed shop boosts.
///
/// Temporary boosts are rehydrated on load so a mid-boost kill still honors
/// the remaining duration. Consumable purchases themselves are not stacked
/// in inventory — they apply immediately.
class ShopInventory {
  final Set<String> ownedPermanents;

  /// Wall-clock expiry for Spark Surge (×1.5 production). Null when inactive.
  DateTime? sparkSurgeExpiresAt;

  ShopInventory({
    Set<String>? ownedPermanents,
    this.sparkSurgeExpiresAt,
  }) : ownedPermanents = ownedPermanents ?? <String>{};

  bool owns(String productId) => ownedPermanents.contains(productId);

  bool get hasClickPrimer => owns(ShopCatalog.clickPrimer);
  bool get hasIdlePrimer => owns(ShopCatalog.idlePrimer);
  bool get hasChronoChip => owns(ShopCatalog.chronoChip);
  bool get hasSparkMagnet => owns(ShopCatalog.sparkMagnet);
  bool get hasKineticAmplifier => owns(ShopCatalog.kineticAmplifier);
  bool get hasIdleAmplifier => owns(ShopCatalog.idleAmplifier);
  bool get hasChronoLensPro => owns(ShopCatalog.chronoLensPro);
  bool get hasCollapseEfficiency => owns(ShopCatalog.collapseEfficiency);
  bool get hasSurgeProtocol => owns(ShopCatalog.surgeProtocol);
  bool get hasNeuralPatron => owns(ShopCatalog.neuralPatron);
  bool get hasPrestigeDividend => owns(ShopCatalog.prestigeDividend);

  /// Additive click bonus from owned primers/amplifiers (0.03 + 0.12 max).
  double get clickBonus {
    var bonus = 0.0;
    if (hasClickPrimer) bonus += 0.03;
    if (hasKineticAmplifier) bonus += 0.12;
    return bonus;
  }

  /// Additive idle bonus from owned primers/amplifiers (0.03 + 0.15 max).
  double get idleBonus {
    var bonus = 0.0;
    if (hasIdlePrimer) bonus += 0.03;
    if (hasIdleAmplifier) bonus += 0.15;
    return bonus;
  }

  double get clickMultiplier => 1.0 + clickBonus;
  double get idleMultiplier => 1.0 + idleBonus;

  double get offlineCapBonusHours {
    var hours = 0.0;
    if (hasChronoChip) hours += 2.0;
    if (hasChronoLensPro) hours += 6.0;
    return hours;
  }

  double get offlineGainMultiplier {
    if (!hasChronoLensPro) return 1.0;
    return 1.15;
  }

  /// Delay scale for Neural Spark spawns. 0.75 ⇒ 25% more often.
  double get neuralSparkSpawnDelayFactor => hasSparkMagnet ? 0.75 : 1.0;

  double get collapseCooldownFactor => hasCollapseEfficiency ? 0.80 : 1.0;

  /// Extra net-worth carry in basis points (2% = 200).
  int get surgeCarryBps => hasSurgeProtocol ? 200 : 0;

  double get neuralCostFactor => hasNeuralPatron ? 0.90 : 1.0;

  double get prestigePointsMultiplier => hasPrestigeDividend ? 1.15 : 1.0;

  void grantPermanent(String productId) {
    ownedPermanents.add(productId);
  }

  void clear() {
    ownedPermanents.clear();
    sparkSurgeExpiresAt = null;
  }

  Map<String, dynamic> toJson() => {
        'owned': ownedPermanents.toList()..sort(),
        if (sparkSurgeExpiresAt != null)
          'sparkSurgeExpiresAt': sparkSurgeExpiresAt!.toUtc().toIso8601String(),
      };

  factory ShopInventory.fromJson(Map<String, dynamic> json) {
    final ownedRaw = json['owned'];
    final owned = <String>{};
    if (ownedRaw is List) {
      for (final id in ownedRaw) {
        if (id is String && ShopCatalog.byId(id) != null) {
          owned.add(id);
        }
      }
    }
    DateTime? surgeExpiry;
    final surgeRaw = json['sparkSurgeExpiresAt'];
    if (surgeRaw is String) {
      surgeExpiry = DateTime.tryParse(surgeRaw)?.toUtc();
    }
    return ShopInventory(
      ownedPermanents: owned,
      sparkSurgeExpiresAt: surgeExpiry,
    );
  }
}

/// Why a mock/IAP grant was refused. Used by the shop UI for feedback.
enum ShopPurchaseResult {
  success,
  unknownProduct,
  alreadyOwned,
  notAvailable,
  noIdleToClaim,
}
