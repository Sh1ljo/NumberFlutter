import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'neural_network.dart';

/// A job the network can be taught once the pyramid is complete.
///
/// Each Skill is, in real machine-learning terms, a dataset: the network
/// studies it, its Mastery rises, and the Skill's helper does that job for
/// the player — better the higher Mastery climbs.
enum SkillId { tapping, shopping, sparkHunting, prestigePlanning }

/// What gates a Skill beyond Skills themselves being unlocked.
enum SkillGate { none, firstDeepLayer, firstEpoch }

class SkillDef {
  final SkillId id;
  final String name;

  /// Name of the helper this Skill powers.
  final String helperName;
  final IconData icon;

  /// One line: what the helper does for the player.
  final String promise;

  /// Activation this Skill learns best with, and why in plain words.
  final String preferredActivation;
  final String fitReason;
  final SkillGate gate;

  const SkillDef({
    required this.id,
    required this.name,
    required this.helperName,
    required this.icon,
    required this.promise,
    required this.preferredActivation,
    required this.fitReason,
    required this.gate,
  });

  String get gateHint {
    switch (gate) {
      case SkillGate.none:
        return '';
      case SkillGate.firstDeepLayer:
        return 'Grow your first deep layer';
      case SkillGate.firstEpoch:
        return 'Complete your first Epoch';
    }
  }
}

abstract class NeuralSkills {
  static const List<SkillDef> all = [
    SkillDef(
      id: SkillId.tapping,
      name: 'TAPPING',
      helperName: 'Auto-Tap',
      icon: Icons.touch_app_outlined,
      promise: 'Taps for you, up to 10 times a second.',
      preferredActivation: 'relu',
      fitReason: 'Tapping is about fast reflexes — quick ReLU neurons.',
      gate: SkillGate.none,
    ),
    SkillDef(
      id: SkillId.shopping,
      name: 'SHOPPING',
      helperName: 'Auto-Buy',
      icon: Icons.shopping_cart_outlined,
      promise: "Buys the advisor's recommended upgrade for you.",
      preferredActivation: 'tanh',
      fitReason: 'Shopping weighs good against bad — Tanh neurons, which '
          'swing both ways.',
      gate: SkillGate.none,
    ),
    SkillDef(
      id: SkillId.sparkHunting,
      name: 'SPARK HUNTING',
      helperName: 'Auto-Catch',
      icon: Icons.bolt_outlined,
      promise: 'Catches Neural Sparks and makes them appear more often.',
      preferredActivation: 'sigmoid',
      fitReason: 'Catch or ignore is a yes/no decision — Sigmoid neurons.',
      gate: SkillGate.firstDeepLayer,
    ),
    SkillDef(
      id: SkillId.prestigePlanning,
      name: 'PRESTIGE PLANNING',
      helperName: 'Auto-Prestige',
      icon: Icons.auto_awesome_outlined,
      promise: 'Tells you when your next prestige is due — and can do it '
          'for you.',
      preferredActivation: 'linear',
      fitReason: 'Planning keeps numbers exactly as they are — Linear '
          'neurons.',
      gate: SkillGate.firstEpoch,
    ),
  ];

  static SkillDef def(SkillId id) => all.firstWhere((d) => d.id == id);

  // ── Training ───────────────────────────────────────────────────────────
  //
  // Mastery follows m = c·t / (1 + c·t): quick at first, then a long tail.
  // With a freshly finished pyramid (strength ≈ 4.5) at 50% fit that is
  // about 40 minutes to 50%, 6 hours to 90% and ~3 days to 99%.

  /// Base training speed per second per unit of network strength.
  static const double trainingK = 7.5e-5;
  static const double maxMastery = 0.999;

  /// Training speed multiplier from fit: 0.5× with no matching neurons,
  /// 2× when every neuron matches.
  static double fitMultiplier(double fit) => 0.5 + 1.5 * fit.clamp(0.0, 1.0);

  /// Mastery after [seconds] of training from [mastery] at [rate] (= c).
  static double train(double mastery, double rate, double seconds) {
    if (!(rate > 0) || !(seconds > 0)) return mastery;
    final m = mastery.clamp(0.0, maxMastery);
    final next = 1.0 - 1.0 / (1.0 / (1.0 - m) + rate * seconds);
    return math.min(next, maxMastery);
  }

  // ── Helper strength ────────────────────────────────────────────────────

  /// Auto-Tap: 1 tap/s untrained, 10 taps/s at full Mastery.
  static double tapsPerSecond(double mastery) =>
      1.0 + 9.0 * mastery.clamp(0.0, 1.0);

  /// From this Mastery on, Auto-Tap keeps a rhythm steady enough to build
  /// Momentum and Overclock streaks.
  static const double rhythmMastery = 0.75;

  /// Auto-Buy: seconds between purchases, 30s untrained → 1s at full.
  static double shoppingIntervalSeconds(double mastery) =>
      30.0 - 29.0 * mastery.clamp(0.0, 1.0);

  /// Share of the balance Auto-Buy may spend, chosen by the player.
  static const List<double> spendLimits = [0.25, 0.5, 1.0];
  static const double defaultSpendLimit = 0.5;

  /// Auto-Catch: chance to catch each spark.
  static double sparkCatchChance(double mastery) => mastery.clamp(0.0, 1.0);

  /// Auto-Catch: spark spawn delays are divided by this (up to +30% sparks).
  static double sparkSpawnRateBonus(double mastery) =>
      1.0 + 0.3 * mastery.clamp(0.0, 1.0);

  /// Auto-Prestige becomes available at this Mastery.
  static const double autoPrestigeMastery = 0.5;

  /// Auto-Prestige: how long it waits once a prestige is ready, 60s at 0%
  /// down to under a second near 100%.
  static double prestigeReactionSeconds(double mastery) =>
      60.0 * (1.0 - mastery.clamp(0.0, 1.0));
}

/// Everything the player has done with Skills. Saved inside the neural
/// network's save data, so it syncs to the cloud with it.
class SkillsState {
  final Map<SkillId, double> mastery;
  final Set<SkillId> helpersOn;

  /// The one Skill currently training, if any.
  SkillId? training;

  /// Auto-Buy's spending limit, a share of the balance.
  double spendLimit;

  /// The player has confirmed the one-time Auto-Prestige warning.
  bool autoPrestigeConfirmed;

  /// Unlocked Skills the player has already seen on the SKILLS tab. Drives
  /// the "something new" badge.
  int seenUnlockCount;

  SkillsState({
    Map<SkillId, double>? mastery,
    Set<SkillId>? helpersOn,
    this.training,
    this.spendLimit = NeuralSkills.defaultSpendLimit,
    this.autoPrestigeConfirmed = false,
    this.seenUnlockCount = 0,
  })  : mastery = mastery ?? <SkillId, double>{},
        helpersOn = helpersOn ?? <SkillId>{};

  double masteryOf(SkillId id) => mastery[id] ?? 0.0;
  bool isHelperOn(SkillId id) => helpersOn.contains(id);

  Map<String, dynamic> toJson() => {
        'mastery': {
          for (final e in mastery.entries) e.key.name: e.value,
        },
        'helpersOn': helpersOn.map((s) => s.name).toList(),
        'training': training?.name,
        'spendLimit': spendLimit,
        'autoPrestigeConfirmed': autoPrestigeConfirmed,
        'seenUnlockCount': seenUnlockCount,
      };

  static SkillId? _idFromName(Object? name) {
    if (name is! String) return null;
    for (final id in SkillId.values) {
      if (id.name == name) return id;
    }
    return null;
  }

  factory SkillsState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return SkillsState();
    final mastery = <SkillId, double>{};
    final rawMastery = j['mastery'];
    if (rawMastery is Map) {
      for (final e in rawMastery.entries) {
        final id = _idFromName(e.key);
        final v = e.value;
        if (id != null && v is num && v.isFinite) {
          mastery[id] = v.toDouble().clamp(0.0, NeuralSkills.maxMastery);
        }
      }
    }
    final helpers = <SkillId>{};
    final rawHelpers = j['helpersOn'];
    if (rawHelpers is List) {
      for (final v in rawHelpers) {
        final id = _idFromName(v);
        if (id != null) helpers.add(id);
      }
    }
    final rawLimit = (j['spendLimit'] as num?)?.toDouble();
    return SkillsState(
      mastery: mastery,
      helpersOn: helpers,
      training: _idFromName(j['training']),
      spendLimit: NeuralSkills.spendLimits.contains(rawLimit)
          ? rawLimit!
          : NeuralSkills.defaultSpendLimit,
      autoPrestigeConfirmed: (j['autoPrestigeConfirmed'] as bool?) ?? false,
      seenUnlockCount:
          ((j['seenUnlockCount'] as num?)?.toInt() ?? 0).clamp(0, 99),
    );
  }
}

/// Fit: the share of the network's neurons using a Skill's preferred
/// activation. Returns 0 for an empty network.
double skillFit(NeuralNetwork network, SkillId id) {
  final (matching, total) = skillFitCounts(network, id);
  return total == 0 ? 0.0 : matching / total;
}

/// Matching and total neuron counts, for "8 of 22 neurons" copy.
(int, int) skillFitCounts(NeuralNetwork network, SkillId id) {
  final preferred = NeuralSkills.def(id).preferredActivation;
  var total = 0;
  var matching = 0;
  for (final layer in network.layers) {
    for (final neuron in layer.neurons) {
      total++;
      if (neuron.activationFn == preferred) matching++;
    }
  }
  return (matching, total);
}
