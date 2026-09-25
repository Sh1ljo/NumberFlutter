import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a factory reset erases every stat and record, and survives a restart',
      () async {
    SharedPreferences.setMockInitialValues({
      'number': '123456789',
      'highestNumber': '987654321',
      'prestigeCount': 4,
      'prestigeMultiplier': '3.0',
      'lifetime_clicks': 5000,
      'achievements_unlocked': '["first_strike"]',
      'tutorialCompleted': true,
      'tutorialStep': 'done',
      'tutorialBeatsSeen': '["tipMomentum"]',
      'corrupt_save_backup_1700000000000': '{"number":"42"}',
    });
    final gs = GameState();
    await gs.ready;
    expect(gs.prestigeCount, 4);
    expect(gs.lifetimeClicks, 5000);

    final result = await gs.hardReset();

    expect(result, FactoryResetResult.deviceOnly);
    expect(gs.number, BigInt.zero);
    expect(gs.highestNumber, BigInt.zero);
    expect(gs.prestigeCount, 0);
    expect(gs.prestigeMultiplier, 1.0);
    expect(gs.lifetimeClicks, 0);
    expect(gs.tutorialCompleted, isFalse);
    expect(gs.tutorialStep, TutorialStep.welcome);
    expect(gs.hasSeenTutorialBeat(TutorialStep.tipMomentum), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('corrupt_save_backup_')),
      isEmpty,
      reason: 'old copies of the save are history too',
    );
    // Signed out: there is no cloud account to finish clearing later.
    expect(prefs.getString('pendingCloudResetUserId'), isNull);
    gs.dispose();

    final reloaded = GameState();
    await reloaded.ready;
    addTearDown(reloaded.dispose);
    expect(reloaded.number, BigInt.zero);
    expect(reloaded.highestNumber, BigInt.zero);
    expect(reloaded.prestigeCount, 0);
    expect(reloaded.lifetimeClicks, 0);
    expect(reloaded.tutorialStep, TutorialStep.welcome);
  });
}
