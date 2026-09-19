import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/data/achievement_data.dart';
import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/sync_service.dart';
import 'package:number_flutter/models/player_progress.dart';

PlayerProgress _progress({
  required List<String> achievements,
  required int clicks,
  required DateTime updatedAt,
}) =>
    PlayerProgress(
      userId: 'u',
      number: BigInt.one,
      clickPower: BigInt.one,
      autoClickRate: 0,
      prestigeCurrency: 0,
      prestigeMultiplier: 1,
      prestigeCount: 0,
      upgradeLevels: const {},
      highestNumber: BigInt.one,
      progressScore: 0,
      achievements: achievements,
      lifetimeClicks: clicks,
      updatedAt: updatedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ids are unique and every achievement has copy', () {
    final ids = Achievements.all.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final a in Achievements.all) {
      expect(a.title, isNotEmpty, reason: a.id);
      expect(a.description, isNotEmpty, reason: a.id);
    }
  });

  test('every event id GameState unlocks directly exists in the table', () {
    for (final id in [
      Achievements.firstStrike,
      Achievements.firstOverclock,
      Achievements.firstCollapse,
      Achievements.maxMomentum,
      Achievements.longAbsence,
      Achievements.sparkCatcher,
      Achievements.firstEpoch,
    ]) {
      final def = Achievements.byId(id);
      expect(def, isNotNull, reason: id);
      expect(def!.isMet, isNull, reason: '$id is event-driven, not polled');
    }
  });

  test('unlocking adds 1% production each and queues a notice', () async {
    SharedPreferences.setMockInitialValues({});
    final gs = GameState();
    await gs.ready;
    addTearDown(gs.dispose);

    expect(gs.achievementBonus, 1.0);
    gs.number = BigInt.from(2000000);
    gs.highestNumber = gs.number;
    gs.setSelectedUpgradeCategory(GameState.idleCategory);
    gs.buyUpgrade(GameState.autoClickerId);

    expect(gs.unlockedAchievements,
        containsAll(['num_1k', 'num_1m', 'first_idle']));
    expect(gs.pendingAchievementIds, containsAll(['num_1k', 'first_idle']));
    expect(gs.achievementBonus,
        closeTo(1 + 0.01 * gs.unlockedAchievements.length, 1e-12));
    expect(gs.globalProductionMultiplier, closeTo(gs.achievementBonus, 1e-12));
  });

  test('a sync keeps unlocks and taps from both sides', () {
    final older = _progress(
      achievements: const ['num_1k', 'clicks_100'],
      clicks: 5000,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final newer = _progress(
      achievements: const ['num_1k', 'prestige_1'],
      clicks: 300,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final result =
        SyncService.pickWinner(local: older, remote: newer, forceUpload: false);
    expect(result.winner, SyncWinner.remote);
    expect(
        result.resolved.achievements, ['clicks_100', 'num_1k', 'prestige_1']);
    expect(result.resolved.lifetimeClicks, 5000);
  });

  test('progress round-trips the new cloud fields', () {
    final p = _progress(
      achievements: const ['a', 'b'],
      clicks: 42,
      updatedAt: DateTime.utc(2026, 1, 1),
    ).copyWith(neuralNetworkJson: '{"x":1}', artifactsJson: '{"y":2}');
    final back = PlayerProgress.fromDatabase(p.toDatabase());
    expect(back.achievements, ['a', 'b']);
    expect(back.lifetimeClicks, 42);
    expect(back.neuralNetworkJson, '{"x":1}');
    expect(back.artifactsJson, '{"y":2}');
  });
}
