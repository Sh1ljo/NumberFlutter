/// What buying some levels of an upgrade actually changes, after every
/// permanent multiplier. Transient boosts (Overclock surge, Temporal
/// Collapse, Neural Spark, momentum combo) are left out so the figure is the
/// one the player keeps.
class UpgradeGainPreview {
  /// Extra numbers per manual tap.
  final double perClick;

  /// Extra numbers per second of idle income.
  final double perSecond;

  /// When the gain only applies some of the time: "avg" (Probability
  /// Strike), "at max combo" (Momentum), "while surging" (Overclock).
  final String? qualifier;

  /// Stat change for upgrades whose effect isn't a flat amount, e.g.
  /// "Strikes ×10 → ×12". Null for plain click / idle upgrades.
  final String? detail;

  const UpgradeGainPreview({
    this.perClick = 0,
    this.perSecond = 0,
    this.qualifier,
    this.detail,
  });

  @override
  bool operator ==(Object other) =>
      other is UpgradeGainPreview &&
      other.perClick == perClick &&
      other.perSecond == perSecond &&
      other.qualifier == qualifier &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(perClick, perSecond, qualifier, detail);
}

/// The advisor's pick: which upgrade to buy next, and how many levels.
class UpgradeRecommendation {
  final String upgradeId;
  final String category;

  /// Levels to buy in one go. More than one when the same upgrade keeps
  /// winning after each simulated purchase, or when a level milestone
  /// (×2 at 25, 50, 100, …) is within reach.
  final int amount;
  final BigInt cost;

  /// Estimated total production gain (numbers per second, clicking at the
  /// player's measured pace) once all [amount] levels are bought.
  final double gainPerSecond;

  /// Seconds for the purchase to earn back its own cost.
  final double paybackSeconds;

  /// Seconds until the player can afford it at their current pace; 0 when
  /// affordable now.
  final double secondsToAfford;

  /// Taps per second the estimate assumed.
  final double assumedClickRate;

  const UpgradeRecommendation({
    required this.upgradeId,
    required this.category,
    required this.amount,
    required this.cost,
    required this.gainPerSecond,
    required this.paybackSeconds,
    required this.secondsToAfford,
    required this.assumedClickRate,
  });

  bool get affordableNow => secondsToAfford <= 0;

  @override
  bool operator ==(Object other) =>
      other is UpgradeRecommendation &&
      other.upgradeId == upgradeId &&
      other.amount == amount &&
      other.cost == cost &&
      other.gainPerSecond == gainPerSecond &&
      other.paybackSeconds == paybackSeconds &&
      other.secondsToAfford == secondsToAfford;

  @override
  int get hashCode => Object.hash(upgradeId, amount, cost, gainPerSecond,
      paybackSeconds, secondsToAfford);
}
