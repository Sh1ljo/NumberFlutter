import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/login_prompt_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoginPromptPolicy policy;
  final BigInt enoughProgress = LoginPromptPolicy.progressWorthSaving;
  final DateTime t0 = DateTime.utc(2026, 1, 1);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    policy = LoginPromptPolicy();
  });

  Future<bool> ask({
    bool signedIn = false,
    bool tutorialCompleted = true,
    BigInt? highestNumber,
    DateTime? now,
  }) =>
      policy.shouldPrompt(
        signedIn: signedIn,
        tutorialCompleted: tutorialCompleted,
        highestNumber: highestNumber ?? enoughProgress,
        now: now ?? t0,
      );

  group('gates before the first ask', () {
    test('a signed-in player is never prompted', () async {
      expect(await ask(signedIn: true), isFalse);
    });

    test('a player still in the tutorial is never prompted', () async {
      expect(await ask(tutorialCompleted: false), isFalse);
    });

    test('a player with nothing worth saving is never prompted', () async {
      expect(await ask(highestNumber: enoughProgress - BigInt.one), isFalse);
    });

    test('an established signed-out player is prompted once', () async {
      expect(await ask(), isTrue);
    });
  });

  group('snooze ladder', () {
    test('LATER silences the prompt for a day, then lets it back', () async {
      await policy.recordDismissed(now: t0);

      expect(await ask(now: t0.add(const Duration(hours: 23))), isFalse);
      expect(await ask(now: t0.add(const Duration(days: 1))), isTrue);
    });

    test('each LATER buys a longer silence than the last', () async {
      await policy.recordDismissed(now: t0);
      final second = t0.add(const Duration(days: 1));
      await policy.recordDismissed(now: second);

      expect(await ask(now: second.add(const Duration(days: 2))), isFalse);
      expect(await ask(now: second.add(const Duration(days: 3))), isTrue);
    });

    test('the prompt retires itself after the dismissal cap', () async {
      var at = t0;
      for (var i = 0; i < LoginPromptPolicy.maxDismissals; i++) {
        await policy.recordDismissed(now: at);
        at = at.add(const Duration(days: 30));
      }

      // Years later it still stays quiet.
      expect(await ask(now: at.add(const Duration(days: 3650))), isFalse);
    });
  });

  group('retire', () {
    test('never asks again, whatever the clock says', () async {
      await policy.retire();
      expect(await ask(now: t0.add(const Duration(days: 3650))), isFalse);
    });

    test('survives a signed-in player later signing out', () async {
      await policy.retire();
      expect(await ask(signedIn: true), isFalse);
      expect(await ask(signedIn: false), isFalse);
    });
  });

  test('reset clears the history so the prompt is eligible again', () async {
    await policy.retire();
    await policy.reset();
    expect(await ask(), isTrue);
  });

  test('state persists across policy instances, not just in memory', () async {
    await policy.recordDismissed(now: t0);
    final fresh = LoginPromptPolicy();

    expect(
      await fresh.shouldPrompt(
        signedIn: false,
        tutorialCompleted: true,
        highestNumber: enoughProgress,
        now: t0.add(const Duration(hours: 1)),
      ),
      isFalse,
    );
  });
}
