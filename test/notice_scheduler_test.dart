import 'package:flutter_test/flutter_test.dart';

import 'package:number_flutter/logic/notice_scheduler.dart';

void main() {
  final DateTime t0 = DateTime.utc(2026, 1, 1);

  group('NoticeScheduler.upgrades', () {
    late NoticeScheduler schedule;

    setUp(() {
      schedule = NoticeScheduler.upgrades();
    });

    test('lone unlock: false before settle, true at settle, gap zero while fresh',
        () {
      expect(schedule.currentGap, Duration.zero);
      schedule.noteArrivals(now: t0);

      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: t0.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: t0.add(const Duration(seconds: 3)),
        ),
        isTrue,
      );
      expect(schedule.currentGap, Duration.zero);
    });

    test('burst folding: not showable until settleQuiet after the last arrival',
        () {
      schedule.noteArrivals(now: t0);
      schedule.noteArrivals(now: t0.add(const Duration(seconds: 2)));
      schedule.noteArrivals(now: t0.add(const Duration(seconds: 4)));

      final lastArrival = t0.add(const Duration(seconds: 4));
      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: lastArrival.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: lastArrival.add(const Duration(seconds: 3)),
        ),
        isTrue,
      );

      schedule.recordShown(now: lastArrival.add(const Duration(seconds: 3)));
      expect(schedule.currentGap, const Duration(seconds: 20));
    });

    test('maxWait caps a never-quiet stream', () {
      var at = t0;
      schedule.noteArrivals(now: at);
      // A new id every 2s never reaches settleQuiet (3s).
      for (var i = 0; i < 7; i++) {
        at = at.add(const Duration(seconds: 2));
        schedule.noteArrivals(now: at);
      }
      expect(at, t0.add(const Duration(seconds: 14)));

      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: at,
        ),
        isFalse,
      );
      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: t0.add(schedule.maxWait),
        ),
        isTrue,
      );
    });

    test('backoff doubles after each show and caps at maxGap', () {
      schedule.noteArrivals(now: t0);
      schedule.recordShown(now: t0.add(const Duration(seconds: 3)));
      expect(schedule.currentGap, const Duration(seconds: 20));

      schedule.recordShown(now: t0);
      expect(schedule.currentGap, const Duration(seconds: 40));

      schedule.recordShown(now: t0);
      expect(schedule.currentGap, const Duration(seconds: 80));

      schedule.recordShown(now: t0);
      expect(schedule.currentGap, const Duration(seconds: 160));

      schedule.recordShown(now: t0);
      expect(schedule.currentGap, const Duration(minutes: 3));

      schedule.recordShown(now: t0);
      expect(schedule.currentGap, const Duration(minutes: 3));
    });

    test('resetQuiet with no arrivals returns the gap to zero', () {
      schedule.noteArrivals(now: t0);
      schedule.recordShown(now: t0.add(const Duration(seconds: 3)));
      expect(schedule.currentGap, const Duration(seconds: 20));

      // Next unlock arrives but the screen is busy, so the batch sits.
      final heldAt = t0.add(const Duration(seconds: 4));
      schedule.noteArrivals(now: heldAt);
      expect(schedule.currentGap, const Duration(seconds: 20));

      final later = heldAt.add(schedule.resetQuiet);
      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: later,
        ),
        isTrue,
      );
      expect(schedule.currentGap, Duration.zero);
    });

    test('a lone unlock after resetQuiet is timely, not stuck behind the gap',
        () {
      schedule.noteArrivals(now: t0);
      schedule.recordShown(now: t0.add(const Duration(seconds: 3)));
      expect(schedule.currentGap, const Duration(seconds: 20));

      final nextUnlock = t0.add(schedule.resetQuiet);
      schedule.noteArrivals(now: nextUnlock);
      expect(schedule.currentGap, Duration.zero);
      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: true,
          now: nextUnlock.add(schedule.settleQuiet),
        ),
        isTrue,
      );
    });

    test('screenAllows or empty queue never shows', () {
      schedule.noteArrivals(now: t0);
      expect(
        schedule.canShow(
          hasPending: true,
          screenAllows: false,
          now: t0.add(schedule.settleQuiet),
        ),
        isFalse,
      );
      expect(
        schedule.canShow(
          hasPending: false,
          screenAllows: true,
          now: t0.add(schedule.settleQuiet),
        ),
        isFalse,
      );
    });
  });

  group('NoticeScheduler.achievements preset', () {
    test('10s base / 60s cap / 60s reset', () {
      final schedule = NoticeScheduler.achievements();
      expect(schedule.baseGap, const Duration(seconds: 10));
      expect(schedule.maxGap, const Duration(minutes: 1));
      expect(schedule.resetQuiet, const Duration(minutes: 1));
      expect(schedule.settleQuiet, const Duration(seconds: 2));
      expect(schedule.maxWait, const Duration(seconds: 8));
    });
  });
}
