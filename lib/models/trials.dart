import 'dart:convert';

import '../logic/leaderboard_ranking.dart';

/// Weekly and monthly Trials: a small set of goals everyone gets for the same
/// period, measured against lifetime counters from the moment the period
/// started for this player.
///
/// There is no server to hand out challenges, so they are derived from the
/// period id: every player sees the same goal types in the same week, while
/// the targets are scaled to where each player was when the period began.
/// Periods run on UTC so the weekly and monthly standings line up worldwide.

enum TrialCadence { weekly, monthly }

enum TrialGoal { earn, taps, prestiges, upgrades, sparks }

/// Lifetime totals the trials measure progress against. Each only ever grows
/// (a hard reset aside), so progress is always `now - baseline`.
class TrialCounters {
  const TrialCounters({
    required this.earned,
    this.taps = 0,
    this.prestiges = 0,
    this.upgrades = 0,
    this.sparks = 0,
  });

  static final TrialCounters zero = TrialCounters(earned: BigInt.zero);

  /// Number produced by taps, idle and bursts. Spending never lowers it.
  final BigInt earned;
  final int taps;
  final int prestiges;

  /// Upgrade levels bought, counted across prestiges.
  final int upgrades;

  /// Neural Sparks caught.
  final int sparks;

  BigInt valueOf(TrialGoal goal) {
    switch (goal) {
      case TrialGoal.earn:
        return earned;
      case TrialGoal.taps:
        return BigInt.from(taps);
      case TrialGoal.prestiges:
        return BigInt.from(prestiges);
      case TrialGoal.upgrades:
        return BigInt.from(upgrades);
      case TrialGoal.sparks:
        return BigInt.from(sparks);
    }
  }

  Map<String, dynamic> toJson() => {
        'earned': earned.toString(),
        'taps': taps,
        'prestiges': prestiges,
        'upgrades': upgrades,
        'sparks': sparks,
      };

  factory TrialCounters.fromJson(Map<String, dynamic> json) => TrialCounters(
        earned: BigInt.tryParse(json['earned'] as String? ?? '') ?? BigInt.zero,
        taps: (json['taps'] as num?)?.toInt() ?? 0,
        prestiges: (json['prestiges'] as num?)?.toInt() ?? 0,
        upgrades: (json['upgrades'] as num?)?.toInt() ?? 0,
        sparks: (json['sparks'] as num?)?.toInt() ?? 0,
      );
}

/// Period ids and bounds, all in UTC.
class TrialPeriods {
  TrialPeriods._();

  /// ISO-8601 week id, e.g. `2026-W40`. Weeks start Monday 00:00 UTC and
  /// belong to the year that holds their Thursday.
  static String weekId(DateTime time) {
    final t = time.toUtc();
    final day = DateTime.utc(t.year, t.month, t.day);
    final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
    final week = thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7 + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Calendar month id, e.g. `2026-09`.
  static String monthId(DateTime time) {
    final t = time.toUtc();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}';
  }

  static String idFor(TrialCadence cadence, DateTime time) =>
      cadence == TrialCadence.weekly ? weekId(time) : monthId(time);

  static DateTime startOf(TrialCadence cadence, DateTime time) {
    final t = time.toUtc();
    if (cadence == TrialCadence.monthly) return DateTime.utc(t.year, t.month);
    final day = DateTime.utc(t.year, t.month, t.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime endOf(TrialCadence cadence, DateTime time) {
    final start = startOf(cadence, time);
    return cadence == TrialCadence.monthly
        ? DateTime.utc(start.year, start.month + 1)
        : start.add(const Duration(days: 7));
  }
}

class TrialObjective {
  const TrialObjective({
    required this.goal,
    required this.target,
    required this.reward,
  });

  final TrialGoal goal;
  final BigInt target;

  /// Prestige points paid out on claim.
  final double reward;

  String get id => goal.name;

  Map<String, dynamic> toJson() => {
        'goal': goal.name,
        'target': target.toString(),
        'reward': reward,
      };

  static TrialObjective? fromJson(Map<String, dynamic> json) {
    final goal = TrialGoal.values
        .where((g) => g.name == json['goal'])
        .firstOrNull;
    final target = BigInt.tryParse(json['target'] as String? ?? '');
    if (goal == null || target == null || target <= BigInt.zero) return null;
    return TrialObjective(
      goal: goal,
      target: target,
      reward: (json['reward'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// One period's trial for this player: the goals, where the counters stood
/// when it began, and which rewards have been paid out.
class TrialRun {
  TrialRun({
    required this.cadence,
    required this.periodId,
    required this.baseline,
    required this.objectives,
    required this.sweepReward,
    Set<String>? claimed,
  }) : claimed = claimed ?? <String>{};

  /// Claim key for the bonus paid when every objective is done.
  static const String sweepKey = 'sweep';

  final TrialCadence cadence;
  final String periodId;
  final TrialCounters baseline;
  final List<TrialObjective> objectives;
  final double sweepReward;
  final Set<String> claimed;

  BigInt progressOf(TrialObjective objective, TrialCounters now) {
    final delta = now.valueOf(objective.goal) - baseline.valueOf(objective.goal);
    return delta < BigInt.zero ? BigInt.zero : delta;
  }

  /// 0..1 for progress bars.
  double fractionOf(TrialObjective objective, TrialCounters now) {
    final progress = progressOf(objective, now);
    if (progress >= objective.target) return 1.0;
    return (progress.toDouble() / objective.target.toDouble()).clamp(0.0, 1.0);
  }

  bool isComplete(TrialObjective objective, TrialCounters now) =>
      progressOf(objective, now) >= objective.target;

  bool isClaimed(String key) => claimed.contains(key);

  int completedCount(TrialCounters now) =>
      objectives.where((o) => isComplete(o, now)).length;

  bool allComplete(TrialCounters now) =>
      objectives.isNotEmpty && completedCount(now) == objectives.length;

  bool canClaimSweep(TrialCounters now) =>
      allComplete(now) && !isClaimed(sweepKey);

  /// Whether any reward is ready to be claimed right now.
  bool hasClaimable(TrialCounters now) =>
      canClaimSweep(now) ||
      objectives.any((o) => isComplete(o, now) && !isClaimed(o.id));

  /// Number earned since the period began: the ranked trial score.
  BigInt earnedSince(TrialCounters now) {
    final delta = now.earned - baseline.earned;
    return delta < BigInt.zero ? BigInt.zero : delta;
  }

  TrialObjective? objectiveById(String id) =>
      objectives.where((o) => o.id == id).firstOrNull;

  Map<String, dynamic> toJson() => {
        'cadence': cadence.name,
        'period': periodId,
        'baseline': baseline.toJson(),
        'objectives': [for (final o in objectives) o.toJson()],
        'sweep': sweepReward,
        'claimed': claimed.toList()..sort(),
      };

  static TrialRun? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final cadence = TrialCadence.values
        .where((c) => c.name == json['cadence'])
        .firstOrNull;
    final periodId = json['period'] as String?;
    final baseline = json['baseline'];
    if (cadence == null || periodId == null || baseline is! Map) return null;
    final objectives = [
      for (final raw in json['objectives'] as List<dynamic>? ?? const [])
        if (raw is Map)
          TrialObjective.fromJson(Map<String, dynamic>.from(raw)),
    ].whereType<TrialObjective>().toList();
    if (objectives.isEmpty) return null;
    return TrialRun(
      cadence: cadence,
      periodId: periodId,
      baseline: TrialCounters.fromJson(Map<String, dynamic>.from(baseline)),
      objectives: objectives,
      sweepReward: (json['sweep'] as num?)?.toDouble() ?? 0.0,
      claimed: {
        for (final key in json['claimed'] as List<dynamic>? ?? const [])
          if (key is String) key,
      },
    );
  }

  // ── Generation ─────────────────────────────────────────────────────────

  /// Goals besides [TrialGoal.earn] drawn for each period. Earn is always
  /// in, since it is also what the period's standings rank.
  static const int weeklyExtraGoals = 2;
  static const int monthlyExtraGoals = 3;

  /// Rewards as a share of the next prestige's base PP at period start, so
  /// they stay meaningful without outpacing prestiging itself.
  static const double weeklyObjectiveShare = 0.2;
  static const double weeklySweepShare = 0.5;
  static const double monthlyObjectiveShare = 0.4;
  static const double monthlySweepShare = 1.0;

  /// Builds the trial for the period containing [now].
  ///
  /// [prestigeRequirement] and [prestigeReward] are the player's values at
  /// the start, so targets and rewards are fixed for the whole period and
  /// can't be inflated by claiming later.
  factory TrialRun.start({
    required TrialCadence cadence,
    required DateTime now,
    required TrialCounters counters,
    required int prestigeCount,
    required BigInt prestigeRequirement,
    required double prestigeReward,
  }) {
    final periodId = TrialPeriods.idFor(cadence, now);
    final weekly = cadence == TrialCadence.weekly;
    final goals = [
      TrialGoal.earn,
      ...goalsFor(periodId).take(weekly ? weeklyExtraGoals : monthlyExtraGoals),
    ];
    final objectiveReward = _roundReward(
        prestigeReward * (weekly ? weeklyObjectiveShare : monthlyObjectiveShare));
    return TrialRun(
      cadence: cadence,
      periodId: periodId,
      baseline: counters,
      objectives: [
        for (final goal in goals)
          TrialObjective(
            goal: goal,
            target: targetFor(
              goal,
              cadence: cadence,
              prestigeCount: prestigeCount,
              prestigeRequirement: prestigeRequirement,
            ),
            reward: objectiveReward,
          ),
      ],
      sweepReward: _roundReward(
          prestigeReward * (weekly ? weeklySweepShare : monthlySweepShare)),
    );
  }

  /// The non-earn goals in this period's order. Deterministic on every
  /// platform (Dart's String.hashCode and Random are not), so all players
  /// get the same set.
  static List<TrialGoal> goalsFor(String periodId) {
    final pool = TrialGoal.values.where((g) => g != TrialGoal.earn).toList();
    var state = _fnv1a(periodId);
    for (var i = pool.length - 1; i > 0; i--) {
      state = _xorshift32(state);
      final j = state % (i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    return pool;
  }

  static BigInt targetFor(
    TrialGoal goal, {
    required TrialCadence cadence,
    required int prestigeCount,
    required BigInt prestigeRequirement,
  }) {
    final weekly = cadence == TrialCadence.weekly;
    switch (goal) {
      case TrialGoal.earn:
        // 1.5 runs' worth a week, 5 a month: the prestige requirement grows
        // with the player, so this stays a stretch at every stage.
        final target = weekly
            ? prestigeRequirement * BigInt.from(3) ~/ BigInt.two
            : prestigeRequirement * BigInt.from(5);
        return target > BigInt.zero ? target : BigInt.from(1000);
      case TrialGoal.taps:
        return BigInt.from(weekly ? 2500 : 10000);
      case TrialGoal.prestiges:
        // Late runs take far longer, so ask for fewer of them.
        final int count;
        if (prestigeCount < 6) {
          count = weekly ? 3 : 8;
        } else if (prestigeCount < 11) {
          count = weekly ? 2 : 5;
        } else {
          count = weekly ? 1 : 3;
        }
        return BigInt.from(count);
      case TrialGoal.upgrades:
        return BigInt.from(weekly ? 150 : 600);
      case TrialGoal.sparks:
        return BigInt.from(weekly ? 15 : 50);
    }
  }

  static double _roundReward(double value) {
    if (!value.isFinite || value < 1.0) return 1.0;
    return (value * 10).roundToDouble() / 10;
  }

  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      // hash * 0x01000193 mod 2^32, split so it never exceeds 2^53 (the
      // integer limit of JS numbers on web).
      hash = (((hash << 24) & 0xffffffff) + hash * 0x193) & 0xffffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static int _xorshift32(int x) {
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    return x & 0xffffffff;
  }
}

/// The player's current weekly and monthly trials.
class TrialState {
  TrialState({this.weekly, this.monthly});

  TrialRun? weekly;
  TrialRun? monthly;

  TrialRun? runFor(TrialCadence cadence) =>
      cadence == TrialCadence.weekly ? weekly : monthly;

  /// Starts a fresh run for any cadence whose period has moved on. Returns
  /// whether anything changed.
  bool roll({
    required DateTime now,
    required TrialCounters counters,
    required int prestigeCount,
    required BigInt prestigeRequirement,
    required double prestigeReward,
  }) {
    var changed = false;
    for (final cadence in TrialCadence.values) {
      final current = runFor(cadence);
      if (current != null &&
          current.periodId == TrialPeriods.idFor(cadence, now)) {
        continue;
      }
      final next = TrialRun.start(
        cadence: cadence,
        now: now,
        counters: counters,
        prestigeCount: prestigeCount,
        prestigeRequirement: prestigeRequirement,
        prestigeReward: prestigeReward,
      );
      if (cadence == TrialCadence.weekly) {
        weekly = next;
      } else {
        monthly = next;
      }
      changed = true;
    }
    return changed;
  }

  bool hasClaimable(TrialCounters now) =>
      (weekly?.hasClaimable(now) ?? false) ||
      (monthly?.hasClaimable(now) ?? false);

  Map<String, dynamic> toJson() => {
        if (weekly != null) 'weekly': weekly!.toJson(),
        if (monthly != null) 'monthly': monthly!.toJson(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory TrialState.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? mapOf(Object? raw) =>
        raw is Map ? Map<String, dynamic>.from(raw) : null;
    TrialRun? runOf(String key, TrialCadence cadence) {
      final run = TrialRun.fromJson(mapOf(json[key]));
      return run?.cadence == cadence ? run : null;
    }

    return TrialState(
      weekly: runOf('weekly', TrialCadence.weekly),
      monthly: runOf('monthly', TrialCadence.monthly),
    );
  }

  /// Never throws: an unreadable blob just starts fresh trials.
  static TrialState parse(String? raw) {
    if (raw == null || raw.isEmpty) return TrialState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return TrialState.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return TrialState();
  }

  /// Weekly/monthly standing for the public leaderboard row.
  static Map<String, dynamic> leaderboardFields(
    TrialState state,
    TrialCounters now,
  ) {
    Map<String, dynamic> fieldsFor(String prefix, TrialRun? run) {
      if (run == null) return const {};
      final earned = run.earnedSince(now);
      return {
        '${prefix}_id': run.periodId,
        '${prefix}_earned_numeric': earned.toString(),
        '${prefix}_earned_log10': highestNumberSortKey(earned),
        '${prefix}_done': run.completedCount(now),
      };
    }

    return {
      ...fieldsFor('week', state.weekly),
      ...fieldsFor('month', state.monthly),
    };
  }
}
