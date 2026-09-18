import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';
import 'package:number_flutter/ui/widgets/tutorial_overlay.dart';

/// Minimal harness: a fake screen with one targetable widget per
/// [TutorialTarget] the tests need, plus the overlay on top.
class _Harness extends StatefulWidget {
  final GameState gameState;
  final int currentTab;
  final Size surfaceSize;
  final bool provideTargets;

  const _Harness({
    required this.gameState,
    this.currentTab = TutorialTab.generators,
    this.surfaceSize = const Size(390, 780),
    this.provideTargets = true,
  });

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final Map<TutorialTarget, GlobalKey> _keys = {
    for (final t in TutorialTarget.values) t: GlobalKey(),
  };

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>.value(
      value: widget.gameState,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Stack(
            children: [
              if (widget.provideTargets)
                Positioned(
                  left: 40,
                  top: 200,
                  child: Container(
                    key: _keys[TutorialTarget.tapArea],
                    width: 200,
                    height: 120,
                    color: Colors.blue,
                  ),
                ),
              if (widget.provideTargets)
                Positioned(
                  left: 40,
                  bottom: 20,
                  child: Container(
                    key: _keys[TutorialTarget.navUpgrades],
                    width: 80,
                    height: 50,
                    color: Colors.green,
                  ),
                ),
              if (widget.provideTargets)
                Positioned(
                  left: 40,
                  top: 300,
                  child: Container(
                    key: _keys[TutorialTarget.prestigeMultiplier],
                    width: 150,
                    height: 80,
                    color: Colors.purple,
                  ),
                ),
              TutorialOverlay(
                resolveKey: (t) =>
                    widget.provideTargets ? _keys[t] : null,
                currentTab: widget.currentTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  late GameState gameState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gameState = GameState();
    await gameState.ready;
  });

  tearDown(() {
    gameState.dispose();
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    int currentTab = TutorialTab.generators,
    Size size = const Size(390, 780),
    bool provideTargets = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_Harness(
      gameState: gameState,
      currentTab: currentTab,
      surfaceSize: size,
      provideTargets: provideTargets,
    ));
    // Let the post-frame hole resolution and its retries settle.
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('rendering', () {
    testWidgets('welcome shows its card and a SKIP button', (tester) async {
      gameState.debugSetTutorialStep(TutorialStep.welcome);
      await pumpHarness(tester);

      expect(find.text('WELCOME TO NUMBER'), findsOneWidget);
      expect(find.text('SKIP'), findsOneWidget);
      expect(find.text('TAP ANYWHERE TO CONTINUE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides itself entirely once the tutorial is done',
        (tester) async {
      gameState.debugSetTutorialStep(TutorialStep.done);
      await pumpHarness(tester);

      expect(find.text('SKIP'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every step renders without throwing', (tester) async {
      // The whole point of the spec table: no step can produce a broken frame.
      for (final step in TutorialStep.values) {
        if (step == TutorialStep.done) continue;
        gameState.debugSetTutorialStep(step);
        await pumpHarness(tester);
        expect(tester.takeException(), isNull,
            reason: '${step.name} threw while rendering');
      }
    });
  });

  group('escape hatch', () {
    testWidgets('SKIP is present on every step, in every mode',
        (tester) async {
      // Previously the floatingHint path drew no SKIP at all, so several
      // steps could wedge with no way out.
      for (final step in TutorialStep.values) {
        if (step == TutorialStep.done) continue;
        gameState.debugSetTutorialStep(step);
        await pumpHarness(tester);
        expect(find.text('SKIP'), findsOneWidget,
            reason: 'no SKIP on ${step.name} (${specFor(step).mode.name})');
      }
    });

    testWidgets('SKIP is present even on the wrong tab', (tester) async {
      // clickToFifty requires the generators tab.
      gameState.debugSetTutorialStep(TutorialStep.clickToFifty);
      await pumpHarness(tester, currentTab: TutorialTab.prestige);

      expect(find.text('SKIP'), findsOneWidget);
      // ...but the card for a step that isn't on this screen should not be.
      expect(find.text('GENERATORS'), findsNothing);
    });

    testWidgets('SKIP is present when the target never resolves',
        (tester) async {
      gameState.debugSetTutorialStep(TutorialStep.navUpgrades);
      await pumpHarness(tester, provideTargets: false);

      expect(find.text('SKIP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SKIP from an upgrade step ends the tutorial outright',
        (tester) async {
      // It used to drop the player at learnPrestige, so escaping took up to
      // four presses.
      gameState.debugSetTutorialStep(TutorialStep.momentumIntro);
      await pumpHarness(tester);

      await tester.tap(find.text('SKIP'));
      // Past GameState's 350ms save debounce, so no timer is left pending
      // when the binding checks its invariants.
      await tester.pump(const Duration(milliseconds: 600));

      expect(gameState.tutorialStep, TutorialStep.done);
      expect(gameState.isTutorialActive, isFalse);
    });
  });

  group('advancing', () {
    testWidgets('tap-to-continue advances on a tap anywhere', (tester) async {
      gameState.debugSetTutorialStep(TutorialStep.welcome);
      await pumpHarness(tester);

      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(gameState.tutorialStep, TutorialStep.clickToFifty);
    });

    testWidgets('a spotlight step does not advance on a dim tap',
        (tester) async {
      gameState.debugSetTutorialStep(TutorialStep.clickToFifty);
      await pumpHarness(tester);

      // Top-left corner is dim, well away from the 40,200 target.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 100));

      expect(gameState.tutorialStep, TutorialStep.clickToFifty);
    });

    testWidgets('spotlightTapToContinue advances on a tap inside the hole',
        (tester) async {
      gameState.debugSetTutorialStep(TutorialStep.prestigeMultiplierHint);
      await pumpHarness(tester, currentTab: TutorialTab.prestige);

      // Inside the 40,300,150x80 target rect.
      await tester.tapAt(const Offset(60, 320));
      await tester.pump(const Duration(milliseconds: 100));

      expect(gameState.tutorialStep, TutorialStep.prestigeGainHint);
    });

    testWidgets(
        'spotlightTapToContinue does not advance on a tap in the dim area',
        (tester) async {
      gameState.debugSetTutorialStep(TutorialStep.prestigeMultiplierHint);
      await pumpHarness(tester, currentTab: TutorialTab.prestige);

      // Well outside the 40,300,150x80 target rect.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 100));

      expect(gameState.tutorialStep, TutorialStep.prestigeMultiplierHint);
    });
  });

  group('narrow viewports', () {
    testWidgets('does not throw below the old 328px clamp floor',
        (tester) async {
      // With a fixed 280px card and 24px margins, clamp(24, width - 304)
      // inverted below 328px wide and threw an assertion.
      for (final width in [320.0, 300.0, 280.0, 240.0, 200.0]) {
        gameState.debugSetTutorialStep(TutorialStep.welcome);
        await pumpHarness(tester, size: Size(width, 640));
        expect(tester.takeException(), isNull,
            reason: 'threw at width $width');
        expect(find.text('WELCOME TO NUMBER'), findsOneWidget);
      }
    });

    testWidgets('long copy stays on screen on a short viewport',
        (tester) async {
      // neuralAccuracyLimit has one of the longest bodies.
      gameState.debugSetTutorialStep(TutorialStep.neuralAccuracyLimit);
      await pumpHarness(
        tester,
        currentTab: TutorialTab.neural,
        size: const Size(360, 520),
      );

      expect(tester.takeException(), isNull);
      final card = find.text('ALWAYS TRAINING');
      expect(card, findsOneWidget);
      final rect = tester.getRect(card);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(520));
    });
  });
}
