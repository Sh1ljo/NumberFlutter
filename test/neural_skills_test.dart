import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';
import 'package:number_flutter/models/neural_network.dart';
import 'package:number_flutter/models/neural_skill.dart';

Future<GameState> _neuralGame({int prestigeCount = 0}) async {
  SharedPreferences.setMockInitialValues({});
  final gs = GameState();
  await gs.ready;
  gs.debugSetTutorialStep(TutorialStep.done);
  gs.prestigeCount = prestigeCount;
  gs.researchNodes.firstWhere((n) => n.id == 'neural_genesis').level = 1;
  gs.neuralNetwork = NeuralNetwork(
    layers: [
      NeuralLayer(index: 0, neurons: [NeuralNeuron(id: 'layer_0_neuron_0')]),
    ],
    unlocked: true,
  );
  gs.number = BigInt.from(10).pow(40);
  return gs;
}

/// Branches until [layers] layers exist (or nothing more can branch).
void _growTo(GameState gs, int layers) {
  for (var guard = 0; guard < 100; guard++) {
    if (gs.neuralNetwork.layers.length >= layers) return;
    final candidates = [
      for (final l in gs.neuralNetwork.layers)
        for (final n in l.neurons)
          if (gs.canBranchNeuron(n.id)) n.id,
    ];
    if (candidates.isEmpty) return;
    for (final id in candidates) {
      expect(gs.branchNeuron(id), isTrue);
      if (gs.neuralNetwork.layers.length >= layers) return;
    }
  }
}

Future<GameState> _skillsGame({int prestigeCount = 0}) async {
  final gs = await _neuralGame(prestigeCount: prestigeCount);
  _growTo(gs, NeuralNetwork.pyramidLayerCount);
  expect(gs.skillsUnlocked, isTrue);
  // The Skills chapter has its own tests; keep it out of the way here.
  gs.debugSetTutorialStep(TutorialStep.done);
  return gs;
}

void _setAllActivations(NeuralNetwork nn, String fn) {
  for (final l in nn.layers) {
    for (final n in l.neurons) {
      n.activationFn = fn;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mastery curve', () {
    test('is half-way at c·t = 1 and never passes the cap', () {
      expect(NeuralSkills.train(0, 0.01, 100), closeTo(0.5, 1e-12));
      expect(NeuralSkills.train(0, 1, 1e12), NeuralSkills.maxMastery);
    });

    test('training in slices equals training in one go', () {
      var sliced = 0.0;
      for (var i = 0; i < 1000; i++) {
        sliced = NeuralSkills.train(sliced, 3e-4, 0.1 * 36);
      }
      final once = NeuralSkills.train(0, 3e-4, 3600);
      expect(sliced, closeTo(once, 1e-9));
    });

    test('a fresh pyramid at half fit hits the pacing targets', () {
      // Strength of a completed pyramid with a few gradient levels, and
      // 50% fit: the design point for 40m / 6h / ~3d.
      const strength = 4.5;
      final rate =
          NeuralSkills.trainingK * strength * NeuralSkills.fitMultiplier(0.5);
      double secondsTo(double m) => (1 / (1 - m) - 1) / rate;
      expect(secondsTo(0.5) / 60, inInclusiveRange(30, 50));
      expect(secondsTo(0.9) / 3600, inInclusiveRange(5, 8));
      expect(secondsTo(0.99) / 86400, inInclusiveRange(2, 4));
    });

    test('fit spans 0.5× to 2×', () {
      expect(NeuralSkills.fitMultiplier(0), 0.5);
      expect(NeuralSkills.fitMultiplier(1), 2.0);
    });
  });

  group('unlock', () {
    test('Skills stay locked until all 7 pyramid layers exist', () async {
      final gs = await _neuralGame();
      addTearDown(gs.dispose);
      _growTo(gs, 6);
      expect(gs.pyramidLayersBuilt, 6);
      expect(gs.skillsUnlocked, isFalse);
      expect(gs.isSkillAvailable(SkillId.tapping), isFalse);

      _growTo(gs, 7);
      expect(gs.skillsUnlocked, isTrue);
      expect(gs.isSkillAvailable(SkillId.tapping), isTrue);
      expect(gs.isSkillAvailable(SkillId.shopping), isTrue);
    });

    test('Spark Hunting needs a deep layer, Prestige Planning an Epoch',
        () async {
      final gs = await _skillsGame(prestigeCount: 18);
      addTearDown(gs.dispose);
      expect(gs.isSkillAvailable(SkillId.sparkHunting), isFalse);
      expect(gs.isSkillAvailable(SkillId.prestigePlanning), isFalse);

      _growTo(gs, 8);
      expect(gs.isSkillAvailable(SkillId.sparkHunting), isTrue);

      gs.neuralNetwork.loss = 0.001;
      expect(gs.startEpoch(), isTrue);
      expect(gs.isSkillAvailable(SkillId.prestigePlanning), isTrue);
    });

    test('a new Skill badges NEURAL until the SKILLS tab is opened', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      expect(gs.hasUnseenSkills, isTrue);
      gs.setNeuralSubTabIndex(NeuralSubTab.skills);
      expect(gs.hasUnseenSkills, isFalse);
    });
  });

  group('training', () {
    test('only the training Skill gains Mastery', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.trainSkill(SkillId.tapping);
      gs.debugTickSkills(100);
      expect(gs.skillMastery(SkillId.tapping), greaterThan(0));
      expect(gs.skillMastery(SkillId.shopping), 0);
    });

    test('a better fit trains faster', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      _setAllActivations(gs.neuralNetwork, 'linear');
      final slow = gs.skillTrainingRate(SkillId.tapping);
      _setAllActivations(gs.neuralNetwork, 'relu');
      final fast = gs.skillTrainingRate(SkillId.tapping);
      expect(gs.skillFitFor(SkillId.tapping), 1.0);
      expect(fast, greaterThan(slow * 3.9));
    });

    test('Mastery survives prestige and a save round trip', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.neuralNetwork.skills.mastery[SkillId.tapping] = 0.4;
      gs.trainSkill(SkillId.tapping);
      gs.setSkillHelper(SkillId.tapping, true);
      gs.setShoppingSpendLimit(0.25);

      gs.number = gs.prestigeRequirement;
      await gs.prestige();
      expect(gs.skillMastery(SkillId.tapping), 0.4);

      final back =
          NeuralNetwork.fromJsonString(gs.neuralNetwork.toJsonString());
      expect(back.skills.masteryOf(SkillId.tapping), 0.4);
      expect(back.skills.training, SkillId.tapping);
      expect(back.skills.isHelperOn(SkillId.tapping), isTrue);
      expect(back.skills.spendLimit, 0.25);
    });

    test('a v5 save without skills loads with none', () {
      final nn = NeuralNetwork.fromJson({
        'version': 5,
        'layers': <Object>[],
        'unlocked': true,
        'epochs': 2,
      });
      expect(nn.skills.mastery, isEmpty);
      expect(nn.skills.training, isNull);
      expect(nn.skills.spendLimit, NeuralSkills.defaultSpendLimit);
    });

    test('junk skill data is ignored rather than crashing the load', () {
      final skills = SkillsState.fromJson({
        'mastery': {'tapping': 7.0, 'nope': 0.5, 'shopping': 'x'},
        'helpersOn': ['tapping', 'bogus', 3],
        'training': 'bogus',
        'spendLimit': 0.33,
      });
      expect(skills.masteryOf(SkillId.tapping), NeuralSkills.maxMastery);
      expect(skills.masteryOf(SkillId.shopping), 0);
      expect(skills.helpersOn, {SkillId.tapping});
      expect(skills.training, isNull);
      expect(skills.spendLimit, NeuralSkills.defaultSpendLimit);
    });

    test('time away trains the active Skill and is reported', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      var now = DateTime(2026, 1, 1, 12);
      gs.clock = () => now;
      gs.trainSkill(SkillId.shopping);
      final rate = gs.skillTrainingRate(SkillId.shopping);

      gs.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(hours: 1));
      gs.didChangeAppLifecycleState(AppLifecycleState.resumed);

      final expected = NeuralSkills.train(0, rate, 3600);
      expect(gs.skillMastery(SkillId.shopping), closeTo(expected, 1e-9));
      expect(gs.offlineMasteryGain, closeTo(expected, 1e-9));
      expect(gs.offlineMasterySkill, SkillId.shopping);
    });
  });

  group('helpers', () {
    test('Auto-Tap adds to the number without counting as player taps',
        () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.number = BigInt.zero;
      final clicks = gs.lifetimeClicks;
      gs.setSkillHelper(SkillId.tapping, true);
      expect(gs.autoTapRate, closeTo(1.0, 1e-9));

      gs.debugTickSkills(20); // 2 seconds at 1 tap/s
      expect(gs.number, greaterThan(BigInt.zero));
      expect(gs.lifetimeClicks, clicks);
    });

    test('Auto-Tap rate follows Mastery', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.neuralNetwork.skills.mastery[SkillId.tapping] = 1.0;
      gs.setSkillHelper(SkillId.tapping, true);
      expect(gs.autoTapRate, closeTo(10.0, 1e-9));
      gs.setSkillHelper(SkillId.tapping, false);
      expect(gs.autoTapRate, 0);
    });

    test('Auto-Buy buys the advisor pick within the spending limit', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.number = BigInt.from(1000000);
      final rec = gs.recommendedUpgrade;
      expect(rec, isNotNull);
      final levelBefore =
          gs.upgrades.firstWhere((u) => u.id == rec!.upgradeId).level;

      gs.setSkillHelper(SkillId.shopping, true);
      gs.debugTickSkills(301); // the first purchase comes after 30s

      final level = gs.upgrades.firstWhere((u) => u.id == rec!.upgradeId).level;
      expect(level, greaterThan(levelBefore));
      // Half the balance at most (default limit).
      expect(gs.number, greaterThanOrEqualTo(BigInt.from(500000)));
    });

    test('Auto-Buy spends nothing when even one level is over the limit',
        () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.number = BigInt.from(1);
      gs.setSkillHelper(SkillId.shopping, true);
      gs.debugTickSkills(301);
      expect(gs.number, BigInt.from(1));
    });

    test('Auto-Prestige needs confirmation and 50% Mastery', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.neuralNetwork.epochs = 1;
      const id = SkillId.prestigePlanning;
      expect(gs.isSkillAvailable(id), isTrue);

      gs.setSkillHelper(id, true);
      expect(gs.skills.isHelperOn(id), isFalse,
          reason: 'cannot be switched on before the warning is confirmed');

      gs.confirmAutoPrestige();
      gs.setSkillHelper(id, true);
      expect(gs.skills.isHelperOn(id), isTrue);
      expect(gs.isHelperActive(id), isFalse, reason: 'Mastery is 0%');

      gs.neuralNetwork.skills.mastery[id] = 0.5;
      expect(gs.isHelperActive(id), isTrue);
    });

    test('Auto-Prestige prestiges once the reaction time has passed', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.neuralNetwork.epochs = 1;
      const id = SkillId.prestigePlanning;
      gs.neuralNetwork.skills.mastery[id] = 0.99; // reacts within ~0.6s
      gs.confirmAutoPrestige();
      gs.setSkillHelper(id, true);
      gs.number = gs.prestigeRequirement;
      final before = gs.prestigeCount;

      gs.debugTickSkills(10);
      await Future<void>.delayed(Duration.zero);

      expect(gs.prestigeCount, before + 1);
      expect(gs.helperNotice, contains('AUTO-PRESTIGE'));
    });

    test('helpers stand aside while a tutorial card is up', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.number = BigInt.from(1000000);
      gs.setSkillHelper(SkillId.shopping, true);
      gs.debugSetTutorialStep(TutorialStep.tipSkillExpert);
      final before = gs.number;
      gs.debugTickSkills(301);
      expect(gs.number, before);
    });

    test('Spark Hunting makes sparks come more often', () async {
      final gs = await _skillsGame(prestigeCount: 18);
      addTearDown(gs.dispose);
      _growTo(gs, 8);
      final base = gs.neuralSparkSpawnDelayFactor;
      gs.neuralNetwork.skills.mastery[SkillId.sparkHunting] = 1.0;
      gs.setSkillHelper(SkillId.sparkHunting, true);
      expect(gs.sparkAutoCatchChance, 1.0);
      expect(gs.neuralSparkSpawnDelayFactor, closeTo(base / 1.3, 1e-9));
    });
  });

  group('tutorial', () {
    test('five pyramid layers bring the teaser', () async {
      final gs = await _neuralGame();
      addTearDown(gs.dispose);
      _growTo(gs, 5);
      gs.number = BigInt.zero; // no prestige or upgrade cards competing
      gs.click();
      expect(gs.tutorialStep, TutorialStep.skillsWhisper);
    });

    test('the Skills chapter walks from unlock to a working helper', () async {
      final gs = await _neuralGame();
      addTearDown(gs.dispose);
      _growTo(gs, NeuralNetwork.pyramidLayerCount);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.number = BigInt.zero; // no prestige or upgrade cards competing
      gs.click();
      expect(gs.tutorialStep, TutorialStep.skillsUnlocked);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.navNeuralForSkills);

      gs.onMainTabChanged(TutorialTab.neural);
      expect(gs.tutorialStep, TutorialStep.skillsOpenTab);

      gs.setNeuralSubTabIndex(NeuralSubTab.skills);
      expect(gs.tutorialStep, TutorialStep.skillsHowItLearns);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.skillsTrainTapping);

      gs.trainSkill(SkillId.tapping);
      expect(gs.tutorialStep, TutorialStep.skillsMastery);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.skillsFit);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.skillsHelper);

      gs.setSkillHelper(SkillId.tapping, true);
      expect(gs.tutorialStep, TutorialStep.skillsGoal);

      gs.onTutorialTapToContinue();
      expect(gs.tutorialStep, TutorialStep.done);
      expect(gs.hasSeenTutorialBeat(TutorialStep.skillsUnlocked), isTrue);

      // Seen once, never again.
      gs.click();
      expect(gs.tutorialStep, TutorialStep.done);
    });

    test('steps already done by the player are passed over', () async {
      final gs = await _skillsGame();
      addTearDown(gs.dispose);
      gs.setNeuralSubTabIndex(NeuralSubTab.skills);
      gs.trainSkill(SkillId.tapping);
      gs.onMainTabChanged(TutorialTab.neural);
      gs.debugSetTutorialStep(TutorialStep.skillsUnlocked);

      gs.onTutorialTapToContinue();
      // Already on NEURAL › SKILLS: straight to the explanation.
      expect(gs.tutorialStep, TutorialStep.skillsHowItLearns);
      gs.onTutorialTapToContinue();
      // Tapping is already training: straight to Mastery.
      expect(gs.tutorialStep, TutorialStep.skillsMastery);
    });

    test('SKIP ends the chapter for good', () async {
      final gs = await _neuralGame();
      addTearDown(gs.dispose);
      _growTo(gs, NeuralNetwork.pyramidLayerCount);
      gs.debugSetTutorialStep(TutorialStep.done);
      gs.number = BigInt.zero; // no prestige or upgrade cards competing
      gs.click();
      expect(gs.tutorialStep, TutorialStep.skillsUnlocked);
      gs.onTutorialTapToContinue();
      gs.skipTutorial();
      expect(gs.tutorialStep, TutorialStep.done);
      gs.click();
      expect(gs.tutorialStep, TutorialStep.done);
    });

    test('the chapter belongs to its own scope', () {
      final chapter = chapterFor(TutorialStep.skillsFit)!;
      expect(chapter.number, 6);
      for (final step in chapter.steps) {
        expect(specFor(step).scope, TutorialScope.skills);
      }
    });
  });
}
