import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';
import 'package:number_flutter/models/upgrade.dart';

Future<void> _flushSaves() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Upgrade _u(GameState gs, String id) => gs.upgrades.firstWhere((u) => u.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a legacy save with the 100M grant baked in is repaired on load',
      () async {
    // Written mid upgrade deep-dive by a build that stored its borrowed
    // budget. The deep-dive no longer exists; the grant must still go.
    SharedPreferences.setMockInitialValues({
      'number': '100000030',
      'highestNumber': '100000030',
      'tutorialStep': 'buyMomentum',
      'upgradeLevels': '{"click_power":1,"click_probability_strike":1}',
    });
    final gs = GameState();
    await gs.ready;
    addTearDown(gs.dispose);

    expect(gs.number, BigInt.from(30));
    expect(gs.highestNumber, BigInt.from(30));
    expect(_u(gs, GameState.probabilityStrikeId).level, 0);
    // That player was past everything chapter 1 teaches.
    expect(gs.tutorialCompleted, isTrue);
    expect(gs.tutorialStep, TutorialStep.done);
  });

  test('a chapter 1 purchase is kept: nothing is borrowed or taken back',
      () async {
    SharedPreferences.setMockInitialValues({});
    final gs = GameState();
    await gs.ready;
    addTearDown(gs.dispose);
    gs.debugSetTutorialStep(TutorialStep.buyClickPower);
    gs.onMainTabChanged(TutorialTab.upgrades);
    gs.number = BigInt.from(40);

    gs.buyUpgrade(GameState.clickPowerId);

    expect(gs.tutorialStep, TutorialStep.navGeneratorsForSpark);
    expect(gs.number, BigInt.from(25));
    expect(_u(gs, GameState.clickPowerId).level, 1);
    await _flushSaves();
    final prefs = await SharedPreferences.getInstance();
    expect(BigInt.parse(prefs.getString('number')!), BigInt.from(25));
  });

  group('gain preview', () {
    late GameState gs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gs = GameState();
      await gs.ready;
      gs.skipTutorial();
    });

    tearDown(() => gs.dispose());

    test('click power shows the multiplied gain, not the raw +1', () {
      gs.prestigeMultiplier = 3.0;
      final preview = gs.upgradeGainPreview(_u(gs, GameState.clickPowerId), 1);
      expect(preview.perClick, closeTo(3.0 * gs.globalProductionMultiplier, 1e-9));
      expect(preview.perSecond, 0);
    });

    test('idle tiers show real N/s, including a milestone doubling', () {
      final auto = _u(gs, GameState.autoClickerId);
      auto.level = 24;
      gs.debugRecalculateDerivedStats();
      final preview = gs.upgradeGainPreview(auto, 1);
      // Level 25 doubles the whole tier: 25×2 − 24 = 26 base N/s.
      expect(preview.perSecond,
          closeTo(26 * gs.totalMultiplier, 1e-6));
      expect(auto.level, 24, reason: 'preview must not leak levels');
    });

    test('special upgrades describe their stat change', () {
      final strike =
          gs.upgradeGainPreview(_u(gs, GameState.probabilityStrikeId), 1);
      expect(strike.perClick, greaterThan(0));
      expect(strike.detail, isNotNull);
      final momentum = gs.upgradeGainPreview(_u(gs, GameState.momentumId), 1);
      expect(momentum.detail, contains('Max combo'));
    });
  });

  group('recommended upgrade', () {
    late GameState gs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gs = GameState();
      await gs.ready;
      gs.skipTutorial();
    });

    tearDown(() => gs.dispose());

    test('is hidden while the tutorial steers purchases', () {
      gs.debugSetTutorialStep(TutorialStep.buyAutoClicker);
      expect(gs.recommendedUpgrade, isNull);
    });

    test('an idle player is pointed at idle upgrades', () {
      gs.debugClickRateOverride = 0;
      _u(gs, GameState.autoClickerId).level = 10;
      _u(gs, GameState.clickPowerId).level = 10;
      gs.number = BigInt.from(5000);
      gs.debugRecalculateDerivedStats();
      final rec = gs.recommendedUpgrade!;
      expect(rec.category, GameState.idleCategory);
    });

    test('a fast tapper is pointed at click upgrades', () {
      gs.debugClickRateOverride = 8;
      _u(gs, GameState.autoClickerId).level = 1;
      gs.debugRecalculateDerivedStats();
      gs.number = BigInt.from(50);
      final rec = gs.recommendedUpgrade!;
      expect(rec.category, GameState.clickCategory);
    });

    test('recommends several levels when they are all worth it, and BUY '
        'charges exactly the quoted cost', () {
      gs.debugClickRateOverride = 0;
      _u(gs, GameState.autoClickerId).level = 1;
      gs.debugRecalculateDerivedStats();
      gs.number = BigInt.from(100000);
      final rec = gs.recommendedUpgrade!;
      expect(rec.amount, greaterThan(1));
      expect(rec.affordableNow, isTrue);

      final before = gs.number;
      final levelBefore = _u(gs, rec.upgradeId).level;
      expect(gs.buyUpgradeLevels(rec.upgradeId, rec.amount), isTrue);
      expect(before - gs.number, rec.cost);
      expect(_u(gs, rec.upgradeId).level, levelBefore + rec.amount);
    });

    test('computing it leaves the real state untouched', () {
      gs.debugClickRateOverride = 3;
      _u(gs, GameState.autoClickerId).level = 30;
      _u(gs, GameState.clickPowerId).level = 12;
      gs.number = BigInt.from(1000000);
      gs.debugRecalculateDerivedStats();
      final levels = [for (final u in gs.upgrades) u.level];
      final click = gs.clickPower;
      final idle = gs.totalIdleRate;
      final number = gs.number;

      expect(gs.recommendedUpgrade, isNotNull);
      expect([for (final u in gs.upgrades) u.level], levels);
      expect(gs.clickPower, click);
      expect(gs.totalIdleRate, idle);
      expect(gs.number, number);
    });

    test('just short of the prestige requirement it says to save instead',
        () {
      gs.debugClickRateOverride = 0;
      _u(gs, GameState.autoClickerId).level = 10;
      gs.debugRecalculateDerivedStats();
      // A second of idle income away: nothing can pay for itself in time.
      gs.number = gs.prestigeRequirement - BigInt.one;

      expect(gs.recommendedUpgrade, isNull);
      expect(gs.advisorSavingForPrestige, isTrue);
    });

    test('far from the requirement it recommends as usual', () {
      gs.debugClickRateOverride = 0;
      _u(gs, GameState.autoClickerId).level = 10;
      gs.debugRecalculateDerivedStats();
      gs.number = BigInt.from(5000);

      expect(gs.recommendedUpgrade, isNotNull);
      expect(gs.advisorSavingForPrestige, isFalse);
    });

    test('once prestige is ready it only spends the surplus above it', () {
      gs.debugClickRateOverride = 0;
      _u(gs, GameState.autoClickerId).level = 10;
      gs.debugRecalculateDerivedStats();
      final requirement = gs.prestigeRequirement;
      gs.number = requirement + BigInt.from(2000);

      final rec = gs.recommendedUpgrade!;
      expect(rec.reserve, requirement);
      expect(rec.affordableWith(gs.number), rec.affordableNow);
      if (rec.affordableNow) {
        expect(gs.buyUpgradeLevels(rec.upgradeId, rec.amount), isTrue);
        expect(gs.number >= requirement, isTrue,
            reason: 'following the advice must keep PRESTIGE available');
      }
    });

    test('following it every time grows production (greedy sim)', () {
      gs.debugClickRateOverride = 2;
      gs.number = BigInt.from(200);
      var now = DateTime(2026, 1, 1);
      gs.clock = () => now;
      var bought = 0;
      // Simulate ~2 hours of play in 10s steps, always taking the advice.
      for (var t = 0; t < 720; t++) {
        now = now.add(const Duration(seconds: 10));
        final rec = gs.recommendedUpgrade;
        if (rec != null && rec.affordableNow) {
          if (gs.buyUpgradeLevels(rec.upgradeId, rec.amount)) bought++;
        }
        final perSec =
            gs.totalIdleRate + 2 * gs.clickPower.toDouble() * gs.prestigeMultiplier;
        gs.number += BigInt.from((perSec * 10).floor());
      }
      expect(bought, greaterThan(20));
      // Several idle tiers climbed, rather than one tier forever.
      final idleTiersOwned = gs.upgrades
          .where((u) => u.effectType == GameState.idleCategory && u.level > 0)
          .length;
      expect(idleTiersOwned, greaterThanOrEqualTo(3));
    });
  });
}
