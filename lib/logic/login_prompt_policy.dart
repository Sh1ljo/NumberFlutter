import 'package:shared_preferences/shared_preferences.dart';

/// Decides *when* the "Save Your Progress" account prompt is allowed to appear.
///
/// The prompt used to fire on every cold start for every signed-out player,
/// including brand-new ones who had nothing worth saving yet. This gates it on
/// three things instead:
///
///  1. the player has finished the tutorial and banked real progress, so the
///     ask is about protecting something they care about;
///  2. any previous "LATER" has aged out of an escalating snooze;
///  3. they have not dismissed it [maxDismissals] times, or opted out outright.
///
/// Signing in retires the prompt for good. None of this removes the manual
/// sign-in entry points in Settings, the leaderboard or the profile editor —
/// this only controls the *unprompted* modal.
class LoginPromptPolicy {
  static const String _keyDismissCount = 'loginPrompt.dismissCount';
  static const String _keyNextEligibleMs = 'loginPrompt.nextEligibleMs';
  static const String _keyRetired = 'loginPrompt.retired';

  /// How many times a player may tap LATER before the prompt stops for good.
  static const int maxDismissals = 3;

  /// Snooze applied after the 1st, 2nd and 3rd dismissal. The last entry is
  /// academic — [maxDismissals] retires the prompt at the same time — but it
  /// keeps the ladder total even if that cap is ever raised.
  static const List<Duration> snoozeLadder = <Duration>[
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
  ];

  /// Progress floor before the prompt is worth showing at all. Roughly 1% of
  /// the way to the first prestige (100M): far enough in that losing the save
  /// would actually sting, early enough that it is still recoverable.
  static final BigInt progressWorthSaving = BigInt.from(1000000);

  /// True when an unprompted account modal is allowed right now.
  ///
  /// [signedIn] short-circuits everything: a player with a session is never
  /// asked. Callers still own the "is the backend even available" check.
  Future<bool> shouldPrompt({
    required bool signedIn,
    required bool tutorialCompleted,
    required BigInt highestNumber,
    DateTime? now,
  }) async {
    if (signedIn) return false;
    if (!tutorialCompleted) return false;
    if (highestNumber < progressWorthSaving) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyRetired) ?? false) return false;
    if ((prefs.getInt(_keyDismissCount) ?? 0) >= maxDismissals) return false;

    final nextEligibleMs = prefs.getInt(_keyNextEligibleMs);
    if (nextEligibleMs == null) return true;
    final at = now ?? DateTime.now();
    return at.millisecondsSinceEpoch >= nextEligibleMs;
  }

  /// Records a LATER: advances the snooze ladder and retires the prompt once
  /// the player has said no [maxDismissals] times.
  Future<void> recordDismissed({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyDismissCount) ?? 0) + 1;
    await prefs.setInt(_keyDismissCount, count);

    if (count >= maxDismissals) {
      await prefs.setBool(_keyRetired, true);
      return;
    }

    final snooze = snoozeLadder[
        (count - 1).clamp(0, snoozeLadder.length - 1)];
    final at = now ?? DateTime.now();
    await prefs.setInt(
        _keyNextEligibleMs, at.add(snooze).millisecondsSinceEpoch);
  }

  /// Retires the prompt permanently — "don't ask again", or a completed
  /// sign-in. A later sign-out does not bring it back; Settings still has the
  /// button.
  Future<void> retire() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRetired, true);
  }

  /// Clears all prompt history. Used by tests and by an explicit hard reset.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDismissCount);
    await prefs.remove(_keyNextEligibleMs);
    await prefs.remove(_keyRetired);
  }
}
