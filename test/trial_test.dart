import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:number_flutter/logic/trial/trial_calendar.dart';
import 'package:number_flutter/logic/trial/trial_rules.dart';
import 'package:number_flutter/logic/trial/trial_run.dart';

import 'trial_sim_support.dart';

void main() {
  group('TrialWeek', () {
    test('starts on Monday 00:00 UTC and lasts 7 days', () {
      final week = TrialWeek.containing(DateTime.utc(2026, 9, 25, 13, 5));
      expect(week.id, '2026-09-21');
      expect(week.start, DateTime.utc(2026, 9, 21));
      expect(week.end, DateTime.utc(2026, 9, 28));
      expect(week.start.weekday, DateTime.monday);
    });

    test('Sunday 23:59 and Monday 00:00 are different weeks', () {
      final sunday = TrialWeek.containing(DateTime.utc(2026, 9, 27, 23, 59));
      final monday = TrialWeek.containing(DateTime.utc(2026, 9, 28));
      expect(sunday.id, '2026-09-21');
      expect(monday.id, '2026-09-28');
      expect(sunday.next, monday);
      expect(monday.previous, sunday);
      expect(monday.index, sunday.index + 1);
    });

    test('local times resolve to the UTC week', () {
      // 2026-09-28 00:30 at UTC+2 is still Sunday in UTC.
      final local = DateTime.parse('2026-09-28T00:30:00+02:00');
      expect(TrialWeek.containing(local).id, '2026-09-21');
    });

    test('ISO week numbers', () {
      expect(TrialWeek.containing(DateTime.utc(2026, 9, 21)).isoWeekNumber, 39);
      expect(TrialWeek.containing(DateTime.utc(2026, 1, 1)).isoWeekNumber, 1);
      // 2027-01-01 is a Friday: it belongs to 2026's week 53.
      expect(TrialWeek.containing(DateTime.utc(2027, 1, 1)).isoWeekNumber, 53);
    });

    test('tryParse round-trips and rejects non-Mondays', () {
      final week = TrialWeek.containing(DateTime.utc(2026, 3, 4));
      expect(TrialWeek.tryParse(week.id), week);
      expect(TrialWeek.tryParse('2026-09-22'), isNull);
      expect(TrialWeek.tryParse('nonsense'), isNull);
    });

    test('each week belongs to exactly one month, by its Thursday', () {
      // Mon Sep 28 – Sun Oct 4 2026: Thursday is Oct 1.
      expect(TrialWeek.tryParse('2026-09-28')!.month.id, '2026-10');
      final september = const TrialMonth(2026, 9);
      expect(september.weeks.map((w) => w.id),
          ['2026-08-31', '2026-09-07', '2026-09-14', '2026-09-21']);
      expect(september.end, DateTime.utc(2026, 9, 28));
      // Over a year, every week lands in exactly one month.
      var week = TrialWeek.containing(DateTime.utc(2026, 1, 1));
      for (var i = 0; i < 60; i++) {
        final owners = [
          for (var m = 1; m <= 12; m++)
            for (final y in [2025, 2026, 2027])
              if (TrialMonth(y, m).weeks.contains(week)) TrialMonth(y, m),
        ];
        expect(owners, [week.month]);
        week = week.next;
      }
    });

    test('countdown formatting', () {
      expect(formatTrialCountdown(const Duration(days: 2, hours: 4)), '2d 4h');
      expect(formatTrialCountdown(const Duration(hours: 3, minutes: 12)),
          '3h 12m');
      expect(formatTrialCountdown(const Duration(minutes: 8)), '8m');
      expect(formatTrialCountdown(const Duration(seconds: 20)), '<1m');
    });
  });

  group('modifiers', () {
    test('one twist and one rule, never conflicting', () {
      for (var i = 2900; i < 3100; i++) {
        final mods = modifiersForWeekIndex(i);
        expect(mods, hasLength(2));
        expect(mods[0].kind, TrialModifierKind.twist);
        expect(mods[1].kind, TrialModifierKind.rule);
        expect(
            mods.contains(TrialModifier.handsOff) &&
                mods.contains(TrialModifier.glassCannon),
            isFalse);
        expect(
            mods.contains(TrialModifier.nightShift) &&
                mods.contains(TrialModifier.blackout),
            isFalse);
      }
    });

    test('back-to-back weeks never repeat a twist or a rule', () {
      for (var i = 2900; i < 3100; i++) {
        final a = modifiersForWeekIndex(i);
        final b = modifiersForWeekIndex(i + 1);
        expect(a[0], isNot(b[0]), reason: 'twist, week $i');
        expect(a[1], isNot(b[1]), reason: 'rule, week $i');
      }
    });

    test('most pairings come up over a year and a half', () {
      final pairs = {
        for (var i = 3000; i < 3078; i++)
          modifiersForWeekIndex(i).map((m) => m.name).join('+'),
      };
      // 36 pairs minus the 2 conflicting ones.
      expect(pairs.length, greaterThanOrEqualTo(30));
    });
  });

  group('drafts', () {
    test('same week and draft number give the same choices', () {
      final mods = modifiersForWeekIndex(2960);
      for (var n = 1; n < 12; n++) {
        final a =
            draftOptions(weekIndex: 2960, draftNumber: n, modifiers: mods);
        final b =
            draftOptions(weekIndex: 2960, draftNumber: n, modifiers: mods);
        expect(a, b);
        expect(a.toSet(), hasLength(a.length), reason: 'no duplicates');
      }
    });

    test('Wildcard offers four, others three', () {
      expect(
          draftOptions(
              weekIndex: 1,
              draftNumber: 1,
              modifiers: [TrialModifier.momentum, TrialModifier.wildcard]),
          hasLength(4));
      expect(
          draftOptions(
              weekIndex: 1,
              draftNumber: 1,
              modifiers: [TrialModifier.momentum, TrialModifier.inflation]),
          hasLength(3));
    });

    test('Hands Off never offers tap perks, Blackout never offers Night Owl',
        () {
      for (var n = 1; n < 40; n++) {
        final handsOff = draftOptions(
            weekIndex: n * 3,
            draftNumber: n,
            modifiers: [TrialModifier.handsOff, TrialModifier.wildcard]);
        expect(handsOff.where((p) => p.needsTapping), isEmpty);
        final blackout = draftOptions(
            weekIndex: n * 3,
            draftNumber: n,
            modifiers: [TrialModifier.momentum, TrialModifier.blackout]);
        expect(blackout, isNot(contains(TrialPerk.nightOwl)));
      }
    });

    test('TrialRandom is deterministic and in range', () {
      final a = TrialRandom(42);
      final b = TrialRandom(42);
      for (var i = 0; i < 1000; i++) {
        final x = a.nextInt(7);
        expect(x, b.nextInt(7));
        expect(x, inInclusiveRange(0, 6));
      }
      final d = TrialRandom(0).nextDouble();
      expect(d, inInclusiveRange(0.0, 1.0));
    });

    test('drafts unlock every ×100 from 1K and must be taken in order', () {
      final run = _run(TrialModifier.momentum, TrialModifier.inflation);
      expect(run.pendingDrafts, 0);
      run.totalEarned = 999;
      expect(run.pendingDrafts, 0);
      run.totalEarned = 1000;
      expect(run.pendingDrafts, 1);
      run.totalEarned = 1e5;
      expect(run.pendingDrafts, 2);
      final offered = run.draftChoices;
      final notOffered =
          TrialPerk.values.firstWhere((p) => !offered.contains(p));
      expect(run.takeDraft(notOffered), isFalse);
      expect(run.takeDraft(offered.first), isTrue);
      expect(run.pendingDrafts, 1);
      expect(run.perk(offered.first), 1);
    });
  });

  group('economy', () {
    test('a fresh run already produces, even with tapping disabled', () {
      final run = _run(TrialModifier.handsOff, TrialModifier.inflation);
      expect(run.tappingEnabled, isFalse);
      expect(run.liveProduction, greaterThan(0));
      expect(run.tap(DateTime.utc(2026, 9, 21), math.Random(1)).gain, 0);
    });

    test('score counts everything earned, not the balance', () {
      final now = DateTime.utc(2026, 9, 21, 1);
      final run = _run(TrialModifier.chainReaction, TrialModifier.inflation);
      run.balance = 1000;
      run.totalEarned = 1000;
      expect(run.buy(0, now, count: 3), 3);
      expect(run.balance, lessThan(1000));
      expect(run.totalEarned, 1000);
    });

    test('bulk cost equals buying one at a time', () {
      final now = DateTime.utc(2026, 9, 21, 1);
      final a = _run(TrialModifier.chainReaction, TrialModifier.inflation);
      final b = _run(TrialModifier.chainReaction, TrialModifier.inflation);
      a.balance = b.balance = 1e9;
      final bulk = a.costFor(2, 10, now);
      var single = 0.0;
      for (var i = 0; i < 10; i++) {
        single += b.unitCost(2, now);
        b.buy(2, now);
      }
      expect(bulk, closeTo(single, single * 1e-9));
    });

    test('maxAffordable is exact', () {
      final now = DateTime.utc(2026, 9, 21, 1);
      final run = _run(TrialModifier.chainReaction, TrialModifier.inflation);
      for (final balance in [0.0, 9.0, 10.0, 11.0, 1234.0, 5e8, 7.7e13]) {
        run.balance = balance;
        for (var i = 0; i < run.generatorCount; i++) {
          final n = run.maxAffordable(i, now);
          expect(run.costFor(i, n, now), lessThanOrEqualTo(balance));
          expect(run.costFor(i, n + 1, now), greaterThan(balance));
        }
      }
    });

    test('Minimalist removes the top two generators', () {
      final run = _run(TrialModifier.chainReaction, TrialModifier.minimalist);
      run.balance = 1e30;
      expect(run.generatorCount, 4);
      expect(run.buy(5, DateTime.utc(2026, 9, 21)), 0);
    });

    test('Volatile Market moves prices within ±40%', () {
      final run = _run(TrialModifier.market, TrialModifier.inflation);
      final prices = <double>[];
      for (var s = 0; s < 180; s += 5) {
        prices.add(run.costMultiplier(DateTime.utc(2026, 9, 21, 0, 0, s)));
      }
      expect(prices.reduce(math.min), closeTo(0.6, 0.02));
      expect(prices.reduce(math.max), closeTo(1.4, 0.02));
    });

    test('Momentum combo builds with taps and drains when idle', () {
      final run = _run(TrialModifier.momentum, TrialModifier.inflation);
      var now = DateTime.utc(2026, 9, 21);
      for (var i = 0; i < 40; i++) {
        run.tap(now, math.Random(1));
      }
      expect(run.comboMultiplier, closeTo(4, 1e-9));
      now = now.add(const Duration(seconds: 1));
      run.tick(1, now);
      expect(run.comboMultiplier, lessThan(4));
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(seconds: 1));
        run.tick(1, now);
      }
      expect(run.comboMultiplier, 1);
    });

    test('away earnings are half rate, capped, and stop at week end', () {
      final week = TrialWeek.containing(DateTime.utc(2026, 9, 21));
      final run = TrialRun(
        week: week,
        startedAt: week.start,
        owned: [10, 0, 0, 0, 0, 0],
      );
      final perSecond = run.baseProduction;
      expect(run.modifiers, isNot(contains(TrialModifier.blackout)));
      expect(run.modifiers, isNot(contains(TrialModifier.nightShift)));

      run.lastUpdate = week.start;
      final gained = run.applyAway(week.start.add(const Duration(hours: 1)));
      expect(gained, closeTo(perSecond * 3600 * 0.5, 1e-6));

      run.lastUpdate = week.start;
      final capped = run.applyAway(week.start.add(const Duration(days: 2)));
      expect(capped, closeTo(perSecond * 8 * 3600 * 0.5, 1e-6));

      run.lastUpdate = week.end.subtract(const Duration(hours: 1));
      final late = run.applyAway(week.end.add(const Duration(days: 3)));
      expect(late, closeTo(perSecond * 3600 * 0.5, 1e-6));
    });

    test('Windfall pays 20 minutes of production', () {
      final run = _run(TrialModifier.chainReaction, TrialModifier.inflation);
      run.owned[1] = 20;
      // Find a draft that offers Windfall.
      for (var n = 0;
          n < 60 && !run.draftChoices.contains(TrialPerk.windfall);
          n++) {
        run.totalEarned = trialDraftThreshold(run.draftsTaken + 1);
        if (!run.draftChoices.contains(TrialPerk.windfall)) {
          run.takeDraft(run.draftChoices.first);
        }
      }
      expect(run.draftChoices, contains(TrialPerk.windfall));
      final before = run.totalEarned;
      final expected = run.baseProduction * 1200;
      run.takeDraft(TrialPerk.windfall);
      expect(run.totalEarned - before, closeTo(expected, expected * 1e-9));
    });

    test('tiers and points', () {
      expect(TrialTier.forScore(0).name, 'Unranked');
      expect(TrialTier.forScore(999).name, 'Unranked');
      expect(TrialTier.forScore(1000).name, 'Bronze');
      expect(TrialTier.forScore(1e6).name, 'Silver');
      expect(TrialTier.forScore(1e15).name, 'Diamond');
      expect(TrialTier.forScore(1e60).name, 'Legend');
      expect(trialPointsFor(1e15), 1500);
      expect(trialPointsFor(0), 0);
    });

    test('save round-trips', () {
      final now = DateTime.utc(2026, 9, 22, 5);
      final run = _run(TrialModifier.momentum, TrialModifier.wildcard);
      run
        ..balance = 12345.5
        ..totalEarned = 9.9e9
        ..tapLevel = 3
        ..draftsTaken = 2
        ..taps = 77
        ..lastUpdate = now;
      run.owned[3] = 12;
      run.perks[TrialPerk.overtime] = 2;
      final copy = TrialRun.fromJson(run.toJson())!;
      expect(copy.toJson(), run.toJson());
      expect(copy.modifiers, run.modifiers);
      expect(TrialRun.fromJson({'week': 'bad'}), isNull);
    });

    test('corrupt saves are sanitised', () {
      final copy = TrialRun.fromJson({
        'week': '2026-09-21',
        'balance': double.nan,
        'total_earned': -5,
        'owned': [-3, 2],
        'perks': {'overtime': 2, 'bogus': 4},
      })!;
      expect(copy.balance, 0);
      expect(copy.totalEarned, 0);
      expect(copy.owned, [0, 2, 0, 0, 0, 0]);
      expect(copy.perks, {TrialPerk.overtime: 2});
    });
  });

  group('pacing', () {
    final weeks = [
      for (var i = 0; i < 6; i++)
        TrialWeek.containing(
            DateTime.utc(2026, 9, 21).add(Duration(days: 7 * i))),
    ];

    test('the first Draft comes within two minutes of play', () {
      final week = weeks.first;
      var firstDraftMinute = -1;
      simulateTrialWeekMinutes(
        week,
        const TrialSimPlayer(
            sessionsPerDay: 1, sessionMinutes: 5, tapsPerSecond: 5),
        (minute, run) {
          if (firstDraftMinute < 0 && run.draftsEarned > 0) {
            firstDraftMinute = minute;
          }
        },
      );
      expect(firstDraftMinute, inInclusiveRange(1, 2));
    });

    test('every player type makes real progress every week', () {
      for (final week in weeks) {
        for (final player in [
          TrialSimPlayer.engaged,
          TrialSimPlayer.casual,
          TrialSimPlayer.idle,
        ]) {
          final run = simulateTrialWeek(week, player);
          expect(run.scoreLog10, inInclusiveRange(12, 20),
              reason: '${week.id} ${run.modifiers}');
          expect(run.draftsTaken, greaterThanOrEqualTo(5));
        }
      }
    });

    test('playing more never scores less than barely checking in', () {
      for (final week in weeks) {
        final engaged = simulateTrialWeek(week, TrialSimPlayer.engaged);
        final casual = simulateTrialWeek(week, TrialSimPlayer.casual);
        final idle = simulateTrialWeek(week, TrialSimPlayer.idle);
        expect(engaged.scoreLog10, greaterThanOrEqualTo(idle.scoreLog10),
            reason: '${week.id} ${engaged.modifiers}');
        expect(engaged.scoreLog10, greaterThan(casual.scoreLog10));
      }
    });
  });
}

TrialRun _run(TrialModifier twist, TrialModifier rule) {
  // Find a real week with this pair so the run's modifiers match.
  for (var i = 2900; i < 3200; i++) {
    final mods = modifiersForWeekIndex(i);
    if (mods[0] == twist && mods[1] == rule) {
      final start = DateTime.fromMillisecondsSinceEpoch(
          (i * 7 - 3) * Duration.millisecondsPerDay,
          isUtc: true);
      final week = TrialWeek.containing(start);
      expect(week.index, i);
      return TrialRun.fresh(week, week.start);
    }
  }
  throw StateError('No week pairs $twist with $rule');
}
