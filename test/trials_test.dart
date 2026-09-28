import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/backend_service.dart';
import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/sync_service.dart';
import 'package:number_flutter/models/leaderboard.dart';
import 'package:number_flutter/models/player_progress.dart';
import 'package:number_flutter/models/trials.dart';
import 'package:number_flutter/ui/screens/leaderboard/leaderboard_format.dart';

TrialCounters _counters({
  int earned = 0,
  int taps = 0,
  int prestiges = 0,
  int upgrades = 0,
  int sparks = 0,
}) =>
    TrialCounters(
      earned: BigInt.from(earned),
      taps: taps,
      prestiges: prestiges,
      upgrades: upgrades,
      sparks: sparks,
    );

TrialRun _start(
  TrialCadence cadence,
  DateTime now, {
  TrialCounters? counters,
  int prestigeCount = 0,
  int requirement = 100000000,
  double reward = 3.0,
}) =>
    TrialRun.start(
      cadence: cadence,
      now: now,
      counters: counters ?? TrialCounters.zero,
      prestigeCount: prestigeCount,
      prestigeRequirement: BigInt.from(requirement),
      prestigeReward: reward,
    );

LeaderboardEntry _entry(String id, {int highest = 0, double? loss}) =>
    LeaderboardEntry(
      userId: id,
      displayName: id,
      highestNumber: BigInt.from(highest),
      lifetimeEarned: BigInt.zero,
      lowestLoss: loss,
      weekEarned: BigInt.zero,
      monthEarned: BigInt.zero,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('periods', () {
    test('ISO week ids, including year boundaries', () {
      expect(TrialPeriods.weekId(DateTime.utc(2026, 9, 28)), '2026-W40');
      expect(TrialPeriods.weekId(DateTime.utc(2026, 10, 4, 23, 59)), '2026-W40');
      expect(TrialPeriods.weekId(DateTime.utc(2026, 10, 5)), '2026-W41');
      // Jan 3 2021 is a Sunday still in 2020's last week.
      expect(TrialPeriods.weekId(DateTime.utc(2021, 1, 3)), '2020-W53');
      // Dec 30 2024 is a Monday in 2025's first week.
      expect(TrialPeriods.weekId(DateTime.utc(2024, 12, 30)), '2025-W01');
    });

    test('weeks start Monday 00:00 UTC and months on the 1st', () {
      final t = DateTime.utc(2026, 9, 30, 15);
      expect(TrialPeriods.startOf(TrialCadence.weekly, t),
          DateTime.utc(2026, 9, 28));
      expect(TrialPeriods.endOf(TrialCadence.weekly, t),
          DateTime.utc(2026, 10, 5));
      expect(TrialPeriods.monthId(t), '2026-09');
      expect(TrialPeriods.startOf(TrialCadence.monthly, t),
          DateTime.utc(2026, 9));
      expect(TrialPeriods.endOf(TrialCadence.monthly, DateTime.utc(2026, 12, 9)),
          DateTime.utc(2027, 1));
    });
  });

  group('generation', () {
    test('everyone gets the same goals for a period, earn always first', () {
      final now = DateTime.utc(2026, 9, 28);
      final a = _start(TrialCadence.weekly, now);
      final b = _start(TrialCadence.weekly, now,
          counters: _counters(earned: 999, taps: 5), prestigeCount: 12);
      expect(a.objectives.map((o) => o.goal), b.objectives.map((o) => o.goal));
      expect(a.objectives.first.goal, TrialGoal.earn);
      expect(a.objectives, hasLength(1 + TrialRun.weeklyExtraGoals));
      expect(a.objectives.map((o) => o.goal).toSet(), hasLength(3));

      final month = _start(TrialCadence.monthly, now);
      expect(month.objectives, hasLength(1 + TrialRun.monthlyExtraGoals));
    });

    test('the goal mix changes between periods', () {
      final mixes = {
        for (var week = 1; week <= 30; week++)
          TrialRun.goalsFor('2026-W${week.toString().padLeft(2, '0')}')
              .take(2)
              .map((g) => g.name)
              .join(','),
      };
      expect(mixes.length, greaterThan(3));
    });

    test('targets scale with progress; rewards with the prestige reward', () {
      final now = DateTime.utc(2026, 9, 28);
      final early = _start(TrialCadence.weekly, now);
      final late = _start(TrialCadence.weekly, now,
          prestigeCount: 14, requirement: 1000000000, reward: 60);
      final earlyEarn = early.objectives.first;
      final lateEarn = late.objectives.first;
      expect(earlyEarn.target, BigInt.from(150000000));
      expect(lateEarn.target, BigInt.from(1500000000));
      expect(earlyEarn.reward, 1.0); // 0.2 x 3 PP, floored at 1
      expect(lateEarn.reward, 12.0);
      expect(late.sweepReward, 30.0);

      expect(
        TrialRun.targetFor(TrialGoal.prestiges,
            cadence: TrialCadence.weekly,
            prestigeCount: 2,
            prestigeRequirement: BigInt.one),
        BigInt.from(3),
      );
      expect(
        TrialRun.targetFor(TrialGoal.prestiges,
            cadence: TrialCadence.weekly,
            prestigeCount: 15,
            prestigeRequirement: BigInt.one),
        BigInt.one,
      );
    });
  });

  group('progress', () {
    test('counts only what happened since the period began', () {
      final run = _start(TrialCadence.weekly, DateTime.utc(2026, 9, 28),
          counters: _counters(earned: 1000, taps: 50));
      final earn = run.objectives.first;
      final now = _counters(earned: 1000 + 75000000, taps: 60);
      expect(run.progressOf(earn, now), BigInt.from(75000000));
      expect(run.fractionOf(earn, now), closeTo(0.5, 1e-9));
      expect(run.isComplete(earn, now), isFalse);
      expect(run.earnedSince(now), BigInt.from(75000000));

      // A counter that went backwards (e.g. an older cloud copy) never
      // shows negative progress.
      expect(run.progressOf(earn, _counters()), BigInt.zero);
    });

    test('roll keeps the current period and replaces a stale one', () {
      final state = TrialState();
      bool roll(DateTime now, TrialCounters c) => state.roll(
            now: now,
            counters: c,
            prestigeCount: 0,
            prestigeRequirement: BigInt.from(100000000),
            prestigeReward: 3,
          );

      expect(roll(DateTime.utc(2026, 9, 28), _counters()), isTrue);
      final firstWeek = state.weekly!;
      firstWeek.claimed.add('earn');
      expect(roll(DateTime.utc(2026, 9, 30), _counters(earned: 5)), isFalse);
      expect(identical(state.weekly, firstWeek), isTrue);

      expect(roll(DateTime.utc(2026, 10, 5), _counters(earned: 9)), isTrue);
      expect(state.weekly!.periodId, '2026-W41');
      expect(state.weekly!.baseline.earned, BigInt.from(9));
      expect(state.weekly!.claimed, isEmpty);
      expect(state.monthly!.periodId, '2026-10');
    });

    test('state survives JSON and garbage parses to empty', () {
      final state = TrialState();
      state.roll(
        now: DateTime.utc(2026, 9, 28),
        counters: _counters(earned: 42, sparks: 3),
        prestigeCount: 4,
        prestigeRequirement: BigInt.parse('123456789012345678901234567890'),
        prestigeReward: 7.5,
      );
      state.weekly!.claimed.addAll(['earn', TrialRun.sweepKey]);

      final back = TrialState.parse(state.toJsonString());
      expect(back.weekly!.periodId, state.weekly!.periodId);
      expect(back.weekly!.baseline.earned, BigInt.from(42));
      expect(back.weekly!.baseline.sparks, 3);
      expect(back.weekly!.claimed, {'earn', 'sweep'});
      expect(back.weekly!.objectives.first.target,
          state.weekly!.objectives.first.target);
      expect(back.monthly!.objectives.length, state.monthly!.objectives.length);

      expect(TrialState.parse('not json').weekly, isNull);
      expect(TrialState.parse('{"weekly":{"cadence":"monthly"}}').weekly,
          isNull);
    });

    test('leaderboard fields carry the period score', () {
      final state = TrialState();
      state.roll(
        now: DateTime.utc(2026, 9, 28),
        counters: _counters(earned: 100),
        prestigeCount: 0,
        prestigeRequirement: BigInt.from(1000),
        prestigeReward: 3,
      );
      final fields =
          TrialState.leaderboardFields(state, _counters(earned: 1100));
      expect(fields['week_id'], '2026-W40');
      expect(fields['week_earned_numeric'], '1000');
      expect(fields['week_earned_log10'], closeTo(3.0, 1e-9));
      expect(fields['week_done'], 0);
      expect(fields['month_id'], '2026-09');
    });
  });

  group('GameState', () {
    Future<GameState> fresh() async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.ready;
      addTearDown(gs.dispose);
      return gs;
    }

    test('loading starts both trials', () async {
      final gs = await fresh();
      expect(gs.trials.weekly, isNotNull);
      expect(gs.trials.monthly, isNotNull);
      expect(gs.hasClaimableTrialReward, isFalse);
    });

    test('a save from before the counter starts at its highest number',
        () async {
      SharedPreferences.setMockInitialValues({
        'number': '500',
        'highestNumber': '123456789',
      });
      final gs = GameState();
      await gs.ready;
      addTearDown(gs.dispose);
      expect(gs.lifetimeEarned, BigInt.from(123456789));
      // The trial baseline is taken after the seed, so it adds no progress.
      expect(gs.trials.weekly!.earnedSince(gs.trialCounters), BigInt.zero);
    });

    test('taps, purchases and sparks feed the lifetime counters', () async {
      final gs = await fresh();
      final gain = gs.click().gain;
      expect(gs.lifetimeEarned, gain);
      expect(gs.trialCounters.taps, 1);

      gs.number = BigInt.from(1000000);
      gs.setSelectedUpgradeCategory(GameState.idleCategory);
      gs.buyUpgrade(GameState.autoClickerId);
      expect(gs.lifetimeUpgradeLevels, greaterThan(0));
      // Spending never lowers what was earned.
      expect(gs.lifetimeEarned, gain);

      gs.activateNeuralSparkBoost();
      expect(gs.lifetimeSparks, 1);
    });

    test('an objective pays once, and the sweep after all are done',
        () async {
      final gs = await fresh();
      final run = gs.trials.weekly!;
      final earn = run.objectives.first;
      expect(gs.claimTrialObjective(TrialCadence.weekly, earn.id), isNull);

      gs.lifetimeEarned += earn.target;
      expect(gs.hasClaimableTrialReward, isTrue);
      final before = gs.prestigeCurrency;
      expect(gs.claimTrialObjective(TrialCadence.weekly, earn.id), earn.reward);
      expect(gs.prestigeCurrency, closeTo(before + earn.reward, 1e-9));
      expect(gs.claimTrialObjective(TrialCadence.weekly, earn.id), isNull);
      expect(gs.claimTrialSweep(TrialCadence.weekly), isNull);

      // Finish everything else.
      gs.lifetimeClicks += 1000000;
      gs.lifetimeUpgradeLevels += 1000000;
      gs.lifetimeSparks += 1000000;
      gs.prestigeCount += 100;
      expect(run.allComplete(gs.trialCounters), isTrue);
      expect(gs.claimTrialSweep(TrialCadence.weekly), run.sweepReward);
      expect(gs.claimTrialSweep(TrialCadence.weekly), isNull);
    });
  });

  test('sync keeps the larger trial counters from either side', () {
    PlayerProgress progress(int n, DateTime at) => PlayerProgress(
          userId: 'u',
          number: BigInt.one,
          clickPower: BigInt.one,
          autoClickRate: 0,
          prestigeCurrency: 0,
          prestigeMultiplier: 1,
          prestigeCount: 0,
          upgradeLevels: const {},
          highestNumber: BigInt.one,
          progressScore: 0,
          lifetimeEarned: BigInt.from(n),
          lifetimeUpgradeLevels: n,
          lifetimeSparks: n,
          trialsJson: 'from-$n',
          updatedAt: at,
        );
    final bigOld = progress(500, DateTime.utc(2026, 1, 1));
    final smallNew = progress(10, DateTime.utc(2026, 1, 2));
    final result = SyncService.pickWinner(
        local: bigOld, remote: smallNew, forceUpload: false);
    expect(result.winner, SyncWinner.remote);
    expect(result.resolved.lifetimeEarned, BigInt.from(500));
    expect(result.resolved.lifetimeUpgradeLevels, 500);
    expect(result.resolved.lifetimeSparks, 500);
    // Claims travel with the winner's prestige points.
    expect(result.resolved.trialsJson, 'from-10');

    final back = PlayerProgress.fromDatabase(bigOld.toDatabase());
    expect(back.lifetimeEarned, BigInt.from(500));
    expect(back.trialsJson, 'from-500');
  });

  group('leaderboard', () {
    test('ranks exactly and densely, best first', () {
      final ranked = BackendService.rankEntries([
        _entry('a', highest: 5),
        _entry('b', highest: 9),
        _entry('c', highest: 9),
        _entry('d', highest: 1),
      ], LeaderboardMetric.highest);
      expect(ranked.map((e) => e.userId), ['b', 'c', 'a', 'd']);
      expect(ranked.map((e) => e.rank), [1, 1, 2, 3]);

      final byAccuracy = BackendService.rankEntries([
        _entry('worse', loss: 0.2),
        _entry('better', loss: 0.01),
      ], LeaderboardMetric.accuracy);
      expect(byAccuracy.first.userId, 'better');
    });

    test('gap to the next player up', () {
      expect(
        LeaderboardFormat.gap(_entry('me', highest: 900),
            _entry('them', highest: 1000), LeaderboardMetric.highest),
        '+101',
      );
      expect(
        LeaderboardFormat.gap(_entry('me', loss: 0.05),
            _entry('them', loss: 0.04), LeaderboardMetric.accuracy),
        '+1.00%',
      );
      expect(
        LeaderboardFormat.gap(_entry('me', highest: 5),
            _entry('them', highest: 1), LeaderboardMetric.highest),
        isNull,
      );
    });

    test('rows from older builds still parse', () {
      final entry = LeaderboardEntry.fromDatabase('x', {
        'display_name': '  Ada Lovelace ',
        'highest_number_numeric': '12345',
        'neural_lowest_loss': 0.25,
      });
      expect(entry.displayName, 'Ada Lovelace');
      expect(entry.initials, 'AL');
      expect(entry.prestigeCount, isNull);
      expect(entry.accuracyPercent, closeTo(75, 1e-9));
      expect(entry.valueFor(LeaderboardMetric.prestiges), 0);
    });
  });
}
