import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/storage_service.dart';
import 'package:number_flutter/models/neural_network.dart';
import 'package:number_flutter/models/upgrade.dart';

/// The purchase maths exactly as it was before the cost multiplier was
/// cached: `costMultiplier ^ level` rebuilt from zero by repeated product on
/// every call. The cached version must match it bit for bit.
({BigInt cost, int amount}) _referencePurchaseInfo(
  Upgrade upgrade, {
  required int buyAmount,
  required BigInt number,
  required double costFactor,
}) {
  int toBuy;
  if (buyAmount == -1) {
    toBuy = 999999;
  } else if (buyAmount == -2) {
    final nextMilestone = GameState.upgradeMilestoneThresholds
        .where((threshold) => threshold > upgrade.level)
        .firstOrNull;
    toBuy = nextMilestone == null ? 1 : nextMilestone - upgrade.level;
  } else {
    toBuy = buyAmount;
  }
  if (upgrade.maxLevel != -1) {
    final remaining = upgrade.maxLevel - upgrade.level;
    if (remaining <= 0) return (cost: BigInt.zero, amount: 0);
    if (remaining < toBuy) toBuy = remaining;
  }

  int bought = 0;
  BigInt totalCost = BigInt.zero;
  BigInt remainingNumber = number;
  double currentMultiplier = 1.0;
  for (int i = 0; i < upgrade.level; i++) {
    currentMultiplier *= upgrade.costMultiplier;
  }
  while (bought < toBuy) {
    BigInt cost = BigInt.from(
        upgrade.baseCost.toDouble() * currentMultiplier * costFactor);
    if (remainingNumber >= cost) {
      remainingNumber -= cost;
      totalCost += cost;
      bought++;
      currentMultiplier *= upgrade.costMultiplier;
    } else if (buyAmount == -1) {
      break;
    } else {
      totalCost += cost;
      bought++;
      currentMultiplier *= upgrade.costMultiplier;
      while (bought < toBuy) {
        cost = BigInt.from(
            upgrade.baseCost.toDouble() * currentMultiplier * costFactor);
        totalCost += cost;
        bought++;
        currentMultiplier *= upgrade.costMultiplier;
      }
      break;
    }
  }
  if (buyAmount == -1 && bought == 0) {
    return (
      cost: BigInt.from(
          upgrade.baseCost.toDouble() * currentMultiplier * costFactor),
      amount: 0,
    );
  }
  return (cost: totalCost, amount: buyAmount == -1 ? bought : toBuy);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameState gameState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gameState = GameState();
    await gameState.ready;
  });

  tearDown(() => gameState.dispose());

  group('memoized prestige requirement', () {
    test('matches the uncached formula across counts', () {
      for (final count in [0, 1, 2, 7, 13, 35, 200, 999, 1000, 1500]) {
        gameState.prestigeCount = count;
        expect(gameState.prestigeRequirement,
            GameState.prestigeRequirementAtCount(count),
            reason: 'count $count');
      }
    });

    test('follows the test-environment flag', () {
      gameState.prestigeCount = 3;
      final production = gameState.prestigeRequirement;
      gameState.setTestEnvironmentEnabled(true);
      final testEnv = gameState.prestigeRequirement;
      expect(testEnv, BigInt.from(10000) * BigInt.from(21).pow(3) ~/
          BigInt.from(10).pow(3));
      expect(testEnv, isNot(production));
      gameState.setTestEnvironmentEnabled(false);
      expect(gameState.prestigeRequirement, production);
    });
  });

  group('cached cost multiplier', () {
    test('purchase info matches the from-zero loop at every level and mode',
        () {
      final number = BigInt.from(10).pow(40);
      gameState.number = number;
      for (final upgrade in gameState.upgrades) {
        final cap = upgrade.maxLevel == -1 ? 320 : upgrade.maxLevel;
        // Up, then back down, then up again: exercises the incremental path
        // and the reset-from-zero path when a level goes backwards.
        final levels = [
          for (int l = 0; l <= cap; l++) l,
          for (int l = cap; l >= 0; l -= 7) l,
          for (int l = 0; l <= cap; l += 13) l,
        ];
        for (final buyAmount in [1, 10, 100, -1, -2]) {
          gameState.buyAmount = buyAmount;
          for (final level in levels) {
            upgrade.level = level;
            final expected = _referencePurchaseInfo(
              upgrade,
              buyAmount: buyAmount,
              number: number,
              costFactor: gameState.upgradeCostReductionFactor,
            );
            expect(gameState.getPurchaseInfo(upgrade), expected,
                reason: '${upgrade.id} level $level buy $buyAmount');
          }
        }
        upgrade.level = 0;
      }
    });
  });

  group('cached neural strength', () {
    test('tracks gradient, activation and branch changes', () {
      gameState.number = BigInt.from(10).pow(30);
      gameState.neuralNetwork = NeuralNetwork(
        layers: [
          NeuralLayer(
            index: 0,
            neurons: [NeuralNeuron(id: 'layer_0_neuron_0')],
          ),
        ],
        unlocked: true,
      );
      void check(String when) => expect(gameState.neuralNetworkStrength,
          gameState.neuralNetwork.computeStrength(),
          reason: when);

      check('fresh network');
      final before = gameState.neuralTopologyKey;

      expect(gameState.upgradeNeuronGradient('layer_0_neuron_0'), isTrue);
      check('after gradient upgrade');
      expect(gameState.neuralTopologyKey, isNot(before));

      expect(gameState.changeNeuronActivation('layer_0_neuron_0', 'relu'),
          isTrue);
      check('after activation change');

      expect(gameState.branchNeuron('layer_0_neuron_0'), isTrue);
      check('after branching');

      gameState.neuralNetwork = NeuralNetwork.initial();
      check('after replacing the network');
    });
  });

  group('skip-unchanged storage writes', () {
    Future<void> save(StorageService storage, {required BigInt number}) =>
        storage.saveGame(
          number: number,
          clickPower: BigInt.from(7),
          autoClickRate: 1.5,
          prestigeCurrency: 2.25,
          prestigeMultiplier: 1.2,
          prestigeCount: 1,
          upgradeLevels: const {'click_power': 3},
          highestNumber: number,
          nexusLevels: const {'opt_protocol': 1},
          tutorialCompleted: true,
          tutorialStep: 'done',
          nexusTutorialSeen: false,
          neuralTutorialSeen: false,
          artifactTutorialSeen: false,
          nexusStabilized: false,
        );

    test('round-trips, and a later change still lands', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await save(storage, number: BigInt.from(100));
      await save(storage, number: BigInt.from(100));
      await save(storage, number: BigInt.from(250));

      final loaded = await storage.loadGame();
      expect(loaded['number'], BigInt.from(250));
      expect(loaded['clickPower'], BigInt.from(7));
      expect(loaded['upgradeLevels'], {'click_power': 3});
      expect(loaded['tutorialCompleted'], isTrue);
    });

    test('rewrites everything after clearAllData', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await save(storage, number: BigInt.from(100));
      await storage.clearAllData();
      await save(storage, number: BigInt.from(100));

      final loaded = await storage.loadGame();
      expect(loaded['number'], BigInt.from(100));
      expect(loaded['clickPower'], BigInt.from(7));
    });
  });
}
