import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';
import 'package:number_flutter/models/upgrade.dart';

Future<GameState> _game([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final gs = GameState();
  await gs.ready;
  return gs;
}

/// A prestige plus the end of its reveal animation, which is when the
/// post-prestige chapters start.
Future<void> _prestigeAndReveal(GameState gs) async {
  gs.number = gs.prestigeRequirement;
  await gs.prestige();
  gs.setPrestigeAnimating(false);
}

int _level(GameState gs, String id) =>
    gs.upgrades.firstWhere((u) => u.id == id).level;

Upgrade _upgrade(GameState gs, String id) =>
    gs.upgrades.firstWhere((u) => u.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chapter 1', () {
    test('walks from the first tap to the road ahead and keeps everything',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      expect(gs.tutorialStep, TutorialStep.welcome);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.clickToFifty);

      gs.number = GameState.tutorialFirstClickTarget - BigInt.one;
      gs.click();
      expect(gs.tutorialStep, TutorialStep.navUpgrades);

      gs.onMainTabChanged(TutorialTab.upgrades);
      expect(gs.tutorialStep, TutorialStep.selectIdle);

      gs.setSelectedUpgradeCategory(GameState.idleCategory);
      expect(gs.tutorialStep, TutorialStep.buyAutoClicker);

      gs.buyUpgrade(GameState.autoClickerId);
      expect(gs.tutorialStep, TutorialStep.navGenerators);

      gs.onMainTabChanged(TutorialTab.generators);
      expect(gs.tutorialStep, TutorialStep.watchIdle);

      gs.number = GameState.tutorialIdleWatchTarget;
      gs.click();
      expect(gs.tutorialStep, TutorialStep.navUpgradesForClick);

      gs.onMainTabChanged(TutorialTab.upgrades);
      expect(gs.tutorialStep, TutorialStep.buyClickPower);
      expect(gs.selectedUpgradeCategory, GameState.clickCategory);

      gs.buyUpgrade(GameState.clickPowerId);
      expect(gs.tutorialStep, TutorialStep.navGeneratorsForSpark);

      gs.onMainTabChanged(TutorialTab.generators);
      expect(gs.tutorialStep, TutorialStep.catchSpark);

      gs.activateNeuralSparkBoost();
      expect(gs.tutorialStep, TutorialStep.roadAhead);
      expect(gs.tutorialCompleted, isFalse);

      final numberBefore = gs.number;
      gs.onTutorialTapToContinue();

      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.tutorialCompleted, isTrue);
      // No reset at the end any more: what the player earned stays.
      expect(gs.number, numberBefore);
      expect(_level(gs, GameState.autoClickerId), 1);
      expect(_level(gs, GameState.clickPowerId), 1);
      // Finishing it earns a Spark Surge.
      expect(gs.isShopSparkSurgeActive, isTrue);
    });

    test('SKIP ends it with progress kept, but no reward', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.number = BigInt.from(500);

      gs.skipTutorial();

      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.tutorialCompleted, isTrue);
      expect(gs.number, BigInt.from(500));
      expect(gs.isShopSparkSurgeActive, isFalse);
    });

    test('skipping it does not opt out of later chapters', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.skipTutorial();

      gs.number = gs.prestigeRequirement;
      gs.click();

      expect(gs.tutorialStep, TutorialStep.prestigeReady);
    });
  });

  group('chapter 2 · prestige', () {
    test('starts when the requirement is reached and ends on the prestige',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);

      gs.number = gs.prestigeRequirement;
      gs.click();
      expect(gs.tutorialStep, TutorialStep.prestigeReady);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.navPrestige);
      gs.onMainTabChanged(TutorialTab.prestige);
      expect(gs.tutorialStep, TutorialStep.learnPrestigeDetails);
      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.prestigeMultiplierHint);
      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.prestigeGainHint);
      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.doPrestige);

      await gs.prestige();
      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.hasSeenTutorialBeat(TutorialStep.prestigeReady), isTrue);

      // ...and the artifacts chapter follows once the reveal is over.
      gs.setPrestigeAnimating(false);
      expect(gs.tutorialStep, TutorialStep.artifactsIntro);
    });

    test('skips "open PRESTIGE" when the player is already there', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.onMainTabChanged(TutorialTab.prestige);

      gs.number = gs.prestigeRequirement;
      gs.click();
      gs.onTutorialTapToContinue();

      // The nav bar ignores a tap on the current tab, so waiting for one
      // would strand the player.
      expect(gs.tutorialStep, TutorialStep.learnPrestigeDetails);
    });

    test('stands down if the balance drops back under the requirement',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.number = gs.prestigeRequirement;
      gs.click();
      expect(gs.tutorialStep, TutorialStep.prestigeReady);

      gs.number = BigInt.zero;
      gs.click();
      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.hasSeenTutorialBeat(TutorialStep.prestigeReady), isFalse);

      gs.number = gs.prestigeRequirement;
      gs.click();
      expect(gs.tutorialStep, TutorialStep.prestigeReady);
    });
  });

  group('upgrade lessons', () {
    Future<void> revealDelay() => Future<void>.delayed(
        GameState.lessonRevealDelay + const Duration(milliseconds: 100));

    test('Probability Strike: buy it, land a strike, then the explanation',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.onMainTabChanged(TutorialTab.generators);

      gs.number = BigInt.from(25000);
      gs.click();
      expect(gs.tutorialStep, TutorialStep.probabilityStrikeOpen);

      gs.onMainTabChanged(TutorialTab.upgrades);
      expect(gs.tutorialStep, TutorialStep.probabilityStrikeBuy);
      expect(gs.selectedUpgradeCategory, GameState.clickCategory);

      gs.buyUpgrade(GameState.probabilityStrikeId);
      expect(gs.tutorialStep, TutorialStep.probabilityStrikeBack);

      gs.onMainTabChanged(TutorialTab.generators);
      expect(gs.tutorialStep, TutorialStep.probabilityStrikeTry);

      // Guaranteed by the lesson's third tap at the latest.
      var struck = false;
      for (var i = 0; i < GameState.lessonGuaranteedStrikeTap; i++) {
        struck = gs.click().probabilityStrikeTriggered || struck;
      }
      expect(struck, isTrue);
      // The strike stays on screen for a moment before the card covers it.
      expect(gs.tutorialStep, TutorialStep.probabilityStrikeTry);
      await revealDelay();
      expect(gs.tutorialStep, TutorialStep.tipProbabilityStrike);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.done);
      expect(
          gs.hasSeenTutorialBeat(TutorialStep.tipProbabilityStrike), isTrue);
    });

    test('already on UPGRADES, the lesson goes straight to the purchase',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.onMainTabChanged(TutorialTab.upgrades);
      // Past the advisor tip, which the first UPGRADES visit shows.
      if (gs.tutorialStep == TutorialStep.tipAdvisor) {
        gs.onTutorialTapToContinue();
      }

      gs.number = BigInt.from(25000);
      gs.click();

      expect(gs.tutorialStep, TutorialStep.probabilityStrikeBuy);
    });

    test('Momentum finishes once the combo is built', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      _upgrade(gs, GameState.momentumId).level = 1;
      gs.debugSetTutorialStep(TutorialStep.momentumTry);

      for (var i = 0; i < 24; i++) {
        gs.click();
      }
      expect(gs.lessonProgress, (current: 24, target: 25));
      gs.click();
      await revealDelay();
      expect(gs.tutorialStep, TutorialStep.tipMomentum);
    });

    test('Kinetic Synergy finishes after a few taps', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      _upgrade(gs, GameState.kineticSynergyId).level = 1;
      gs.debugSetTutorialStep(TutorialStep.kineticSynergyTry);

      for (var i = 0; i < 5; i++) {
        gs.click();
      }
      await revealDelay();
      expect(gs.tutorialStep, TutorialStep.tipKineticSynergy);
    });

    test('Overclock finishes when the streak fires it', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      _upgrade(gs, GameState.overclockId).level = 1;
      gs.debugSetTutorialStep(TutorialStep.overclockTry);

      for (var i = 0; i < 49; i++) {
        gs.click();
      }
      expect(gs.isOverclockActive, isFalse);
      expect(gs.lessonProgress, (current: 49, target: 50));
      gs.click();
      expect(gs.isOverclockActive, isTrue);
      await revealDelay();
      expect(gs.tutorialStep, TutorialStep.tipOverclock);
    });

    test('Cascade Resonator: look at the rate, then the explanation',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      _upgrade(gs, GameState.cascadeResonatorId).level = 1;
      gs.debugSetTutorialStep(TutorialStep.cascadeResonatorTry);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.tipCascadeResonator);
      gs.onTutorialTapToContinue();
      expect(gs.hasSeenTutorialBeat(TutorialStep.tipCascadeResonator), isTrue);
    });

    test('Temporal Collapse finishes when it is fired', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      _upgrade(gs, GameState.temporalCollapseId).level = 1;
      gs.debugSetTutorialStep(TutorialStep.temporalCollapseTry);

      gs.activateTemporalCollapse();
      await revealDelay();
      expect(gs.tutorialStep, TutorialStep.tipTemporalCollapse);
    });

    test('prestige-gated lessons wait for their prestige', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      for (final id in [
        GameState.probabilityStrikeId,
        GameState.momentumId,
        GameState.kineticSynergyId,
        GameState.overclockId,
      ]) {
        _upgrade(gs, id).level = 1;
      }

      // One prestige in, with money for anything: only Dimensional Tap
      // (prestige 1) is taught; Cascade Resonator (5) and Temporal Collapse
      // (8) are still locked.
      gs.prestigeCount = 1;
      gs.number = BigInt.from(10).pow(30);
      gs.click();
      expect(gs.tutorialStep, TutorialStep.dimensionalTapOpen);

      gs.skipTutorial();
      gs.click();
      expect(gs.tutorialStep, TutorialStep.done);

      gs.prestigeCount = 5;
      gs.click();
      expect(gs.tutorialStep, TutorialStep.cascadeResonatorOpen);
    });

    test('SKIP ends a lesson and remembers it', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.momentumBuy);

      gs.skipTutorial();

      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.hasSeenTutorialBeat(TutorialStep.tipMomentum), isTrue);
    });

    test('stands down, unseen, when the upgrade stops being affordable',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.number = BigInt.from(25000);
      gs.click();
      expect(gs.tutorialStep, TutorialStep.probabilityStrikeOpen);

      gs.number = BigInt.from(100);
      gs.click();
      expect(gs.tutorialStep, TutorialStep.done);
      expect(
          gs.hasSeenTutorialBeat(TutorialStep.tipProbabilityStrike), isFalse);

      gs.number = BigInt.from(25000);
      gs.click();
      expect(gs.tutorialStep, TutorialStep.probabilityStrikeOpen);
    });

    test('an upgrade bought before its lesson came up is never announced',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      _upgrade(gs, GameState.probabilityStrikeId).level = 1;

      gs.number = BigInt.from(100000);
      gs.click();

      expect(gs.tutorialStep, TutorialStep.momentumOpen);
      expect(
          gs.hasSeenTutorialBeat(TutorialStep.tipProbabilityStrike), isTrue);
    });
  });

  group('tips', () {
    test('tips never interrupt chapter 1', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.watchIdle);

      gs.number = BigInt.from(1000000);
      gs.click();

      expect(specFor(gs.tutorialStep).scope, TutorialScope.main);
    });

    test('the advisor is introduced on the first visit to UPGRADES',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.skipTutorial();
      gs.number = BigInt.from(1000);
      expect(gs.recommendedUpgrade, isNotNull);

      gs.onMainTabChanged(TutorialTab.upgrades);
      expect(gs.tutorialStep, TutorialStep.tipAdvisor);
      gs.onTutorialTapToContinue();

      gs.onMainTabChanged(TutorialTab.generators);
      gs.onMainTabChanged(TutorialTab.upgrades);
      expect(gs.tutorialStep, TutorialStep.done);
    });

    test('an Epoch is announced once the network can start one', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.researchNodes.firstWhere((n) => n.id == 'neural_genesis').level = 1;
      gs.neuralNetwork.unlocked = true;
      gs.neuralNetwork.loss = 0.001;
      expect(gs.canStartEpoch, isTrue);

      gs.click();

      expect(gs.tutorialStep, TutorialStep.tipEpoch);
    });
  });

  group('the road to the Nexus', () {
    test('artifacts, then a signal, then the Nexus wakes up', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);

      await _prestigeAndReveal(gs);
      expect(gs.tutorialStep, TutorialStep.artifactsIntro);
      gs.skipTutorial();

      await _prestigeAndReveal(gs);
      expect(gs.tutorialStep, TutorialStep.nexusSignal);
      gs.onTutorialTapToContinue();
      expect(gs.hasSeenTutorialBeat(TutorialStep.nexusSignal), isTrue);

      await _prestigeAndReveal(gs);
      expect(gs.tutorialStep, TutorialStep.nexusAwakens);
      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.navPrestigeForNexus);
      gs.onMainTabChanged(TutorialTab.prestige);
      expect(gs.tutorialStep, TutorialStep.nexusStabilize);

      // The spotlight steps aside for the stabilize animation, and nothing
      // else (a tip, a pending artifact pick) takes its place meanwhile...
      gs.onNexusStabilizeStarted();
      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.isNexusStabilizing, isTrue);
      gs.number = BigInt.from(25000);
      gs.click();
      expect(gs.tutorialStep, TutorialStep.done);
      // ...and the Nexus chapter picks up when it finishes.
      gs.stabilizeNexus();
      expect(gs.isNexusStabilizing, isFalse);
      expect(gs.tutorialStep, TutorialStep.nexusIntro);
    });

    test('a tip showing when stabilizing ends gives way to the Nexus chapter',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.tipOverclock);

      gs.stabilizeNexus();

      expect(gs.tutorialStep, TutorialStep.nexusIntro);
      expect(gs.hasSeenTutorialBeat(TutorialStep.tipOverclock), isFalse);
    });

    test('the deepest tier hints at Neural Genesis, then says it is open',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      for (final node in gs.researchNodes.where((n) => n.tier < 3)) {
        node.level = node.maxLevel;
      }
      gs.prestigeCurrency = 1e9;

      gs.purchaseResearch('resonance_core');
      expect(gs.tutorialStep, TutorialStep.neuralWhisper);
      gs.onTutorialTapToContinue();

      gs.researchNodes.firstWhere((n) => n.id == 'resonance_core').level = 5;
      gs.researchNodes.firstWhere((n) => n.id == 'echo_protocol').level = 4;
      gs.purchaseResearch('echo_protocol');
      expect(gs.tutorialStep, TutorialStep.neuralGenesisReady);

      // Buying it straight away still starts the neural chapter.
      gs.purchaseResearch('neural_genesis');
      expect(gs.tutorialStep, TutorialStep.neuralUnlocked);
    });

    test('deep layers are announced at the prestige that opens them',
        () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.stabilizeNexus();
      gs.skipTutorial();
      gs.researchNodes.firstWhere((n) => n.id == 'neural_genesis').level = 1;
      gs.prestigeCount = GameState.deepLayerPrestigeGates.first - 1;

      await _prestigeAndReveal(gs);

      expect(gs.tutorialStep, TutorialStep.tipDeepLayers);
    });
  });

  group('saves', () {
    test('seen cards survive a restart', () async {
      final gs = await _game();
      gs.debugSetTutorialStep(TutorialStep.tipMomentum);
      gs.onTutorialTapToContinue();
      // Past the 350ms save debounce.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      gs.dispose();

      final reloaded = GameState();
      await reloaded.ready;
      addTearDown(reloaded.dispose);
      expect(reloaded.hasSeenTutorialBeat(TutorialStep.tipMomentum), isTrue);
      expect(reloaded.tutorialCompleted, isTrue);
    });

    test('a later chapter interrupted by an app kill resumes', () async {
      final gs = await _game({
        'tutorialCompleted': true,
        'tutorialStep': TutorialStep.nexusUpgrades.name,
        'tutorialBeatsSeen': '[]',
      });
      addTearDown(gs.dispose);
      expect(gs.tutorialStep, TutorialStep.nexusUpgrades);
    });

    test('chapter 1 resumes where it was left', () async {
      final gs = await _game({
        'tutorialCompleted': false,
        'tutorialStep': TutorialStep.watchIdle.name,
      });
      addTearDown(gs.dispose);
      expect(gs.tutorialStep, TutorialStep.watchIdle);
      expect(gs.tutorialCompleted, isFalse);
    });

    test("an old build's prestige tail counts as chapter 1 finished",
        () async {
      final gs = await _game({
        'tutorialCompleted': false,
        'tutorialStep': 'goodLuck',
        'number': '500',
      });
      addTearDown(gs.dispose);
      expect(gs.tutorialCompleted, isTrue);
      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.number, BigInt.from(500));
    });

    test('a veteran save from before the new cards skips what it is past',
        () async {
      final gs = await _game({
        'tutorialCompleted': true,
        'tutorialStep': 'done',
        'prestigeCount': 5,
        'prestigeMultiplier': '3.0',
      });
      expect(gs.prestigeCount, 5);
      addTearDown(gs.dispose);
      expect(gs.hasSeenTutorialBeat(TutorialStep.prestigeReady), isTrue);
      expect(
          gs.hasSeenTutorialBeat(TutorialStep.tipProbabilityStrike), isTrue);
      expect(gs.hasSeenTutorialBeat(TutorialStep.nexusSignal), isTrue);
      // Still ahead of them, so still to come.
      expect(gs.hasSeenTutorialBeat(TutorialStep.nexusAwakens), isFalse);
      expect(gs.hasSeenTutorialBeat(TutorialStep.tipDeepLayers), isFalse);
    });

    test('a brand-new game has seen nothing', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      for (final step in TutorialStep.values) {
        expect(gs.hasSeenTutorialBeat(step), isFalse, reason: step.name);
      }
    });
  });
}
