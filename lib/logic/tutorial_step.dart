/// Ordered steps for the first-time interactive tutorial.
enum TutorialStep {
  /// Centered welcome card — tap anywhere to continue.
  welcome,

  /// Spotlight on the tap area — click until number reaches 50.
  clickToFifty,

  /// Spotlight on the UPGRADES nav button — tap it.
  navUpgrades,

  /// Spotlight on the IDLE segment button — tap it.
  selectIdle,

  /// Spotlight on the Auto-Clicker row — purchase it.
  buyAutoClicker,

  /// Spotlight on the GENERATORS nav button — tap it.
  navGenerators,

  /// Card only (no dim) — watch idle accumulate until number reaches 100.
  watchIdle,

  /// Spotlight on the UPGRADES nav button — tap it (for click power).
  navUpgradesForClick,

  /// Spotlight on the Click Power row — purchase it.
  buyClickPower,

  /// Centered card — tap anywhere to continue to prestige lesson.
  exploreUpgrades,

  /// Centered card — tap anywhere to finish tutorial and factory-reset.
  learnPrestige,

  /// Spotlight on the PRESTIGE nav button — tap it.
  navPrestige,

  /// Explanation of prestige system on the prestige screen.
  learnPrestigeDetails,

  /// Spotlight on the prestige multiplier stat block.
  prestigeMultiplierHint,

  /// Spotlight on the prestige gain card showing cost and multiplier.
  prestigeGainHint,

  /// Final "good luck" message on main screen.
  goodLuck,

  /// ── Nexus tutorial (fires once, after first stabilization) ────────────
  nexusIntro,
  nexusUpgrades,
  nexusGoal,

  /// ── Neural tutorial (fires once, after Neural Genesis purchase) ───────
  neuralUnlocked,
  navNeural,
  neuralIntro,
  neuralUpgradeHint,
  neuralBranchHint,
  neuralTrainHint,

  /// Tutorial finished or skipped — overlay hidden.
  done,
}
