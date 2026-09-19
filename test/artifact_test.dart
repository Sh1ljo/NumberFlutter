import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/data/artifact_data.dart';
import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/models/artifact.dart';

Future<GameState> _game() async {
  SharedPreferences.setMockInitialValues({});
  final gs = GameState();
  await gs.ready;
  return gs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArtifactState', () {
    test('empower cost is geometric at exactly 1.45 with no cap', () {
      expect(ArtifactState.empowerCost(1), ArtifactState.empowerBaseCost);
      for (var level = 1; level < 200; level++) {
        expect(
          ArtifactState.empowerCost(level + 1) /
              ArtifactState.empowerCost(level),
          closeTo(1.45, 1e-9),
        );
      }
      expect(ArtifactState.empowerCost(200).isFinite, isTrue);
    });

    test('milestones reached are backfilled for an existing save', () {
      final state = ArtifactState(seed: 1);
      expect(state.pendingChoices(0), 0);
      expect(state.pendingChoices(1), 1);
      expect(state.pendingChoices(12), 3);
      expect(state.pendingChoices(999), ArtifactState.milestones.length);
    });

    test('offers are deterministic for a seed and never repeat owned', () {
      final a = ArtifactState(seed: 42);
      final b = ArtifactState(seed: 42);
      final offerA = a.ensureOffer(12, Artifacts.allIds)!;
      final offerB = b.ensureOffer(12, Artifacts.allIds)!;
      expect(offerA, offerB);
      expect(offerA.length, ArtifactState.offerSize);
      expect(offerA.toSet().length, ArtifactState.offerSize);

      for (var i = 0; i < 3; i++) {
        final offer = a.ensureOffer(12, Artifacts.allIds)!;
        for (final id in offer) {
          expect(a.levelOf(id), 0, reason: '$id is already owned');
        }
        expect(a.choose(offer.first), isTrue);
      }
      expect(a.ownedCount, 3);
      expect(a.ensureOffer(12, Artifacts.allIds), isNull);
    });

    test('the offer is fixed until claimed, so restarts cannot reroll', () {
      final a = ArtifactState(seed: 7);
      final first = List<String>.from(a.ensureOffer(1, Artifacts.allIds)!);
      final reloaded = ArtifactState.fromJson(a.toJson());
      expect(reloaded.ensureOffer(1, Artifacts.allIds), first);
    });

    test('an artifact not on offer cannot be chosen', () {
      final a = ArtifactState(seed: 3);
      final offer = a.ensureOffer(1, Artifacts.allIds)!;
      final notOffered =
          Artifacts.allIds.firstWhere((id) => !offer.contains(id));
      expect(a.choose(notOffered), isFalse);
      expect(a.claimedMilestones, 0);
    });
  });

  group('effect curves', () {
    test('level 0 is always neutral', () {
      expect(Artifacts.chronoCapBonusHours(0), 0);
      expect(Artifacts.chronoOfflineMultiplier(0), 1.0);
      expect(Artifacts.echoShare(0), 0);
      expect(Artifacts.titheBonusPerArtifact(0), 0);
      expect(Artifacts.genesisStartLevel(0), 0);
      expect(Artifacts.momentumFloor(0), 0);
      expect(Artifacts.strikeChance(0), Artifacts.baseStrikeChance);
      expect(Artifacts.strikeChainChance(0), 0);
      expect(Artifacts.overclockCoreInterval(0), isNull);
      expect(Artifacts.synapseCostFactor(0), 1.0);
      expect(Artifacts.synapsePreferredBonus(0), 1.10);
      expect(Artifacts.compoundShare(0), 0);
      expect(Artifacts.tempoCooldownFactor(0), 1.0);
      expect(Artifacts.tempoDurationFactor(0), 1.0);
      expect(Artifacts.prismPerMaxedNode(0), 0);
      expect(Artifacts.milestoneBase(0), 2.0);
    });

    test('capped effects hold their caps at level 200', () {
      const l = 200;
      expect(Artifacts.genesisStartLevel(l), 100);
      expect(Artifacts.momentumFloor(l), 0.9);
      expect(Artifacts.strikeChance(l), 0.15);
      expect(Artifacts.overclockCoreInterval(l), 300);
      expect(Artifacts.synapseCostFactor(l), 0.4);
      expect(Artifacts.compoundShare(l), 0.03);
      expect(Artifacts.tempoCooldownFactor(l), closeTo(0.3, 1e-9));
      expect(Artifacts.milestoneBase(l), 2.6);
    });

    test('every artifact describes itself at every level', () {
      for (final def in Artifacts.all) {
        for (final level in [1, 2, 10, 200]) {
          expect(def.describe(level), isNotEmpty, reason: def.id);
        }
      }
      expect(Artifacts.allIds.toSet().length, Artifacts.all.length);
    });
  });

  group('in game', () {
    test('empowering spends PP and raises the level', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.artifactState.levels[Artifacts.chronoLens] = 1;
      gs.prestigeCurrency = 10;
      expect(gs.empowerArtifact(Artifacts.chronoLens), isFalse);
      gs.prestigeCurrency = 100;
      expect(gs.empowerArtifact(Artifacts.chronoLens), isTrue);
      expect(gs.prestigeCurrency,
          closeTo(100 - ArtifactState.empowerBaseCost, 1e-9));
      expect(gs.artifactState.levelOf(Artifacts.chronoLens), 2);
      expect(gs.empowerArtifact(Artifacts.echoChamber), isFalse,
          reason: 'cannot empower an artifact you do not own');
    });

    test('Tithe Engine scales PP with artifacts owned', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.number = gs.prestigeRequirement;
      final base = gs.calculatePrestigePoints(gs.number);
      gs.artifactState.levels
        ..[Artifacts.titheEngine] = 1
        ..[Artifacts.chronoLens] = 1;
      expect(gs.calculatePrestigePoints(gs.number), closeTo(base * 1.06, 1e-9));
    });

    test('Genesis Kit restarts the first idle tiers after prestige', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.artifactState.levels[Artifacts.genesisKit] = 1;
      gs.number = gs.prestigeRequirement;
      await gs.prestige();
      for (final id in Artifacts.genesisKitTiers) {
        expect(gs.upgrades.firstWhere((u) => u.id == id).level, 10);
      }
      expect(gs.totalIdleRate, greaterThan(0));
    });

    test('Milestone Compass strengthens upgrade milestones', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      expect(gs.upgradeMilestoneMultiplierForLevel(1000), 64);
      gs.artifactState.levels[Artifacts.milestoneCompass] = 1;
      expect(gs.upgradeMilestoneMultiplierForLevel(1000),
          math.pow(2.2, 6).round());
    });

    test('prestiging at a milestone makes an offer available', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      expect(gs.pendingArtifactChoices, 0);
      gs.number = gs.prestigeRequirement;
      await gs.prestige();
      expect(gs.pendingArtifactChoices, 1);
      final offer = gs.currentArtifactOffer!;
      expect(gs.chooseArtifact(offer.first), isTrue);
      expect(gs.pendingArtifactChoices, 0);
      expect(gs.unlockedAchievements, contains('artifact_first'));
    });

    test('offline income is capped; Chrono Lens extends the cap', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      var now = DateTime(2026, 1, 1);
      gs.clock = () => now;
      gs.number = BigInt.from(1000);
      gs.setSelectedUpgradeCategory(GameState.idleCategory);
      gs.buyUpgrade(GameState.autoClickerId);

      BigInt awayFor(Duration d) {
        gs.didChangeAppLifecycleState(AppLifecycleState.paused);
        final before = gs.number;
        now = now.add(d);
        gs.didChangeAppLifecycleState(AppLifecycleState.resumed);
        return gs.number - before;
      }

      final capped = awayFor(const Duration(hours: 48));
      final capSeconds = (GameState.baseOfflineCapHours * 3600).floor();
      expect(
        capped,
        BigInt.from(
            (gs.totalIdleRate * capSeconds * gs.offlineGainMultiplier).floor()),
      );
      expect(gs.unlockedAchievements, contains('long_absence'));

      gs.artifactState.levels[Artifacts.chronoLens] = 1;
      expect(gs.offlineCapHours, GameState.baseOfflineCapHours + 4);
      expect(awayFor(const Duration(hours: 48)), greaterThan(capped));
    });

    test('Temporal Collapse doubling never survives a prestige', () async {
      final gs = await _game();
      addTearDown(gs.dispose);
      gs.prestigeCount = 8;
      gs.prestigeMultiplier = 3.0;
      gs.upgrades
          .firstWhere((u) => u.id == GameState.temporalCollapseId)
          .level = 1;
      gs.number = BigInt.from(1000);
      gs.setSelectedUpgradeCategory(GameState.idleCategory);
      gs.buyUpgrade(GameState.autoClickerId);
      // Normalise out the achievement bonus: activating unlocks one.
      final idleBefore = gs.totalIdleRate / gs.achievementBonus;

      gs.activateTemporalCollapse();
      expect(gs.isTemporalCollapseActive, isTrue);
      expect(gs.prestigeMultiplier, 3.0);
      expect(gs.totalIdleRate / gs.achievementBonus,
          closeTo(idleBefore * 2, idleBefore * 1e-9));

      final delta = gs.nextPrestigeDelta;
      gs.number = gs.prestigeRequirement;
      await gs.prestige();
      expect(gs.prestigeMultiplier, closeTo(3.0 + delta, 1e-9));
      expect(gs.isTemporalCollapseActive, isFalse);
    });
  });
}
