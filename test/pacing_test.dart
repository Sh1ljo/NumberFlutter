import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';

/// First-run pacing for a player who always takes the upgrade advisor's
/// pick, at a fixed tapping pace.
class _Run {
  double? firstIdleBuy;
  double? idleOvertakesTapping;
  double? firstPrestige;
}

Future<_Run> _simulate(double tapsPerSecond) async {
  SharedPreferences.setMockInitialValues({});
  final gs = GameState();
  await gs.ready;
  gs.debugSetTutorialStep(TutorialStep.done);
  gs.debugClickRateOverride = tapsPerSecond;
  gs.number = BigInt.zero;
  var now = DateTime(2026, 1, 1);
  gs.clock = () => now;

  final run = _Run();
  const dt = 5;
  for (var t = 0.0; t < 3 * 3600; t += dt) {
    for (var i = 0; i < 25; i++) {
      final rec = gs.recommendedUpgrade;
      if (rec == null || !rec.affordableNow) break;
      if (!gs.buyUpgradeLevels(rec.upgradeId, rec.amount)) break;
      if (rec.category == GameState.idleCategory) run.firstIdleBuy ??= t;
    }
    final income = gs.debugExpectedIncome(tapsPerSecond);
    if (income.idle > 0 && income.idle >= income.tapping) {
      run.idleOvertakesTapping ??= t;
    }
    gs.number += BigInt.from((income.idle + income.tapping) * dt);
    now = now.add(const Duration(seconds: dt));
    if (gs.number >= gs.prestigeRequirement) {
      run.firstPrestige = t + dt;
      break;
    }
  }
  gs.dispose();
  return run;
}

double _min(double? seconds) => (seconds ?? double.infinity) / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Before the click branch was repriced, 4 taps/s reached the first
  // prestige in ~9 minutes without ever buying a generator, while a light
  // tapper needed ~52. See GAME_MATH_REFERENCE.md, "Early-game balance".
  group('first run pacing', () {
    late _Run active;
    late _Run light;

    setUpAll(() async {
      active = await _simulate(4);
      light = await _simulate(0.5);
    });

    test('every player buys a generator within the first few minutes', () {
      expect(_min(active.firstIdleBuy), lessThan(5));
      expect(_min(light.firstIdleBuy), lessThan(5));
    });

    test('idle overtakes tapping early even for a fast tapper', () {
      expect(_min(active.idleOvertakesTapping), lessThan(15));
      expect(_min(light.idleOvertakesTapping), lessThan(15));
    });

    test('the first prestige takes a real session, not a few minutes', () {
      expect(_min(active.firstPrestige), inInclusiveRange(18, 45));
      expect(_min(light.firstPrestige), inInclusiveRange(35, 75));
    });

    test('tapping is rewarded without replacing idle', () {
      final speedup = light.firstPrestige! / active.firstPrestige!;
      expect(speedup, inInclusiveRange(1.4, 3.0));
    });
  });
}
