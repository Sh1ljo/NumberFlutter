/// Every step of every tutorial chapter, tip and teaser.
///
/// The game teaches each system at the moment it unlocks rather than all at
/// once up front: a one-minute onboarding (chapter 1), then a short chapter
/// per system as the player reaches it, single-card tips when a new upgrade
/// first becomes affordable, and teaser cards that hint at what is coming
/// next so there is always something to chase.
///
/// Steps are persisted by NAME (see StorageService), so renaming or removing
/// one needs a matching entry in [legacyTutorialStepNames].
enum TutorialStep {
  // ── Chapter 1 · First steps (new game) ─────────────────────────────────
  /// Centered welcome card — tap anywhere to continue.
  welcome,

  /// Spotlight on the tap area — click until the Auto-Clicker is affordable.
  clickToFifty,

  /// Spotlight on the UPGRADES nav button — tap it.
  navUpgrades,

  /// Spotlight on the IDLE segment button — tap it.
  selectIdle,

  /// Spotlight on the Auto-Clicker row — purchase it.
  buyAutoClicker,

  /// Spotlight on the GENERATORS nav button — tap it.
  navGenerators,

  /// Card only (no dim) — watch idle accumulate.
  watchIdle,

  /// Spotlight on the UPGRADES nav button — tap it (for click power).
  navUpgradesForClick,

  /// Spotlight on the Click Power row — purchase it.
  buyClickPower,

  /// Spotlight on the GENERATORS nav button — go catch a spark.
  navGeneratorsForSpark,

  /// Card only (no dim) — a Neural Spark is spawned on purpose; catch it.
  catchSpark,

  /// The road ahead: locked silhouettes of every system still to come.
  roadAhead,

  // ── Tips ───────────────────────────────────────────────────────────────
  /// First visit to UPGRADES after chapter 1: the advisor card.
  tipAdvisor,

  // ── Upgrade lessons · the first time a special upgrade is affordable ───
  // Each walks the player through buying it, then makes it happen on the
  // play field, then explains it. The last card of each (tip…) is also the
  // lesson's "seen" record, so its name must never change.
  probabilityStrikeOpen,
  probabilityStrikeBuy,
  probabilityStrikeBack,
  probabilityStrikeTry,
  tipProbabilityStrike,

  momentumOpen,
  momentumBuy,
  momentumBack,
  momentumTry,
  tipMomentum,

  kineticSynergyOpen,
  kineticSynergyBuy,
  kineticSynergyBack,
  kineticSynergyTry,
  tipKineticSynergy,

  overclockOpen,
  overclockBuy,
  overclockBack,
  overclockTry,
  tipOverclock,

  dimensionalTapOpen,
  dimensionalTapBuy,
  dimensionalTapBack,
  dimensionalTapTry,
  tipDimensionalTap,

  cascadeResonatorOpen,
  cascadeResonatorBuy,
  cascadeResonatorBack,
  cascadeResonatorTry,
  tipCascadeResonator,

  temporalCollapseOpen,
  temporalCollapseBuy,
  temporalCollapseBack,
  temporalCollapseTry,
  tipTemporalCollapse,

  // ── Chapter 2 · First prestige (first time the requirement is reached) ─
  prestigeReady,
  navPrestige,
  learnPrestigeDetails,
  prestigeMultiplierHint,
  prestigeGainHint,

  /// Spotlight on the real INITIATE PRESTIGE button.
  doPrestige,

  // ── Chapter 3 · Artifacts (after the first prestige) ───────────────────
  artifactsIntro,
  artifactsEmpower,

  /// Teaser: the Nexus is two prestiges away.
  nexusWhisper,

  // ── Teaser at prestige 2 ───────────────────────────────────────────────
  nexusSignal,

  // ── Chapter 4 · The Nexus ──────────────────────────────────────────────
  /// Fires after the prestige that makes the Nexus stabilizable.
  nexusAwakens,
  navPrestigeForNexus,

  /// Spotlight on the real STABILIZE button.
  nexusStabilize,

  /// Fires once the Nexus is stabilized (with or without the steps above).
  nexusIntro,
  nexusUpgrades,

  /// Spotlight on the real Optimization Protocol node — tap it, open the
  /// real NodeDetailSheet, press the real RESEARCH button.
  nexusResearchOptProtocol,
  nexusGoal,

  // ── Teasers on the way down the Nexus tree ─────────────────────────────
  neuralWhisper,
  neuralGenesisReady,

  // ── Chapter 5 · Neural network (after Neural Genesis) ──────────────────
  neuralUnlocked,
  navNeural,
  neuralIntro,

  /// Spotlight on the first neuron — user taps it to open the detail sheet.
  neuralTapNeuron,

  /// Guided inside NeuronDetailSheet — upgrade gradient.
  neuralUpgradeGradient,

  /// Guided inside NeuronDetailSheet — change activation function.
  neuralChangeActivation,

  /// Guided inside NeuronDetailSheet — branch the neuron.
  neuralBranchNeuron,

  /// Spotlight on the loss HUD — explains accuracy & multiplier.
  neuralViewAccuracy,

  /// Tap-to-continue — accuracy asymptote & multiplier explanation.
  neuralAccuracyLimit,

  // ── Late game ──────────────────────────────────────────────────────────
  tipDeepLayers,
  tipEpoch,

  /// Tutorial finished or skipped — overlay hidden.
  done,
}

/// Step names written by older builds that no longer exist. A save still
/// sitting on one of these was past the old onboarding's first minute (the
/// old upgrade deep-dive and prestige tail), so it is treated as having
/// finished chapter 1.
const Set<String> legacyTutorialStepNames = {
  'learnPrestige',
  'goodLuck',
  'upgradeIntro',
  'probabilityStrikeIntro',
  'buyProbabilityStrike',
  'navGeneratorsForStrike',
  'triggerProbabilityStrike',
  'navUpgradesForMomentum',
  'momentumIntro',
  'buyMomentum',
  'navGeneratorsForMomentum',
  'demonstrateMomentum',
  'navUpgradesForSpecial',
  'kineticSynergyIntro',
  'overclockIntro',
  'upgradesDone',
};

/// Which tutorial a step belongs to. SKIP ends the current one only.
enum TutorialScope {
  main,
  prestige,
  artifacts,
  nexus,
  neural,

  /// Single cards (the advisor tip and teasers). Each is its own
  /// one-shot "tutorial", remembered by its step.
  tips,

  /// A special upgrade's lesson (see [upgradeLessons]). SKIP ends it and
  /// remembers it as seen.
  lesson,
  none,
}

/// How the overlay renders a step.
enum TutorialMode {
  /// Full dim, advances on a tap anywhere.
  tapToContinue,

  /// Dim with a hole over the target; only the target is tappable. Advances
  /// when the player performs the action.
  spotlightAction,

  /// Dim with a hole over the target, like [spotlightAction], but advances on
  /// a tap *inside* the hole — for inert display widgets (a stat block, a
  /// cost card) that have no purchase/nav action of their own to hook into.
  spotlightTapToContinue,

  /// Pulsing outline over the target, no dim, taps pass through. For nav
  /// buttons and other chrome the player must be able to reach freely.
  passthroughHint,

  /// Floating card, nothing blocked, nothing dimmed. For "keep playing and
  /// watch what happens" steps.
  floatingHint,

  /// Owned by NeuronDetailSheet, which renders its own in-sheet guidance.
  /// The overlay shows a fallback card when the sheet is closed so the step
  /// can't become invisible and unescapable.
  inSheet,
}

/// Extra content drawn inside a step's card.
enum TutorialVisual {
  /// Locked silhouettes of every system still ahead of the player.
  roadmap,

  /// Live progress bar for a lesson's "try it" goal (taps, streak, combo).
  lessonProgress,
}

/// Named UI target, resolved to a GlobalKey by the overlay via a registry
/// owned by MainLayout.
enum TutorialTarget {
  tapArea,
  navGenerators,
  navUpgrades,
  navPrestige,
  navNeural,
  idleCategory,
  advisorBanner,
  prestigeMultiplier,
  prestigeGainCard,
  prestigeInitiate,
  nexusStabilizeButton,
  nexusOptProtocolNode,
  neuralNeuron,
  neuralHud,
  upgradeAutoClicker,
  upgradeClickPower,
  upgradeProbabilityStrike,
  upgradeMomentum,
  upgradeKineticSynergy,
  upgradeOverclock,
  upgradeDimensionalTap,
  upgradeCascadeResonator,
  upgradeTemporalCollapse,

  /// The TEMPORAL COLLAPSE button on GENERATORS.
  temporalCollapseButton,

  /// The "+N / sec" line on GENERATORS.
  idleRate,
}

/// Tab indices in MainLayout's screen list.
abstract class TutorialTab {
  static const int generators = 0;
  static const int upgrades = 1;
  static const int prestige = 2;
  static const int neural = 3;
}

/// Tab indices inside the Prestige screen.
abstract class PrestigeSubTab {
  static const int prestige = 0;
  static const int nexus = 1;
  static const int artifacts = 2;
}

/// Everything the overlay needs to know about one step, in one place.
class TutorialStepSpec {
  final TutorialScope scope;
  final TutorialMode mode;

  /// UI element to spotlight, if any.
  final TutorialTarget? target;

  /// Tab that must be active for this step to render. When the player is on
  /// any other tab the overlay stays out of the way instead of pointing at
  /// something that isn't on screen.
  final int? requiredTab;

  /// Prestige-screen tab the target lives on. The Prestige screen switches
  /// to it by itself while the step is active.
  final int? requiredPrestigeSubTab;

  /// Upgrade category that must be selected for [target] to exist.
  final String? requiredCategory;

  final String? title;
  final String? body;

  /// Small label above the title for single cards ("NEW UPGRADE").
  /// Chapter steps get "CHAPTER n · NAME · i/n" instead.
  final String? kicker;

  /// Overrides the default "TAP ANYWHERE TO CONTINUE" hint.
  final String? continueHint;

  final TutorialVisual? visual;

  const TutorialStepSpec({
    required this.scope,
    required this.mode,
    this.target,
    this.requiredTab,
    this.requiredPrestigeSubTab,
    this.requiredCategory,
    this.title,
    this.body,
    this.kicker,
    this.continueHint,
    this.visual,
  });

  bool get isTapToContinue => mode == TutorialMode.tapToContinue;

  /// Every step must be escapable. There is no `allowSkip: false` — a step
  /// with no way out is the single worst failure mode this system has.
  bool get hasCopy => title != null && body != null;
}

/// A multi-step tutorial, numbered in the order a player meets it.
class TutorialChapter {
  final int number;
  final String name;
  final TutorialScope scope;
  final List<TutorialStep> steps;

  const TutorialChapter({
    required this.number,
    required this.name,
    required this.scope,
    required this.steps,
  });
}

const List<TutorialChapter> tutorialChapters = [
  TutorialChapter(
    number: 1,
    name: 'FIRST STEPS',
    scope: TutorialScope.main,
    steps: [
      TutorialStep.welcome,
      TutorialStep.clickToFifty,
      TutorialStep.navUpgrades,
      TutorialStep.selectIdle,
      TutorialStep.buyAutoClicker,
      TutorialStep.navGenerators,
      TutorialStep.watchIdle,
      TutorialStep.navUpgradesForClick,
      TutorialStep.buyClickPower,
      TutorialStep.navGeneratorsForSpark,
      TutorialStep.catchSpark,
      TutorialStep.roadAhead,
    ],
  ),
  TutorialChapter(
    number: 2,
    name: 'PRESTIGE',
    scope: TutorialScope.prestige,
    steps: [
      TutorialStep.prestigeReady,
      TutorialStep.navPrestige,
      TutorialStep.learnPrestigeDetails,
      TutorialStep.prestigeMultiplierHint,
      TutorialStep.prestigeGainHint,
      TutorialStep.doPrestige,
    ],
  ),
  TutorialChapter(
    number: 3,
    name: 'ARTIFACTS',
    scope: TutorialScope.artifacts,
    steps: [
      TutorialStep.artifactsIntro,
      TutorialStep.artifactsEmpower,
      TutorialStep.nexusWhisper,
    ],
  ),
  TutorialChapter(
    number: 4,
    name: 'THE NEXUS',
    scope: TutorialScope.nexus,
    steps: [
      TutorialStep.nexusAwakens,
      TutorialStep.navPrestigeForNexus,
      TutorialStep.nexusStabilize,
      TutorialStep.nexusIntro,
      TutorialStep.nexusUpgrades,
      TutorialStep.nexusResearchOptProtocol,
      TutorialStep.nexusGoal,
    ],
  ),
  TutorialChapter(
    number: 5,
    name: 'NEURAL NETWORK',
    scope: TutorialScope.neural,
    steps: [
      TutorialStep.neuralUnlocked,
      TutorialStep.navNeural,
      TutorialStep.neuralIntro,
      TutorialStep.neuralTapNeuron,
      TutorialStep.neuralUpgradeGradient,
      TutorialStep.neuralChangeActivation,
      TutorialStep.neuralBranchNeuron,
      TutorialStep.neuralViewAccuracy,
      TutorialStep.neuralAccuracyLimit,
    ],
  ),
];

/// The chapter [step] belongs to, or null for tips, teasers and `done`.
TutorialChapter? chapterFor(TutorialStep step) {
  for (final chapter in tutorialChapters) {
    if (chapter.steps.contains(step)) return chapter;
  }
  return null;
}

/// The small label above a card's title.
String? tutorialKickerFor(TutorialStep step) {
  final chapter = chapterFor(step);
  if (chapter != null) {
    final index = chapter.steps.indexOf(step) + 1;
    return 'CHAPTER ${chapter.number} · ${chapter.name} · '
        '$index/${chapter.steps.length}';
  }
  final lesson = lessonFor(step);
  if (lesson != null) {
    final index = lesson.steps.indexOf(step) + 1;
    return '${lesson.label} · $index/${lesson.steps.length}';
  }
  return specFor(step).kicker;
}

/// What the player has to do on the play field before a lesson explains
/// the upgrade.
enum LessonGoal {
  /// Land a Probability Strike (the lesson guarantees one within a few taps).
  strike,

  /// Build a Momentum combo of [UpgradeLesson.goalCount] taps.
  combo,

  /// Keep an unbroken streak until Overclock fires.
  streak,

  /// Tap [UpgradeLesson.goalCount] times.
  taps,

  /// Look at the spotlit stat and tap it.
  look,

  /// Fire the active ability.
  ability,
}

/// A special upgrade's lesson: open UPGRADES, buy it, go back to the play
/// field, see it work, then a short explanation.
class UpgradeLesson {
  final String upgradeId;

  /// Kicker prefix, e.g. "NEW UPGRADE".
  final String label;
  final LessonGoal goal;

  /// Taps (or combo length) the "try it" step asks for, where it counts.
  final int goalCount;

  /// open, buy, back, try, explain — in that order.
  final List<TutorialStep> steps;

  const UpgradeLesson({
    required this.upgradeId,
    required this.label,
    required this.goal,
    required this.steps,
    this.goalCount = 0,
  });

  TutorialStep get open => steps[0];
  TutorialStep get buy => steps[1];
  TutorialStep get back => steps[2];
  TutorialStep get tryIt => steps[3];
  TutorialStep get explain => steps[4];

  /// Recorded as seen once the lesson is finished or skipped.
  TutorialStep get beat => explain;
}

/// In the order they become affordable in a first run.
const List<UpgradeLesson> upgradeLessons = [
  UpgradeLesson(
    upgradeId: 'click_probability_strike',
    label: _kickerNewUpgrade,
    goal: LessonGoal.strike,
    steps: [
      TutorialStep.probabilityStrikeOpen,
      TutorialStep.probabilityStrikeBuy,
      TutorialStep.probabilityStrikeBack,
      TutorialStep.probabilityStrikeTry,
      TutorialStep.tipProbabilityStrike,
    ],
  ),
  UpgradeLesson(
    upgradeId: 'click_momentum',
    label: _kickerNewUpgrade,
    goal: LessonGoal.combo,
    goalCount: 25,
    steps: [
      TutorialStep.momentumOpen,
      TutorialStep.momentumBuy,
      TutorialStep.momentumBack,
      TutorialStep.momentumTry,
      TutorialStep.tipMomentum,
    ],
  ),
  UpgradeLesson(
    upgradeId: 'click_kinetic_synergy',
    label: _kickerNewUpgrade,
    goal: LessonGoal.taps,
    goalCount: 5,
    steps: [
      TutorialStep.kineticSynergyOpen,
      TutorialStep.kineticSynergyBuy,
      TutorialStep.kineticSynergyBack,
      TutorialStep.kineticSynergyTry,
      TutorialStep.tipKineticSynergy,
    ],
  ),
  UpgradeLesson(
    upgradeId: 'click_overclock',
    label: _kickerNewUpgrade,
    goal: LessonGoal.streak,
    steps: [
      TutorialStep.overclockOpen,
      TutorialStep.overclockBuy,
      TutorialStep.overclockBack,
      TutorialStep.overclockTry,
      TutorialStep.tipOverclock,
    ],
  ),
  UpgradeLesson(
    upgradeId: 'click_dimensional_tap',
    label: _kickerNewUpgrade,
    goal: LessonGoal.taps,
    goalCount: 5,
    steps: [
      TutorialStep.dimensionalTapOpen,
      TutorialStep.dimensionalTapBuy,
      TutorialStep.dimensionalTapBack,
      TutorialStep.dimensionalTapTry,
      TutorialStep.tipDimensionalTap,
    ],
  ),
  UpgradeLesson(
    upgradeId: 'idle_cascade_resonator',
    label: _kickerNewUpgrade,
    goal: LessonGoal.look,
    steps: [
      TutorialStep.cascadeResonatorOpen,
      TutorialStep.cascadeResonatorBuy,
      TutorialStep.cascadeResonatorBack,
      TutorialStep.cascadeResonatorTry,
      TutorialStep.tipCascadeResonator,
    ],
  ),
  UpgradeLesson(
    upgradeId: 'click_temporal_collapse',
    label: 'NEW ABILITY',
    goal: LessonGoal.ability,
    steps: [
      TutorialStep.temporalCollapseOpen,
      TutorialStep.temporalCollapseBuy,
      TutorialStep.temporalCollapseBack,
      TutorialStep.temporalCollapseTry,
      TutorialStep.tipTemporalCollapse,
    ],
  ),
];

/// The lesson [step] belongs to, or null.
UpgradeLesson? lessonFor(TutorialStep step) {
  for (final lesson in upgradeLessons) {
    if (lesson.steps.contains(step)) return lesson;
  }
  return null;
}

/// Upgrade → the step that records its lesson as seen.
final Map<String, TutorialStep> upgradeTipSteps = {
  for (final lesson in upgradeLessons) lesson.upgradeId: lesson.beat,
};

const String _clickCategory = 'click';
const String _idleCategory = 'idle';

const String _kickerNewUpgrade = 'NEW UPGRADE';
const String _kickerSignal = 'INCOMING SIGNAL';

/// The single source of truth for step behaviour.
///
/// `test/tutorial_spec_test.dart` asserts this covers every [TutorialStep]
/// except [TutorialStep.done], that every spotlight step names a target, and
/// that every step either has copy or is explicitly [TutorialMode.inSheet].
const Map<TutorialStep, TutorialStepSpec> tutorialSpecs = {
  // ── Chapter 1 · First steps ──────────────────────────────────────────────
  TutorialStep.welcome: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    title: 'WELCOME TO NUMBER',
    body:
        'One goal: make the biggest number you can. It starts with a single '
        'tap. It will not stay that simple — numbers this big have a way of '
        'waking things up.',
  ),
  TutorialStep.clickToFifty: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.tapArea,
    requiredTab: TutorialTab.generators,
    title: 'TAP',
    body:
        'Tap anywhere on the play field. Every tap adds to your number. Keep '
        'going until you can afford your first upgrade.',
  ),
  TutorialStep.navUpgrades: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'NICE WORK!',
    body: 'Your first upgrade is within reach. Open UPGRADES below.',
  ),
  TutorialStep.selectIdle: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.idleCategory,
    requiredTab: TutorialTab.upgrades,
    title: 'IDLE UPGRADES',
    body:
        "Switch to IDLE. Idle upgrades earn for you automatically — even "
        "while the app is closed.",
  ),
  TutorialStep.buyAutoClicker: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeAutoClicker,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _idleCategory,
    title: 'AUTO-CLICKER',
    body:
        'Buy the Auto-Clicker! Each level adds +1 number per second, forever.',
  ),
  TutorialStep.navGenerators: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'SEE IT WORK',
    body: 'Head back to GENERATORS and watch your number climb on its own.',
  ),
  TutorialStep.watchIdle: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'IDLE INCOME',
    body:
        'Your number is growing by itself now. Tapping still adds on top — '
        'keep going!',
  ),
  TutorialStep.navUpgradesForClick: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'POWER UP YOUR TAPS',
    body: 'Back to UPGRADES — this time we boost every tap.',
  ),
  TutorialStep.buyClickPower: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeClickPower,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'CLICK POWER',
    body: 'Buy Click Power! Each level makes every tap worth more.',
  ),
  TutorialStep.navGeneratorsForSpark: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'SOMETHING FLICKERED',
    body: 'Head back to GENERATORS. Something just appeared on the field.',
  ),
  TutorialStep.catchSpark: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'CATCH THE SPARK',
    body:
        'Tap the glowing Neural Spark before it fades — it doubles your taps '
        'for 10 seconds. They keep appearing, so stay sharp. "Neural" is a '
        'word worth remembering.',
  ),
  TutorialStep.roadAhead: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    title: 'THE ROAD AHEAD',
    body:
        "That's the basics. Everything below is waiting for you — each one "
        "unlocks as you grow, and we'll show you around when it does. Here's "
        '5 minutes of ×1.5 production to get you started.',
    continueHint: 'TAP ANYWHERE TO START PLAYING',
    visual: TutorialVisual.roadmap,
  ),

  // ── Tips ─────────────────────────────────────────────────────────────────
  TutorialStep.tipAdvisor: TutorialStepSpec(
    scope: TutorialScope.tips,
    mode: TutorialMode.tapToContinue,
    target: TutorialTarget.advisorBanner,
    requiredTab: TutorialTab.upgrades,
    kicker: 'TIP',
    title: 'NOT SURE WHAT TO BUY?',
    body:
        'The RECOMMENDED card points at the purchase that pays for itself '
        'fastest, and tells you when saving up for prestige is the better '
        'move. Tap BUY to follow it. The ×1 / ×10 / NEXT / MAX toggle up top '
        'buys in bulk.',
  ),

  // ── Upgrade lessons ──────────────────────────────────────────────────────
  // open → buy → back → try → explain. See [upgradeLessons].

  // Probability Strike
  TutorialStep.probabilityStrikeOpen: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'PROBABILITY STRIKE',
    body:
        'A new upgrade is within reach: it gives every tap a chance to hit '
        'ten times harder. Open UPGRADES and let us try it.',
  ),
  TutorialStep.probabilityStrikeBuy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeProbabilityStrike,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY IT',
    body: 'Buy one level of Probability Strike.',
  ),
  TutorialStep.probabilityStrikeBack: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'NOW SEE IT',
    body: 'Head back to GENERATORS.',
  ),
  TutorialStep.probabilityStrikeTry: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'WATCH FOR GOLD',
    body: 'Tap away. When a strike lands you will see a big gold number.',
  ),
  TutorialStep.tipProbabilityStrike: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.tapToContinue,
    title: 'THAT WAS A STRIKE',
    body:
        'About 1 tap in 20 strikes for ×10. Each level adds another ×2 to '
        'every strike, so it pays most for players who tap a lot.',
  ),

  // Momentum
  TutorialStep.momentumOpen: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'MOMENTUM',
    body:
        'Momentum turns fast tapping into a growing combo. Open UPGRADES to '
        'get it.',
  ),
  TutorialStep.momentumBuy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeMomentum,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY IT',
    body: 'Buy one level of Momentum.',
  ),
  TutorialStep.momentumBack: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'BUILD A COMBO',
    body: 'Head back to GENERATORS.',
  ),
  TutorialStep.momentumTry: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'KEEP TAPPING',
    body:
        'Tap without stopping and watch the MOMENTUM bar at the top fill up. '
        'Every tap in the chain is worth a little more than the last.',
    visual: TutorialVisual.lessonProgress,
  ),
  TutorialStep.tipMomentum: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.tapToContinue,
    title: 'THAT IS MOMENTUM',
    body:
        'Each tap in an unbroken chain adds +2%, up to ×2. Pause for over a '
        'second and the chain starts again. Levels build the combo faster, '
        'raise the cap and slow the drain.',
  ),

  // Kinetic Synergy
  TutorialStep.kineticSynergyOpen: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'KINETIC SYNERGY',
    body:
        'This one links your taps to your idle income. Open UPGRADES to get '
        'it.',
  ),
  TutorialStep.kineticSynergyBuy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeKineticSynergy,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY IT',
    body: 'Buy one level of Kinetic Synergy.',
  ),
  TutorialStep.kineticSynergyBack: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'NOW SEE IT',
    body: 'Head back to GENERATORS.',
  ),
  TutorialStep.kineticSynergyTry: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'TAP A FEW TIMES',
    body:
        'Every tap now carries a slice of your idle income on top of its '
        'usual value. Watch the numbers.',
    visual: TutorialVisual.lessonProgress,
  ),
  TutorialStep.tipKineticSynergy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.tapToContinue,
    title: 'IDLE POWERS YOUR TAPS',
    body:
        'Each level adds 1% of your idle income per second to every tap. The '
        'more your generators make, the harder you hit.',
  ),

  // Overclock
  TutorialStep.overclockOpen: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'OVERCLOCK',
    body:
        'Overclock rewards a long tapping streak with a surge of idle '
        'income. Open UPGRADES to get it.',
  ),
  TutorialStep.overclockBuy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeOverclock,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY IT',
    body: 'Buy one level of Overclock.',
  ),
  TutorialStep.overclockBack: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'NOW SEE IT',
    body: 'Head back to GENERATORS.',
  ),
  TutorialStep.overclockTry: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'NO BREAKS',
    body:
        'Tap without pausing for more than a second until the streak below '
        'fills. A pause starts it again from zero.',
    visual: TutorialVisual.lessonProgress,
  ),
  TutorialStep.tipOverclock: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.tapToContinue,
    title: 'OVERCLOCKED',
    body:
        'Your idle income is doubled for the next 30 seconds. It fires once '
        'per streak: pause, then start a new streak to fire it again. '
        'Levels make the surge stronger and longer, and the streak shorter.',
  ),

  // Dimensional Tap
  TutorialStep.dimensionalTapOpen: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'DIMENSIONAL TAP',
    body:
        'Your prestige opened a click upgrade that grows with every '
        'prestige. Open UPGRADES to get it.',
  ),
  TutorialStep.dimensionalTapBuy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeDimensionalTap,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY IT',
    body: 'Buy one level of Dimensional Tap.',
  ),
  TutorialStep.dimensionalTapBack: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'NOW SEE IT',
    body: 'Head back to GENERATORS.',
  ),
  TutorialStep.dimensionalTapTry: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'FEEL THE DIFFERENCE',
    body: 'Tap a few times and compare the numbers with before.',
    visual: TutorialVisual.lessonProgress,
  ),
  TutorialStep.tipDimensionalTap: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.tapToContinue,
    title: 'IT GROWS WITH PRESTIGE',
    body:
        'Each level adds click power equal to 500 × your prestige '
        'multiplier. Every prestige raises that multiplier, so it hits '
        'harder every run.',
  ),

  // Cascade Resonator
  TutorialStep.cascadeResonatorOpen: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'CASCADE RESONATOR',
    body:
        'This one doubles all of your idle income at once. Open UPGRADES to '
        'get it.',
  ),
  TutorialStep.cascadeResonatorBuy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeCascadeResonator,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _idleCategory,
    title: 'BUY IT',
    body: 'Buy one level of Cascade Resonator.',
  ),
  TutorialStep.cascadeResonatorBack: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'NOW SEE IT',
    body: 'Head back to GENERATORS.',
  ),
  TutorialStep.cascadeResonatorTry: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightTapToContinue,
    target: TutorialTarget.idleRate,
    requiredTab: TutorialTab.generators,
    title: 'DOUBLED',
    body:
        'That is your idle income now: twice what it was a moment ago. '
        'Tap it to continue.',
  ),
  TutorialStep.tipCascadeResonator: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.tapToContinue,
    title: '×2, ×4, ×8…',
    body:
        'Every level doubles your whole idle rate again, on top of every '
        'other multiplier. It gets expensive fast, but nothing else grows '
        'idle income like it.',
  ),

  // Temporal Collapse
  TutorialStep.temporalCollapseOpen: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'TEMPORAL COLLAPSE',
    body:
        'Your first active ability is within reach. Open UPGRADES to get '
        'it.',
  ),
  TutorialStep.temporalCollapseBuy: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeTemporalCollapse,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY IT',
    body: 'Buy one level of Temporal Collapse.',
  ),
  TutorialStep.temporalCollapseBack: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'A NEW BUTTON',
    body: 'Head back to GENERATORS. Something new is waiting there.',
  ),
  TutorialStep.temporalCollapseTry: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.temporalCollapseButton,
    requiredTab: TutorialTab.generators,
    title: 'FIRE IT',
    body: 'Tap TEMPORAL COLLAPSE.',
  ),
  TutorialStep.tipTemporalCollapse: TutorialStepSpec(
    scope: TutorialScope.lesson,
    mode: TutorialMode.tapToContinue,
    title: 'TIME, COLLAPSED',
    body:
        'You just got 60 seconds of idle income in one burst, and '
        'everything you make is doubled for the next 45 seconds. Then it '
        'recharges for a few minutes. Levels add to the burst, stretch the '
        'boost and shorten the recharge.',
  ),

  // ── Chapter 2 · First prestige ───────────────────────────────────────────
  TutorialStep.prestigeReady: TutorialStepSpec(
    scope: TutorialScope.prestige,
    mode: TutorialMode.tapToContinue,
    title: 'PRESTIGE IS READY',
    body:
        "You've reached the prestige requirement. You can now trade this "
        'whole run for permanent power — and something is waiting for you on '
        'the other side.',
  ),
  TutorialStep.navPrestige: TutorialStepSpec(
    scope: TutorialScope.prestige,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navPrestige,
    title: 'OPEN PRESTIGE',
    body: 'Tap PRESTIGE below.',
  ),
  TutorialStep.learnPrestigeDetails: TutorialStepSpec(
    scope: TutorialScope.prestige,
    mode: TutorialMode.tapToContinue,
    requiredTab: TutorialTab.prestige,
    requiredPrestigeSubTab: PrestigeSubTab.prestige,
    title: 'HOW PRESTIGE WORKS',
    body:
        'Prestiging resets your number and upgrades to zero. In return you '
        'keep a permanent multiplier on everything and earn Prestige Points '
        '(PP). The second run is much faster than the first.',
  ),
  TutorialStep.prestigeMultiplierHint: TutorialStepSpec(
    scope: TutorialScope.prestige,
    mode: TutorialMode.spotlightTapToContinue,
    target: TutorialTarget.prestigeMultiplier,
    requiredTab: TutorialTab.prestige,
    requiredPrestigeSubTab: PrestigeSubTab.prestige,
    title: 'YOUR PRESTIGE MULTIPLIER',
    body:
        'Your permanent boost. It multiplies taps and idle income alike, and '
        'grows with every prestige.',
  ),
  TutorialStep.prestigeGainHint: TutorialStepSpec(
    scope: TutorialScope.prestige,
    mode: TutorialMode.spotlightTapToContinue,
    target: TutorialTarget.prestigeGainCard,
    requiredTab: TutorialTab.prestige,
    requiredPrestigeSubTab: PrestigeSubTab.prestige,
    title: 'COST & REWARD',
    body:
        'The requirement and what you get for it. Each prestige raises the '
        'requirement — and the reward with it.',
  ),
  TutorialStep.doPrestige: TutorialStepSpec(
    scope: TutorialScope.prestige,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.prestigeInitiate,
    requiredTab: TutorialTab.prestige,
    requiredPrestigeSubTab: PrestigeSubTab.prestige,
    title: 'DO IT',
    body: 'Tap INITIATE PRESTIGE and confirm. See you on the other side.',
  ),

  // ── Chapter 3 · Artifacts ────────────────────────────────────────────────
  TutorialStep.artifactsIntro: TutorialStepSpec(
    scope: TutorialScope.artifacts,
    mode: TutorialMode.tapToContinue,
    title: 'YOUR FIRST ARTIFACT',
    body:
        'Your first prestige earned an Artifact — a permanent relic that '
        'bends the rules of every run. In a moment you pick one of three. '
        'More milestones bring more picks; relics you pass on can come back.',
  ),
  TutorialStep.artifactsEmpower: TutorialStepSpec(
    scope: TutorialScope.artifacts,
    mode: TutorialMode.tapToContinue,
    title: 'EMPOWER THEM',
    body:
        'Artifacts level up with Prestige Points (PRESTIGE › ARTIFACTS) and '
        'have no level cap. Also new: Dimensional Tap is in your upgrades — '
        'it grows with every prestige.',
  ),
  TutorialStep.nexusWhisper: TutorialStepSpec(
    scope: TutorialScope.artifacts,
    mode: TutorialMode.tapToContinue,
    title: 'SOMETHING STIRS',
    body:
        'Beneath the prestige layer, something noticed you. Take a look at '
        'PRESTIGE › NEXUS sometime. Two more prestiges and it will be ready '
        'to wake.',
  ),

  // ── Teaser ───────────────────────────────────────────────────────────────
  TutorialStep.nexusSignal: TutorialStepSpec(
    scope: TutorialScope.tips,
    mode: TutorialMode.tapToContinue,
    kicker: _kickerSignal,
    title: 'THE NEXUS HUMS',
    body:
        'The signal is stronger now. One more prestige and the Nexus can be '
        'stabilized — a research tree that makes you permanently stronger, '
        'with something much stranger at its root.',
  ),

  // ── Chapter 4 · The Nexus ────────────────────────────────────────────────
  TutorialStep.nexusAwakens: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.tapToContinue,
    title: 'THE NEXUS AWAKENS',
    body:
        'Three prestiges. The Nexus is ready to be stabilized. Let us go and '
        'wake it up.',
  ),
  TutorialStep.navPrestigeForNexus: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navPrestige,
    title: 'OPEN PRESTIGE',
    body: 'Tap PRESTIGE below. The Nexus lives on its second tab.',
  ),
  TutorialStep.nexusStabilize: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.nexusStabilizeButton,
    requiredTab: TutorialTab.prestige,
    requiredPrestigeSubTab: PrestigeSubTab.nexus,
    title: 'STABILIZE IT',
    body: 'Tap STABILIZE and watch.',
  ),
  TutorialStep.nexusIntro: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.tapToContinue,
    title: 'THE NEXUS',
    body:
        'The Nexus is stable — your hub for permanent research. Spend '
        'Prestige Points (PP) here on upgrades that survive every reset.',
  ),
  TutorialStep.nexusUpgrades: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.tapToContinue,
    title: 'A TREE OF UPGRADES',
    body:
        'Research is a tree: levelling nodes in one tier opens the next. Each '
        'level stacks forever, through every prestige.',
  ),
  TutorialStep.nexusResearchOptProtocol: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.nexusOptProtocolNode,
    requiredTab: TutorialTab.prestige,
    requiredPrestigeSubTab: PrestigeSubTab.nexus,
    title: 'RESEARCH IT',
    body:
        'Tap the highlighted node — Optimization Protocol — then press '
        'RESEARCH to spend your first Prestige Points on a permanent upgrade.',
  ),
  TutorialStep.nexusGoal: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.tapToContinue,
    title: 'AT THE ROOT',
    body:
        'At the very bottom of the tree sits Neural Genesis. Nobody who '
        'reaches it plays the same game afterwards. Climb down to it.',
  ),

  // ── Teasers ──────────────────────────────────────────────────────────────
  TutorialStep.neuralWhisper: TutorialStepSpec(
    scope: TutorialScope.tips,
    mode: TutorialMode.tapToContinue,
    kicker: _kickerSignal,
    title: 'SOMETHING IS LISTENING',
    body:
        'You reached the deepest tier. Level Resonance Core and Echo Protocol '
        'to 5 and Neural Genesis opens: a network that learns, and '
        'multiplies everything it touches.',
  ),
  TutorialStep.neuralGenesisReady: TutorialStepSpec(
    scope: TutorialScope.tips,
    mode: TutorialMode.tapToContinue,
    kicker: _kickerSignal,
    title: 'NEURAL GENESIS IS OPEN',
    body:
        'The path is clear. Research Neural Genesis in the Nexus to awaken '
        'the network — the deepest layer of the game.',
  ),

  // ── Chapter 5 · Neural network ───────────────────────────────────────────
  TutorialStep.neuralUnlocked: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.tapToContinue,
    title: 'NEURAL GENESIS',
    body:
        "Neural Genesis is online — your first neuron just spawned. Let's "
        'take a quick tour of the most complex system in the game.',
  ),
  TutorialStep.navNeural: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navNeural,
    title: 'OPEN NEURAL',
    body: 'Tap NEURAL below to view your network.',
  ),
  TutorialStep.neuralIntro: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.tapToContinue,
    requiredTab: TutorialTab.neural,
    title: 'YOUR NETWORK',
    body:
        'This is your neural network. As it trains, accuracy rises — and '
        "higher accuracy multiplies ALL your gains. Let's upgrade it step by "
        'step.',
  ),
  TutorialStep.neuralTapNeuron: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.neuralNeuron,
    requiredTab: TutorialTab.neural,
    title: 'TAP THE NEURON',
    body:
        'That glowing node is your first neuron. Tap it to open the upgrade '
        'panel.',
  ),
  TutorialStep.neuralUpgradeGradient: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.inSheet,
    requiredTab: TutorialTab.neural,
    title: 'UPGRADE THE GRADIENT',
    body:
        'Open the neuron and upgrade its GRADIENT. Higher gradient levels '
        'train the network faster.',
  ),
  TutorialStep.neuralChangeActivation: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.inSheet,
    requiredTab: TutorialTab.neural,
    title: 'CHANGE THE ACTIVATION',
    body:
        'Open the neuron and change its ACTIVATION FUNCTION. Each layer has '
        'a preferred function that trains 10% faster.',
  ),
  TutorialStep.neuralBranchNeuron: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.inSheet,
    requiredTab: TutorialTab.neural,
    title: 'BRANCH THE NEURON',
    body:
        'Open the neuron and BRANCH it. Branching grows the network into a '
        'new layer — more neurons means faster training.',
  ),
  TutorialStep.neuralViewAccuracy: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.tapToContinue,
    target: TutorialTarget.neuralHud,
    requiredTab: TutorialTab.neural,
    title: 'ACCURACY & MULTIPLIER',
    body:
        'ACCURACY shows how well your network is trained. The MULT '
        'multiplier comes straight from it — the higher it climbs, the more '
        'every gain is boosted. It keeps training while you are away.',
  ),
  TutorialStep.neuralAccuracyLimit: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.tapToContinue,
    requiredTab: TutorialTab.neural,
    title: 'ALWAYS TRAINING',
    body:
        'Accuracy never reaches 100% — it only creeps closer. Keep growing '
        'the pyramid. Train it well enough and you can start an Epoch, and '
        'later prestiges open layers deeper than the pyramid itself.',
  ),

  // ── Late game ────────────────────────────────────────────────────────────
  TutorialStep.tipDeepLayers: TutorialStepSpec(
    scope: TutorialScope.tips,
    mode: TutorialMode.tapToContinue,
    kicker: 'DEEPER',
    title: 'DEEP LAYERS',
    body:
        'Your network can now grow past the pyramid. Branch into the new '
        'deep layer on NEURAL — deep neurons cost more but raise the '
        'multiplier ceiling. More prestiges open more of them.',
  ),
  TutorialStep.tipEpoch: TutorialStepSpec(
    scope: TutorialScope.tips,
    mode: TutorialMode.tapToContinue,
    kicker: 'DEEPER',
    title: 'EPOCH READY',
    body:
        'Your network is trained well enough to start an Epoch. It resets '
        'training and gradients but keeps every neuron, and each Epoch adds '
        '+10% to all production — permanently.',
  ),

  TutorialStep.done: TutorialStepSpec(
    scope: TutorialScope.none,
    mode: TutorialMode.floatingHint,
  ),
};

TutorialStepSpec specFor(TutorialStep step) =>
    tutorialSpecs[step] ?? tutorialSpecs[TutorialStep.done]!;
