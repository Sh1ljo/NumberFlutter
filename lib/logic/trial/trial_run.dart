import 'dart:math' as math;

import 'package:flutter/material.dart' show Color, IconData, Icons;

import 'trial_calendar.dart';
import 'trial_rules.dart';

/// One generator tier in the Trial. Deliberately a different lineup from the
/// main game so the Trial reads as its own mode.
class TrialGenerator {
  final String name;
  final String blurb;
  final IconData icon;
  final double baseCost;
  final double baseRate;

  const TrialGenerator({
    required this.name,
    required this.blurb,
    required this.icon,
    required this.baseCost,
    required this.baseRate,
  });
}

const List<TrialGenerator> trialGenerators = [
  TrialGenerator(
    name: 'Tally',
    blurb: 'Scratches marks, one by one',
    icon: Icons.format_list_numbered,
    baseCost: 10,
    baseRate: 0.5,
  ),
  TrialGenerator(
    name: 'Abacus',
    blurb: 'Beads that never tire',
    icon: Icons.grid_on,
    baseCost: 120,
    baseRate: 4,
  ),
  TrialGenerator(
    name: 'Ledger',
    blurb: 'Double-entry, double speed',
    icon: Icons.menu_book_outlined,
    baseCost: 2e3,
    baseRate: 35,
  ),
  TrialGenerator(
    name: 'Engine',
    blurb: 'Brass gears, endless sums',
    icon: Icons.settings_outlined,
    baseCost: 4e4,
    baseRate: 320,
  ),
  TrialGenerator(
    name: 'Reactor',
    blurb: 'Splits numbers into more numbers',
    icon: Icons.blur_circular,
    baseCost: 1e6,
    baseRate: 3.2e3,
  ),
  TrialGenerator(
    name: 'Singularity',
    blurb: 'Where counting folds in on itself',
    icon: Icons.all_inclusive,
    baseCost: 3e7,
    baseRate: 4e4,
  ),
];

/// Score tiers, each ×1000 above the last. They are the badge shown next to
/// a player's name on the Trial boards.
class TrialTier {
  final int index;
  final String name;
  final Color color;

  const TrialTier(this.index, this.name, this.color);

  static const List<TrialTier> all = [
    TrialTier(0, 'Unranked', Color(0xFF6E6E6E)),
    TrialTier(1, 'Bronze', Color(0xFFC08457)),
    TrialTier(2, 'Silver', Color(0xFFC9D1D9)),
    TrialTier(3, 'Gold', Color(0xFFFFC94D)),
    TrialTier(4, 'Platinum', Color(0xFF7FE0D4)),
    TrialTier(5, 'Diamond', Color(0xFF7DB7FF)),
    TrialTier(6, 'Master', Color(0xFFC792FF)),
    TrialTier(7, 'Grandmaster', Color(0xFFFF7A9C)),
    TrialTier(8, 'Legend', Color(0xFFFF9F43)),
  ];

  /// Tier for a Trial score (total earned).
  static TrialTier forScore(double totalEarned) {
    final reached = trialThresholdsReached(totalEarned);
    return all[math.min(reached, all.length - 1)];
  }
}

/// Total earned needed for the [n]th tier: 1K, 1M, 1B, ...
double trialThreshold(int n) => math.pow(10.0, 3 * n).toDouble();

int trialThresholdsReached(double totalEarned) {
  var n = 0;
  while (totalEarned >= trialThreshold(n + 1)) {
    n++;
  }
  return n;
}

/// Total earned needed for the [n]th Draft: 1K, 100K, 10M, ... — every ×100,
/// twice as often as tiers, so there is always a Draft coming up.
double trialDraftThreshold(int n) => math.pow(10.0, 1 + 2 * n).toDouble();

int trialDraftsReached(double totalEarned) {
  var n = 0;
  while (totalEarned >= trialDraftThreshold(n + 1)) {
    n++;
  }
  return n;
}

/// Monthly points for one week's Trial: 100 per order of magnitude earned,
/// so 1e15 scores 1500. Log-based on purpose: a great week beats a good one,
/// but showing up every week beats one monster week.
int trialPointsFor(double totalEarned) {
  if (totalEarned < 10) return 0;
  // The epsilon stops float error turning exactly 1e15 into 1499.
  return (math.log(totalEarned) / math.ln10 * 100 + 1e-7).floor();
}

class TrialTapResult {
  final double gain;
  final bool critical;
  final bool jackpot;

  const TrialTapResult(this.gain,
      {this.critical = false, this.jackpot = false});

  static const TrialTapResult none = TrialTapResult(0);
}

/// The whole state of one player's Trial for one week, plus its economy.
///
/// Pure logic: no timers, storage or widgets, so it can be tested and
/// simulated directly. [TrialController] drives it.
class TrialRun {
  TrialRun({
    required this.week,
    required this.startedAt,
    DateTime? lastUpdate,
    this.balance = 0,
    this.totalEarned = 0,
    this.tapLevel = 0,
    List<int>? owned,
    Map<TrialPerk, int>? perks,
    this.draftsTaken = 0,
    this.taps = 0,
  })  : modifiers = modifiersForWeek(week),
        lastUpdate = lastUpdate ?? startedAt,
        owned = owned ?? List<int>.filled(trialGenerators.length, 0),
        perks = perks ?? <TrialPerk, int>{};

  /// Every run starts with one free Tally, so a player who never taps (or a
  /// Hands Off week) still has something producing from the first second.
  factory TrialRun.fresh(TrialWeek week, DateTime now) => TrialRun(
        week: week,
        startedAt: now,
        owned:
            List<int>.generate(trialGenerators.length, (i) => i == 0 ? 1 : 0),
      );

  final TrialWeek week;
  final List<TrialModifier> modifiers;
  final DateTime startedAt;
  DateTime lastUpdate;

  double balance;

  /// The score: everything earned this week, spent or not. Scoring the
  /// balance instead would punish buying things.
  double totalEarned;
  int tapLevel;
  final List<int> owned;
  final Map<TrialPerk, int> perks;
  int draftsTaken;
  int taps;

  // Momentum combo. Not saved: it drains in seconds anyway.
  double combo = 0;
  DateTime? _lastTapAt;

  static const double _maxCombo = 30;
  static const double _comboStep = 0.1;
  static const Duration _comboGrace = Duration(milliseconds: 800);
  static const double _comboDrainPerSecond = 8;

  bool has(TrialModifier m) => modifiers.contains(m);
  int perk(TrialPerk p) => perks[p] ?? 0;

  bool get tappingEnabled => !has(TrialModifier.handsOff);

  int get generatorCount =>
      has(TrialModifier.minimalist) ? 4 : trialGenerators.length;

  // ── Production ──────────────────────────────────────────────────────────

  double _milestoneMultiplier(int count) {
    if (has(TrialModifier.milestoneMadness)) {
      return math.pow(1.5, count ~/ 10).toDouble();
    }
    return math.pow(2.0, count ~/ 25).toDouble();
  }

  /// Next milestone for a generator at [count] units.
  int nextMilestone(int count) {
    final step = has(TrialModifier.milestoneMadness) ? 10 : 25;
    return (count ~/ step + 1) * step;
  }

  int get _highestOwnedTier {
    for (var i = generatorCount - 1; i >= 0; i--) {
      if (owned[i] > 0) return i;
    }
    return -1;
  }

  int get generatorTypesOwned =>
      owned.take(generatorCount).where((c) => c > 0).length;

  /// Output of one generator tier before live/away effects.
  double generatorOutput(int i) {
    final count = owned[i];
    if (count == 0 || i >= generatorCount) return 0;
    var rate =
        trialGenerators[i].baseRate * count * _milestoneMultiplier(count);
    if (has(TrialModifier.minimalist)) rate *= 4;
    if (has(TrialModifier.chainReaction) && i > 0) {
      rate *= 1 + 0.03 * owned[i - 1];
    }
    final bootstrap = perk(TrialPerk.bootstrap);
    if (bootstrap > 0 && i < 2) rate *= math.pow(6, bootstrap);
    final specialist = perk(TrialPerk.specialist);
    if (specialist > 0 && i == _highestOwnedTier) {
      rate *= math.pow(3, specialist);
    }
    return rate;
  }

  /// Multipliers that apply both live and while away.
  double get globalMultiplier {
    var m = 1.0;
    if (has(TrialModifier.handsOff)) m *= 3;
    if (has(TrialModifier.glassCannon)) m *= 0.5;
    if (has(TrialModifier.inflation)) m *= 2;
    m *= math.pow(1.5, perk(TrialPerk.overtime));
    final synergy = perk(TrialPerk.synergy);
    if (synergy > 0) {
      m *= math.pow(1 + 0.15 * generatorTypesOwned, synergy);
    }
    return m;
  }

  /// Production with no live or away effects: the base for Windfall and
  /// Jackpot payouts.
  double get baseProduction {
    var sum = 0.0;
    for (var i = 0; i < generatorCount; i++) {
      sum += generatorOutput(i);
    }
    return sum * globalMultiplier;
  }

  double get comboMultiplier =>
      has(TrialModifier.momentum) ? 1 + combo * _comboStep : 1;

  double get liveMultiplier {
    var m = comboMultiplier;
    if (has(TrialModifier.blackout)) m *= 2;
    if (has(TrialModifier.nightShift)) m *= 0.5;
    return m;
  }

  /// Away time earns at half rate: the Trial should reward showing up, and
  /// at full rate a player checking in twice a day kept pace with one who
  /// actually played.
  static const double baseAwayRate = 0.5;

  double get awayMultiplier {
    var m = baseAwayRate * math.pow(2, perk(TrialPerk.nightOwl)).toDouble();
    if (has(TrialModifier.blackout)) m *= 0.1;
    if (has(TrialModifier.nightShift)) m *= 4;
    return m;
  }

  /// Short enough that checking in three times a day beats twice.
  Duration get awayCap => Duration(hours: 8 + 4 * perk(TrialPerk.nightOwl));

  /// Per second while the Trial is open.
  double get liveProduction => baseProduction * liveMultiplier;

  /// Per second while away.
  double get awayProduction => baseProduction * awayMultiplier;

  void _earn(double amount) {
    if (!amount.isFinite || amount <= 0) return;
    balance += amount;
    totalEarned += amount;
  }

  /// Advances the run by [seconds] of live play.
  void tick(double seconds, DateTime now) {
    if (seconds <= 0) return;
    _earn(liveProduction * seconds);
    if (has(TrialModifier.momentum) && combo > 0) {
      final last = _lastTapAt;
      if (last == null || now.difference(last) > _comboGrace) {
        combo = math.max(0, combo - _comboDrainPerSecond * seconds);
      }
    }
    lastUpdate = now;
  }

  /// Credits time spent away from the Trial, capped at [awayCap] and never
  /// past the end of the week. Returns what was earned.
  double applyAway(DateTime now) {
    final until = now.isAfter(week.end) ? week.end : now;
    var away = until.difference(lastUpdate);
    if (away > awayCap) away = awayCap;
    lastUpdate = now;
    combo = 0;
    if (away <= Duration.zero) return 0;
    final gained = awayProduction * away.inMilliseconds / 1000;
    _earn(gained);
    return gained.isFinite ? gained : 0;
  }

  // ── Tapping ─────────────────────────────────────────────────────────────

  double get tapShareOfProduction => 0.08 + 0.015 * tapLevel;

  double get tapGain {
    var gain = (1 + 2 * tapLevel) + liveProduction * tapShareOfProduction;
    gain *= math.pow(3, perk(TrialPerk.sharpTaps));
    if (has(TrialModifier.glassCannon)) gain *= 10;
    return gain;
  }

  double get criticalChance => math.min(0.6, 0.15 * perk(TrialPerk.critical));
  static const double jackpotChance = 1 / 150;

  TrialTapResult tap(DateTime now, math.Random rng) {
    if (!tappingEnabled) return TrialTapResult.none;
    taps++;
    if (has(TrialModifier.momentum)) {
      combo = math.min(_maxCombo, combo + 1);
      _lastTapAt = now;
    }
    var gain = tapGain;
    final critical = criticalChance > 0 && rng.nextDouble() < criticalChance;
    if (critical) gain *= 10;
    final jackpot =
        has(TrialModifier.jackpot) && rng.nextDouble() < jackpotChance;
    if (jackpot) gain += liveProduction * 60;
    _earn(gain);
    return TrialTapResult(gain, critical: critical, jackpot: jackpot);
  }

  // ── Costs & buying ──────────────────────────────────────────────────────

  double get costGrowth => has(TrialModifier.inflation) ? 1.18 : 1.13;

  /// Where the Volatile Market wave is: −1 (cheapest) to +1 (dearest).
  /// Tied to the wall clock so everyone sees the same prices at once.
  static double marketWave(DateTime now) {
    const period = 180;
    final seconds = now.millisecondsSinceEpoch / 1000 % period;
    return math.sin(2 * math.pi * seconds / period);
  }

  double costMultiplier(DateTime now) {
    var m = math.pow(0.75, perk(TrialPerk.discount)).toDouble();
    if (has(TrialModifier.market)) m *= 1 + 0.4 * marketWave(now);
    return m;
  }

  /// Price of the next unit of generator [i].
  double unitCost(int i, DateTime now) =>
      trialGenerators[i].baseCost *
      math.pow(costGrowth, owned[i]) *
      costMultiplier(now);

  /// Price of the next [count] units (geometric series).
  double costFor(int i, int count, DateTime now) {
    if (count <= 0) return 0;
    final g = costGrowth;
    return unitCost(i, now) * (math.pow(g, count) - 1) / (g - 1);
  }

  /// How many units of [i] the balance covers right now.
  int maxAffordable(int i, DateTime now) {
    final first = unitCost(i, now);
    if (balance < first) return 0;
    final g = costGrowth;
    var n = (math.log(1 + balance * (g - 1) / first) / math.log(g)).floor();
    // Float rounding can land one off either way.
    while (n > 0 && costFor(i, n, now) > balance) {
      n--;
    }
    while (costFor(i, n + 1, now) <= balance) {
      n++;
    }
    return n;
  }

  /// Buys up to [count] units; returns how many were bought.
  int buy(int i, DateTime now, {int count = 1}) {
    if (i < 0 || i >= generatorCount) return 0;
    final n = math.min(count, maxAffordable(i, now));
    if (n <= 0) return 0;
    balance -= costFor(i, n, now);
    if (balance < 0) balance = 0;
    owned[i] += n;
    return n;
  }

  double get tapUpgradeCost => 25 * math.pow(4.5, tapLevel).toDouble();

  bool buyTapUpgrade() {
    if (!tappingEnabled || balance < tapUpgradeCost) return false;
    balance -= tapUpgradeCost;
    tapLevel++;
    return true;
  }

  // ── Drafts & tiers ──────────────────────────────────────────────────────

  int get draftsEarned => trialDraftsReached(totalEarned);
  int get pendingDrafts => math.max(0, draftsEarned - draftsTaken);
  TrialTier get tier => TrialTier.forScore(totalEarned);
  double get nextDraftAt => trialDraftThreshold(draftsEarned + 1);

  /// 0..1 progress toward the next Draft, on a log scale so it moves steadily
  /// instead of sitting near 0% for most of the stretch.
  double get progressToNextDraft {
    final lo = draftsEarned == 0 ? 0.0 : 1.0 + 2 * draftsEarned;
    final hi = 1.0 + 2 * (draftsEarned + 1);
    if (totalEarned <= 1) return 0;
    final now = math.log(totalEarned) / math.ln10;
    return ((now - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  /// Choices for the next Draft waiting to be taken, or empty.
  List<TrialPerk> get draftChoices {
    if (pendingDrafts == 0) return const [];
    return draftOptions(
      weekIndex: week.index,
      draftNumber: draftsTaken + 1,
      modifiers: modifiers,
    );
  }

  /// Takes [perk] for the next pending Draft. Returns false if it isn't one
  /// of the offered choices.
  bool takeDraft(TrialPerk perk) {
    if (!draftChoices.contains(perk)) return false;
    perks[perk] = this.perk(perk) + 1;
    draftsTaken++;
    if (perk == TrialPerk.windfall) _earn(baseProduction * 20 * 60);
    return true;
  }

  int get points => trialPointsFor(totalEarned);

  double get scoreLog10 =>
      totalEarned <= 1 ? 0 : math.log(totalEarned) / math.ln10;

  // ── Persistence ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'week': week.id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'last_update': lastUpdate.millisecondsSinceEpoch,
        'balance': balance,
        'total_earned': totalEarned,
        'tap_level': tapLevel,
        'owned': owned,
        'perks': {for (final e in perks.entries) e.key.name: e.value},
        'drafts_taken': draftsTaken,
        'taps': taps,
      };

  static TrialRun? fromJson(Map<String, dynamic> json) {
    final week = TrialWeek.tryParse(json['week'] as String? ?? '');
    if (week == null) return null;
    double num0(Object? v) {
      final d = (v as num?)?.toDouble() ?? 0;
      return d.isFinite && d > 0 ? d : 0;
    }

    final savedOwned = (json['owned'] as List?)?.cast<num>() ?? const [];
    final owned = List<int>.generate(
      trialGenerators.length,
      (i) => i < savedOwned.length ? math.max(0, savedOwned[i].toInt()) : 0,
    );
    final perks = <TrialPerk, int>{};
    final savedPerks = json['perks'];
    if (savedPerks is Map) {
      for (final entry in savedPerks.entries) {
        final perk =
            TrialPerk.values.where((p) => p.name == entry.key).firstOrNull;
        final count = (entry.value as num?)?.toInt() ?? 0;
        if (perk != null && count > 0) perks[perk] = count;
      }
    }
    return TrialRun(
      week: week,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['started_at'] as num?)?.toInt() ??
              week.start.millisecondsSinceEpoch,
          isUtc: true),
      lastUpdate: DateTime.fromMillisecondsSinceEpoch(
          (json['last_update'] as num?)?.toInt() ??
              week.start.millisecondsSinceEpoch,
          isUtc: true),
      balance: num0(json['balance']),
      totalEarned: num0(json['total_earned']),
      tapLevel: math.max(0, (json['tap_level'] as num?)?.toInt() ?? 0),
      owned: owned,
      perks: perks,
      draftsTaken: math.max(0, (json['drafts_taken'] as num?)?.toInt() ?? 0),
      taps: math.max(0, (json['taps'] as num?)?.toInt() ?? 0),
    );
  }
}
