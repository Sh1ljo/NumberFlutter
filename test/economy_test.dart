import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:number_flutter/data/nexus_data.dart';
import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/models/neural_network.dart';
import 'package:number_flutter/models/research_node.dart';
import 'package:number_flutter/models/upgrade.dart';

/// Reference implementation of the shipped cost formula, so these tests assert
/// against the intended maths rather than re-reading the production code.
double _costPerEffect(Upgrade u, int level) {
  final cost = u.baseCost.toDouble() * math.pow(u.costMultiplier, level);
  return cost / (u.effectValue as double);
}

void main() {
  final upgrades = GameState.defaultUpgrades();
  final idleTiers = upgrades
      .where((u) =>
          u.effectType == GameState.idleCategory && u.effectValue is double)
      .where((u) => (u.effectValue as double) > 0)
      .toList();

  group('prestige requirement curve', () {
    test('grows geometrically instead of staying flat', () {
      // The flat-100M bug: every prestige cost the same while rewards grew.
      // Run well past prestige 35, where an earlier double-based
      // implementation silently saturated at int64 max and went flat again.
      for (var n = 0; n < GameState.maxPrestigeRequirementExponent; n++) {
        final here = GameState.prestigeRequirementAtCount(n);
        final next = GameState.prestigeRequirementAtCount(n + 1);
        expect(next, greaterThan(here),
            reason: 'requirement must strictly increase at prestige $n');
      }
    });

    test('ratio between successive requirements is exactly 2.1', () {
      for (final n in [0, 1, 10, 37, 100, 500]) {
        final here = GameState.prestigeRequirementAtCount(n);
        final next = GameState.prestigeRequirementAtCount(n + 1);
        // Compared as a rational rather than round-tripping a 300-digit
        // BigInt through a double. Each level floors once, so next * 10 and
        // here * 21 agree only to within the accumulated truncation, which
        // is bounded by the numerator (21).
        final drift = next * BigInt.from(10) - here * BigInt.from(21);
        expect(drift.abs(), lessThanOrEqualTo(BigInt.from(21)),
            reason: 'growth drifted at prestige $n by $drift');
      }
    });

    test('clamps at the documented exponent ceiling', () {
      final atCeiling = GameState.prestigeRequirementAtCount(
          GameState.maxPrestigeRequirementExponent);
      for (final n in [
        GameState.maxPrestigeRequirementExponent + 1,
        999999,
      ]) {
        expect(GameState.prestigeRequirementAtCount(n), atCeiling);
      }
    });

    test('first prestige is 100M', () {
      expect(GameState.prestigeRequirementAtCount(0), BigInt.from(100000000));
    });

    test('requirement outgrows reward, so the loop cannot run backwards', () {
      expect(GameState.prestigeRequirementGrowth,
          greaterThan(GameState.prestigeRewardGrowth));
    });

    test('never overflows to a non-finite value at extreme counts', () {
      for (final n in [300, 400, 1000, 100000]) {
        expect(GameState.prestigeRequirementAtCount(n), greaterThan(BigInt.zero));
      }
    });

    test('negative counts are clamped rather than throwing', () {
      expect(GameState.prestigeRequirementAtCount(-5),
          GameState.prestigeRequirementAtCount(0));
      expect(GameState.prestigeRewardAtCount(-5),
          GameState.prestigeRewardAtCount(0));
    });
  });

  group('prestige reward and multiplier', () {
    test('reward grows 1.35x per prestige from a base of 3', () {
      expect(GameState.prestigeRewardAtCount(0), closeTo(3.0, 1e-9));
      expect(GameState.prestigeRewardAtCount(1), closeTo(3.0 * 1.35, 1e-9));
    });

    test('multiplier is strictly increasing', () {
      var prev = GameState.multiplierAfterPrestigeCount(0);
      expect(prev, closeTo(1.0, 1e-9));
      for (var n = 1; n <= 50; n++) {
        final m = GameState.multiplierAfterPrestigeCount(n);
        expect(m, greaterThan(prev));
        prev = m;
      }
    });

    test('PP per hour is non-increasing over the late arc', () {
      // Run time scales roughly as requirement / (rate * multiplier), so
      // reward x multiplier / requirement is a proxy for PP per hour. With a
      // 2.1 requirement growth against a 1.35 reward growth and a quadratic
      // multiplier, that proxy has to fall as runs stack up.
      //
      // Evaluated in log space: past prestige ~30 the requirement exceeds a
      // double's 53-bit mantissa, so a direct division would compare
      // quantisation noise rather than the curve.
      double logRatio(int n) =>
          math.log(GameState.prestigeRewardAtCount(n)) +
          math.log(GameState.multiplierAfterPrestigeCount(n)) -
          (math.log(GameState.prestigeBaseRequirement.toDouble()) +
              n * math.log(GameState.prestigeRequirementGrowth));

      for (var n = 10; n < 200; n++) {
        expect(logRatio(n + 1), lessThan(logRatio(n)),
            reason: 'PP/hour proxy must decline at prestige $n');
      }
    });
  });

  group('idle tier ladder', () {
    test('covers all seven tiers', () {
      expect(idleTiers.length, 7);
    });

    test('all tiers share one growth rate', () {
      final rates = idleTiers.map((u) => u.costMultiplier).toSet();
      expect(rates.length, 1,
          reason: 'differing growth rates let one tier dominate forever');
    });

    test('no tier is a trap pick at every level', () {
      // The old bug: Auto-Clicker (r=1.15) stayed the cheapest source of idle
      // income forever because every other tier grew faster.
      for (final tier in idleTiers) {
        final alwaysBeaten = List.generate(60, (l) => l).every((level) {
          final mine = _costPerEffect(tier, level);
          return idleTiers.any((other) =>
              other.id != tier.id && _costPerEffect(other, level) < mine * 0.5);
        });
        expect(alwaysBeaten, isFalse, reason: '${tier.id} is a trap pick');
      }
    });

    test('cost per effect is uniform across tiers at equal level', () {
      // Uniform ratio + uniform growth means the optimal play is "buy the
      // lowest-level tier you can afford", which walks the ladder naturally.
      for (final level in [0, 5, 20, 50]) {
        final ratios = idleTiers.map((u) => _costPerEffect(u, level)).toList();
        final lo = ratios.reduce(math.min);
        final hi = ratios.reduce(math.max);
        expect(hi / lo, lessThan(1.5),
            reason: 'tiers diverge at level $level: $ratios');
      }
    });

    test('absolute entry price rises with tier effect', () {
      final sorted = [...idleTiers]..sort((a, b) =>
          (a.effectValue as double).compareTo(b.effectValue as double));
      for (var i = 1; i < sorted.length; i++) {
        expect(sorted[i].baseCost, greaterThan(sorted[i - 1].baseCost),
            reason: 'tier gating comes from absolute cost, not efficiency');
      }
    });
  });

  group('click branch is competitive', () {
    test('a fresh save clicks for exactly 1', () {
      expect(GameState.productionBaseClickPower, 1);
    });

    test('click power upgrade delivers its full advertised effect', () {
      final clickPower =
          upgrades.firstWhere((u) => u.id == GameState.clickPowerId);
      // The old bug divided this by 50 in production, making it +1/level.
      expect(clickPower.effectValue, BigInt.from(50));
    });

    test('click power grows slower than it used to, so it stays buyable', () {
      final clickPower =
          upgrades.firstWhere((u) => u.id == GameState.clickPowerId);
      expect(clickPower.costMultiplier, lessThan(1.45));
    });
  });

  group('nexus research costs', () {
    double costTo(List<ResearchNode> nodes, String id, int levels) {
      final node = nodes.firstWhere((n) => n.id == id);
      final restore = node.level;
      var sum = 0.0;
      for (var l = 0; l < levels; l++) {
        node.level = l;
        sum += node.costForNextLevel;
      }
      node.level = restore;
      return sum;
    }

    test('scaling nodes grow geometrically', () {
      final nodes = NexusData.allNodes();
      final scaling = nodes.where((n) => n.costsScale).toList();
      expect(scaling, isNotEmpty);
      for (final node in scaling) {
        node.level = 0;
        final first = node.costForNextLevel;
        node.level = 1;
        final second = node.costForNextLevel;
        expect(second / first, closeTo(ResearchNode.costGrowth, 1e-9),
            reason: '${node.id} should scale by costGrowth, not linearly');
      }
    });

    test('maxing the full tree costs well over the old linear total', () {
      // The old linear total was 1,469 PP, which the player bought out within
      // a few prestiges of unlocking, leaving PP with no sink at all.
      final nodes = NexusData.allNodes();
      var total = 0.0;
      for (final node in nodes) {
        total += costTo(nodes, node.id, node.maxLevel);
      }
      expect(total, greaterThan(2000));
    });

    test('neural genesis stays reachable in roughly 15 prestiges', () {
      final nodes = NexusData.allNodes();
      final minPath = costTo(nodes, 'opt_protocol', 5) +
          costTo(nodes, 'idle_foundation', 5) +
          costTo(nodes, 'enhanced_extraction', 3) +
          costTo(nodes, 'resonance_core', 5) +
          costTo(nodes, 'echo_protocol', 5) +
          costTo(nodes, 'neural_genesis', 1);

      var cumulativePp = 0.0;
      var prestiges = 0;
      while (cumulativePp < minPath && prestiges < 100) {
        cumulativePp += GameState.prestigeRewardAtCount(prestiges);
        prestiges++;
      }
      expect(prestiges, inInclusiveRange(12, 18),
          reason: 'min path is $minPath PP, reached after $prestiges prestiges');
    });
  });

  group('neural network', () {
    test('gradient cap is shared by the cost ladder and the UI', () {
      final neuron = NeuralNeuron(id: 'layer_0_neuron_0');
      expect(NeuralNeuron.maxGradientLevel, 9);
      neuron.gradientLevel = NeuralNeuron.maxGradientLevel;
      expect(neuron.isGradientMaxed, isTrue);
      expect(neuron.gradientUpgradeCost, BigInt.zero);
    });

    test('a maxed network trains in days, not weeks', () {
      // Strength of a fully maxed 22-neuron pyramid is ~5.85.
      const strength = 5.85;
      final days =
          math.log(1000) / (GameState.neuralDecayK * strength) / 86400;
      expect(days, lessThan(5.0),
          reason: '$days days of pure waiting is a timer, not an end game');
      expect(days, greaterThan(1.0),
          reason: 'should still be an end-game grind');
    });
  });
}
