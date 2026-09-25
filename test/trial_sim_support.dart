import 'dart:math' as math;

import 'package:number_flutter/logic/trial/trial_calendar.dart';
import 'package:number_flutter/logic/trial/trial_rules.dart';
import 'package:number_flutter/logic/trial/trial_run.dart';

/// A scripted player for pacing tests: plays [sessionsPerDay] sessions of
/// [sessionMinutes] each, tapping [tapsPerSecond], buying greedily, and is
/// away the rest of the day.
class TrialSimPlayer {
  final int sessionsPerDay;
  final int sessionMinutes;
  final int tapsPerSecond;

  const TrialSimPlayer({
    required this.sessionsPerDay,
    required this.sessionMinutes,
    required this.tapsPerSecond,
  });

  static const engaged =
      TrialSimPlayer(sessionsPerDay: 3, sessionMinutes: 10, tapsPerSecond: 5);
  static const casual =
      TrialSimPlayer(sessionsPerDay: 1, sessionMinutes: 5, tapsPerSecond: 3);
  static const idle =
      TrialSimPlayer(sessionsPerDay: 2, sessionMinutes: 1, tapsPerSecond: 0);
}

const List<TrialPerk> _perkPriority = [
  TrialPerk.overtime,
  TrialPerk.specialist,
  TrialPerk.synergy,
  TrialPerk.discount,
  TrialPerk.sharpTaps,
  TrialPerk.bootstrap,
  TrialPerk.nightOwl,
  TrialPerk.critical,
  TrialPerk.windfall,
];

void _takeDrafts(TrialRun run) {
  while (run.pendingDrafts > 0) {
    final choices = run.draftChoices;
    final pick = _perkPriority.firstWhere(choices.contains);
    run.takeDraft(pick);
  }
}

void _buyGreedy(TrialRun run, DateTime now, {bool tapUpgrades = true}) {
  for (var guard = 0; guard < 500; guard++) {
    var bestIndex = -1;
    var bestRatio = 0.0;
    final before = run.baseProduction;
    for (var i = 0; i < run.generatorCount; i++) {
      final cost = run.unitCost(i, now);
      run.owned[i]++;
      final gain = run.baseProduction - before;
      run.owned[i]--;
      // Something to start with when nothing produces yet.
      final ratio = (gain <= 0 ? trialGenerators[i].baseRate : gain) / cost;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        bestIndex = i;
      }
    }
    if (tapUpgrades &&
        run.tappingEnabled &&
        bestIndex >= 0 &&
        run.tapUpgradeCost <= run.unitCost(bestIndex, now) &&
        run.buyTapUpgrade()) {
      continue;
    }
    if (bestIndex < 0 || run.buy(bestIndex, now) == 0) return;
  }
}

/// Plays a full week and returns the final run.
TrialRun simulateTrialWeek(TrialWeek week, TrialSimPlayer player,
    {int seed = 1, void Function(Duration elapsed, TrialRun run)? onSession}) {
  final rng = math.Random(seed);
  var now = week.start;
  final run = TrialRun.fresh(week, now);
  final gap = Duration(
      minutes: 24 * 60 ~/ player.sessionsPerDay - player.sessionMinutes);
  while (now.isBefore(week.end)) {
    run.applyAway(now);
    _takeDrafts(run);
    for (var s = 0; s < player.sessionMinutes * 60; s++) {
      for (var t = 0; t < player.tapsPerSecond; t++) {
        run.tap(now, rng);
      }
      now = now.add(const Duration(seconds: 1));
      run.tick(1, now);
      _takeDrafts(run);
      _buyGreedy(run, now, tapUpgrades: player.tapsPerSecond > 0);
    }
    onSession?.call(now.difference(week.start), run);
    now = now.add(gap);
  }
  run.applyAway(week.end);
  return run;
}

/// One continuous session, reporting after every minute.
void simulateTrialWeekMinutes(TrialWeek week, TrialSimPlayer player,
    void Function(int minute, TrialRun run) onMinute) {
  final rng = math.Random(1);
  var now = week.start;
  final run = TrialRun.fresh(week, now);
  for (var m = 1; m <= player.sessionMinutes; m++) {
    for (var s = 0; s < 60; s++) {
      for (var t = 0; t < player.tapsPerSecond; t++) {
        run.tap(now, rng);
      }
      now = now.add(const Duration(seconds: 1));
      run.tick(1, now);
      _takeDrafts(run);
      _buyGreedy(run, now);
    }
    onMinute(m, run);
  }
}
