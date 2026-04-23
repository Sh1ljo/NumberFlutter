/// Ordered steps for the first-time interactive tutorial.
enum TutorialStep {
  /// Tap the main number area at least once.
  welcomeTap,

  /// Open the Upgrades tab from the bottom nav.
  navUpgrades,

  /// Purchase Click Power (CLICK tab).
  buyClickPower,

  /// Purchase Auto-Clicker (IDLE tab).
  buyAutoClicker,

  /// Purchase Probability Strike after a number grant (CLICK tab).
  buyProbabilityStrike,

  /// Open Prestige from the bottom nav (funds granted when tab opens).
  navPrestige,

  /// Initiate prestige; on success the game resets to a fresh state.
  initiatePrestige,

  /// Tutorial finished or skipped.
  done,
}
