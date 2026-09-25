import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/trial/trial_controller.dart';
import 'package:number_flutter/logic/trial/trial_rules.dart';
import 'package:number_flutter/ui/screens/leaderboard_screen.dart';
import 'package:number_flutter/ui/screens/trial/trial_screen.dart';

/// A Momentum + Milestone Madness week, so the modifiers are known.
final DateTime _fixedNow = DateTime.utc(2026, 10, 20, 12);

Widget _host(TrialController trial, Widget Function(BuildContext) open) =>
    ChangeNotifierProvider.value(
      value: trial,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: open),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _finishGuide(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    if (find.text('GOT IT').evaluate().isNotEmpty) {
      await tester.tap(find.text('GOT IT'));
      await _pumpFor(tester, const Duration(milliseconds: 400));
      return;
    }
    await tester.tap(find.text('NEXT'));
    await _pumpFor(tester, const Duration(milliseconds: 400));
  }
  fail('Guide never reached its last step');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TrialController trial;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    trial = TrialController(clock: () => _fixedNow);
  });
  tearDown(() => trial.dispose());

  test('fixed week really is Momentum + Milestone Madness', () {
    expect(trial.modifiers,
        [TrialModifier.momentum, TrialModifier.milestoneMadness]);
  });

  testWidgets('enter, guide, tap, buy, draft, exit', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(trial, (_) => const TrialScreen()));
    await tester.tap(find.text('OPEN'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    // First visit: the guide walks through the screen, then gets out of the way.
    expect(find.text('WELCOME TO THE WEEKLY TRIAL'), findsOneWidget);
    await _finishGuide(tester);
    expect(find.text('WELCOME TO THE WEEKLY TRIAL'), findsNothing);

    expect(trial.isActive, isTrue);
    expect(find.text('WEEKLY TRIAL'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
    expect(find.text('Momentum'), findsOneWidget);
    expect(find.text('Milestone Madness'), findsOneWidget);
    expect(find.textContaining('main game keeps running'), findsOneWidget);
    expect(find.textContaining('5d 12h left'), findsOneWidget);

    // Tapping earns and builds the Momentum combo.
    final run = trial.run!;
    expect(run.owned[0], 1, reason: 'every run starts with a free Tally');
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.textContaining('TAP ANYWHERE HERE'));
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(run.taps, 12);
    expect(run.totalEarned, greaterThan(12));
    expect(find.textContaining('COMBO'), findsOneWidget);

    // Buy a Tally from the build list.
    run.balance = 1000;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Tally'));
    await tester.pump();
    final buyButton = find.descendant(
      of: find
          .ancestor(of: find.text('Tally'), matching: find.byType(Container))
          .first,
      matching: find.byType(FilledButton),
    );
    await tester.tap(buyButton);
    await tester.pump(const Duration(milliseconds: 100));
    expect(run.owned[0], 2);

    // Reaching 1K offers a Draft; picking a perk applies it.
    run.totalEarned = 1500;
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('DRAFT READY · PICK A PERK'), findsOneWidget);
    await tester.tap(find.text('DRAFT READY · PICK A PERK'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('DRAFT 1'), findsOneWidget);
    final choice = run.draftChoices.first;
    await tester.tap(find.text(choice.title));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(run.perk(choice), 1);
    expect(run.pendingDrafts, 0);
    expect(find.text('DRAFT 1'), findsNothing);

    // EXIT goes straight back and stops the Trial ticking.
    await tester.tap(find.text('EXIT'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('OPEN'), findsOneWidget);
    expect(trial.isActive, isFalse);
    expect(tester.takeException(), isNull);

    // Re-entering continues the same run and skips the guide.
    await tester.tap(find.text('OPEN'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('WELCOME TO THE WEEKLY TRIAL'), findsNothing);
    expect(identical(trial.run, run), isTrue);
    await tester.tap(find.text('EXIT'));
    await _pumpFor(tester, const Duration(seconds: 1));
  });

  testWidgets('fits a small 360x640 phone, guide included', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(trial, (_) => const TrialScreen()));
    await tester.tap(find.text('OPEN'));
    await _pumpFor(tester, const Duration(seconds: 1));
    for (var i = 0; i < 10 && find.text('GOT IT').evaluate().isEmpty; i++) {
      // Every guide card stays fully on screen.
      final card = tester.getRect(find
          .ancestor(of: find.text('NEXT'), matching: find.byType(Container))
          .first);
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(640));
      await tester.tap(find.text('NEXT'));
      await _pumpFor(tester, const Duration(milliseconds: 400));
    }
    await tester.tap(find.text('GOT IT'));
    await _pumpFor(tester, const Duration(milliseconds: 400));
    trial.run!
      ..totalEarned = 3.3e21
      ..balance = 9.9e20
      ..owned.setAll(0, [120, 110, 100, 90, 80, 70]);
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('EXIT'));
    await _pumpFor(tester, const Duration(seconds: 1));
  });

  testWidgets('run survives a reload from storage', (tester) async {
    await tester.runAsync(() async {
      await trial.enter();
      trial.run!.totalEarned = 4242;
      trial.run!.owned[1] = 3;
      await trial.leave();
    });
    final reloaded = TrialController(clock: () => _fixedNow);
    addTearDown(reloaded.dispose);
    await tester.runAsync(reloaded.ensureLoaded);
    expect(reloaded.run, isNotNull);
    expect(reloaded.run!.totalEarned, greaterThanOrEqualTo(4242));
    expect(reloaded.run!.owned[1], 3);
  });

  testWidgets('a finished week is recapped and a fresh run starts',
      (tester) async {
    await tester.runAsync(() async {
      await trial.enter();
      trial.run!.totalEarned = 2e9;
      await trial.leave();
    });
    // A week later.
    final nextWeek =
        TrialController(clock: () => _fixedNow.add(const Duration(days: 7)));
    addTearDown(nextWeek.dispose);
    await tester.runAsync(nextWeek.enter);
    final recap = nextWeek.takeFinishedWeek();
    expect(recap, isNotNull);
    expect(recap!.total, greaterThanOrEqualTo(2e9));
    expect(recap.tier.name, 'Gold');
    expect(nextWeek.run!.totalEarned, lessThan(10));
    expect(nextWeek.run!.week.id, isNot(recap.weekId));
    // Its points count toward the month it belongs to.
    final month = nextWeek.history[recap.weekId]!;
    expect(month.points, 930);
    await tester.runAsync(nextWeek.leave);
  });

  testWidgets('leaderboard: guide walks the tabs, Trial cards work offline',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(trial, (_) => const LeaderboardScreen()));
    await tester.tap(find.text('OPEN'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.text('THREE LEADERBOARDS'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    // The guide switched to the Weekly tab to show the Trial card.
    expect(find.text('THE WEEKLY TRIAL'), findsOneWidget);
    expect(find.text('ENTER THE TRIAL'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('OCTOBER'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('GOT IT'));
    await _pumpFor(tester, const Duration(milliseconds: 600));

    // No cloud in tests: the Trial card still offers to play offline.
    expect(find.text('WEEKLY TRIAL'), findsOneWidget);
    expect(find.text('ENTER THE TRIAL'), findsOneWidget);
    expect(find.textContaining('including the Trial'), findsOneWidget);

    await tester.tap(find.text('ALL-TIME'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('LEADERBOARDS'), findsOneWidget);
    expect(find.text('ENTER THE TRIAL'), findsNothing);

    await tester.tap(find.text('MONTHLY'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('MONTHLY TRIAL'), findsOneWidget);
    expect(find.textContaining('YOUR TOTAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
