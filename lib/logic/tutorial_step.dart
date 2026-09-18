/// Ordered steps for the first-time interactive tutorial.
enum TutorialStep {
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

  /// ── Upgrade deep-dive tutorial (fires after prestige, before goodLuck) ──
  upgradeIntro,
  probabilityStrikeIntro,
  buyProbabilityStrike,
  navGeneratorsForStrike,
  triggerProbabilityStrike,
  navUpgradesForMomentum,
  momentumIntro,
  buyMomentum,
  navGeneratorsForMomentum,
  demonstrateMomentum,
  navUpgradesForSpecial,
  kineticSynergyIntro,
  overclockIntro,
  upgradesDone,

  /// Tutorial finished or skipped — overlay hidden.
  done,
}

/// Which of the four tutorials a step belongs to.
///
/// SKIP needs this: skipping out of the upgrade deep-dive used to jump to
/// `learnPrestige` rather than ending, so the player had to press SKIP up to
/// four times to actually escape.
enum TutorialScope { main, nexus, neural, upgrades, none }

/// How the overlay renders a step.
///
/// Replaces three hand-maintained boolean sets (`isTapToContinue`,
/// `isWatchIdle`, `isNavStep`). A step missing from all three, or listed in
/// the wrong one, used to silently produce a broken frame — no dim, no card,
/// or no way out.
enum TutorialMode {
  /// Full dim, advances on a tap anywhere.
  tapToContinue,

  /// Dim with a hole over the target; only the target is tappable. Advances
  /// when the player performs the action.
  spotlightAction,

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

/// Named UI target, resolved to a GlobalKey by the overlay via a registry
/// owned by MainLayout. Replaces hardcoded `navKeys[1]` / `navKeys[3]`
/// indices scattered through a 39-case switch.
enum TutorialTarget {
  tapArea,
  navGenerators,
  navUpgrades,
  navPrestige,
  navNeural,
  idleCategory,
  prestigeMultiplier,
  prestigeGainCard,
  momentumBar,
  neuralNeuron,
  neuralHud,
  upgradeAutoClicker,
  upgradeClickPower,
  upgradeProbabilityStrike,
  upgradeMomentum,
  upgradeKineticSynergy,
  upgradeOverclock,
}

/// Tab indices in MainLayout's screen list.
abstract class TutorialTab {
  static const int generators = 0;
  static const int upgrades = 1;
  static const int prestige = 2;
  static const int neural = 3;
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

  /// Upgrade category that must be selected for [target] to exist.
  final String? requiredCategory;

  final String? title;
  final String? body;

  /// Overrides the default "TAP ANYWHERE TO CONTINUE" hint.
  final String? continueHint;

  const TutorialStepSpec({
    required this.scope,
    required this.mode,
    this.target,
    this.requiredTab,
    this.requiredCategory,
    this.title,
    this.body,
    this.continueHint,
  });

  bool get isTapToContinue => mode == TutorialMode.tapToContinue;

  /// Every step must be escapable. There is no `allowSkip: false` — a step
  /// with no way out is the single worst failure mode this system has.
  bool get hasCopy => title != null && body != null;
}

const String _clickCategory = 'click';
const String _idleCategory = 'idle';

/// The single source of truth for step behaviour.
///
/// `test/tutorial_spec_test.dart` asserts this covers every [TutorialStep]
/// except [TutorialStep.done], that every spotlight step names a target, and
/// that every step either has copy or is explicitly [TutorialMode.inSheet].
const Map<TutorialStep, TutorialStepSpec> tutorialSpecs = {
  // ── Main onboarding ──────────────────────────────────────────────────────
  TutorialStep.welcome: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    title: 'WELCOME TO NUMBER',
    body:
        'Your goal: collect the biggest number possible. Tap the play field to generate numbers, spend them on upgrades to grow faster, and prestige for permanent multipliers.',
  ),
  TutorialStep.clickToFifty: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.tapArea,
    requiredTab: TutorialTab.generators,
    title: 'GENERATORS',
    body:
        'Tap anywhere on the play field to generate numbers! Every tap adds to your count. Keep clicking to afford your first upgrade.',
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
        "Switch to the IDLE tab. Idle upgrades generate numbers automatically — even when you're not tapping.",
  ),
  TutorialStep.buyAutoClicker: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeAutoClicker,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _idleCategory,
    title: 'AUTO-CLICKER',
    body:
        'Buy the Auto-Clicker! Each level adds +1 number per second automatically.',
  ),
  TutorialStep.navGenerators: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'SEE IT WORK',
    body:
        'Great purchase! Head back to GENERATORS and watch your numbers climb on their own.',
  ),
  TutorialStep.watchIdle: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'IDLE INCOME',
    body:
        'Your numbers are growing by themselves now. You can still click for extra gains. Keep going!',
  ),
  TutorialStep.navUpgradesForClick: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'POWER UP YOUR CLICKS',
    body:
        "Nice grind! Head to UPGRADES again — this time we'll boost your click power.",
  ),
  TutorialStep.buyClickPower: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeClickPower,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'CLICK POWER',
    body:
        'Buy Click Power! Each level increases how much every tap earns you.',
  ),

  // ── Upgrade deep-dive (runs between buyClickPower and learnPrestige) ─────
  TutorialStep.upgradeIntro: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.tapToContinue,
    title: 'EXPLORE SPECIAL UPGRADES',
    body:
        "You've been given a budget to experiment with! Let's explore some powerful upgrades and see them in action.",
  ),
  TutorialStep.probabilityStrikeIntro: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.tapToContinue,
    title: 'PROBABILITY STRIKE',
    body:
        "Each click has a 5% chance to trigger a massive strike! The damage spikes are huge. Let's buy it and see strikes happen.",
  ),
  TutorialStep.buyProbabilityStrike: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeProbabilityStrike,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY IT',
    body: 'Tap Probability Strike to purchase a level.',
  ),
  TutorialStep.navGeneratorsForStrike: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'GO CLICK',
    body:
        'Head back to GENERATORS and click multiple times. Watch for those huge damage spikes!',
  ),
  TutorialStep.triggerProbabilityStrike: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.floatingHint,
    requiredTab: TutorialTab.generators,
    title: 'KEEP CLICKING',
    body:
        'Click rapidly — every click has a 5% chance to trigger a massive strike. Watch those numbers explode!',
  ),
  TutorialStep.navUpgradesForMomentum: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'NICE STRIKE!',
    body:
        "You saw it! Now head to UPGRADES below — there's another upgrade that multiplies your damage the more you click.",
  ),
  TutorialStep.momentumIntro: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.tapToContinue,
    title: 'MOMENTUM',
    body:
        "Each click builds a combo — your damage grows faster and faster as your streak continues. Let's buy it and watch the momentum bar climb.",
  ),
  TutorialStep.buyMomentum: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.spotlightAction,
    target: TutorialTarget.upgradeMomentum,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'BUY MOMENTUM',
    body: 'Tap Momentum to purchase a level.',
  ),
  TutorialStep.navGeneratorsForMomentum: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navGenerators,
    title: 'GO CLICK!',
    body:
        'Head to GENERATORS and click rapidly. Watch the momentum bar climb — the faster you click, the higher your multiplier!',
  ),
  TutorialStep.demonstrateMomentum: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.momentumBar,
    requiredTab: TutorialTab.generators,
    title: 'WATCH IT GROW',
    body:
        'Click rapidly and watch the momentum bar above climb! The faster you click, the higher it climbs.',
  ),
  TutorialStep.navUpgradesForSpecial: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navUpgrades,
    title: 'BACK TO UPGRADES',
    body: "Head to UPGRADES tab. We'll show you two more powerful upgrades.",
  ),
  TutorialStep.kineticSynergyIntro: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.tapToContinue,
    target: TutorialTarget.upgradeKineticSynergy,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'KINETIC SYNERGY',
    body:
        'Each level adds 1% of your idle income to your clicks. This bridges idle and clicking together — they work as one!',
  ),
  TutorialStep.overclockIntro: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.tapToContinue,
    target: TutorialTarget.upgradeOverclock,
    requiredTab: TutorialTab.upgrades,
    requiredCategory: _clickCategory,
    title: 'OVERCLOCK',
    body:
        'Click fast enough and trigger a power surge that doubles your click power! This is your reward for intense clicking.',
  ),
  TutorialStep.upgradesDone: TutorialStepSpec(
    scope: TutorialScope.upgrades,
    mode: TutorialMode.tapToContinue,
    title: 'MASTERY UNLOCKED',
    body:
        "You've explored all the special upgrades! Your experiment budget is returned now — time to play for real and climb the ranks.",
  ),

  // ── Prestige tail ────────────────────────────────────────────────────────
  TutorialStep.learnPrestige: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    title: 'PRESTIGE',
    body:
        'Reset your progress to earn a permanent multiplier that boosts all future gains. Each prestige makes the next multiplier stronger!',
    continueHint: 'TAP ANYWHERE TO START PLAYING',
  ),
  TutorialStep.navPrestige: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.navPrestige,
    title: 'TIME TO PRESTIGE',
    body:
        'Open the PRESTIGE tab to start your first prestige and unlock the Nexus.',
  ),
  TutorialStep.learnPrestigeDetails: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    requiredTab: TutorialTab.prestige,
    title: 'HOW PRESTIGE WORKS',
    body:
        'Reset your current run to earn a permanent Prestige Multiplier. This multiplier applies to ALL future gains — it grows stronger with each prestige!',
  ),
  TutorialStep.prestigeMultiplierHint: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    target: TutorialTarget.prestigeMultiplier,
    requiredTab: TutorialTab.prestige,
    title: 'YOUR PRESTIGE MULTIPLIER',
    body:
        'This is your permanent boost that multiplies everything: clicks, idle gains, and upgrades. The more you prestige, the larger this multiplier becomes.',
  ),
  TutorialStep.prestigeGainHint: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    target: TutorialTarget.prestigeGainCard,
    requiredTab: TutorialTab.prestige,
    title: 'PRESTIGE COST & GAIN',
    body:
        'You need to reach the "Required number" shown here. Each prestige raises that requirement, and raises your reward too.',
  ),
  TutorialStep.goodLuck: TutorialStepSpec(
    scope: TutorialScope.main,
    mode: TutorialMode.tapToContinue,
    requiredTab: TutorialTab.generators,
    title: "YOU'RE READY!",
    body:
        "You've learned the basics. Now go grind, prestige, and climb the leaderboards. Good luck!",
  ),

  // ── Nexus tutorial ───────────────────────────────────────────────────────
  TutorialStep.nexusIntro: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.tapToContinue,
    title: 'THE NEXUS',
    body:
        'You stabilized the Nexus — your hub for permanent upgrades. Each prestige earns Prestige Points (PP); spend them on research that survives every reset.',
  ),
  TutorialStep.nexusUpgrades: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.tapToContinue,
    title: 'PERMANENT RESEARCH',
    body:
        'Tap a node to spend PP. Tier I (Optimization, Surge, Enhanced Extraction) opens Tier II (Idle Foundation, Quick Resume, Kinetic Surge), then Tier III (Resonance Core, Echo Protocol). Each level stacks forever.',
  ),
  TutorialStep.nexusGoal: TutorialStepSpec(
    scope: TutorialScope.nexus,
    mode: TutorialMode.tapToContinue,
    title: 'YOUR GOAL',
    body:
        'Climb the tree all the way down to Neural Genesis. Unlocking it awakens the Neural Network — the deepest layer of the game.',
  ),

  // ── Neural tutorial ──────────────────────────────────────────────────────
  TutorialStep.neuralUnlocked: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.tapToContinue,
    title: 'NEURAL GENESIS',
    body:
        "Neural Genesis is online — your first neuron just spawned. Let's take a quick tour of the most complex system in the game.",
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
        "This is your neural network. As it trains, accuracy rises — and higher accuracy multiplies ALL your gains. Let's upgrade it step by step.",
  ),
  TutorialStep.neuralTapNeuron: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.passthroughHint,
    target: TutorialTarget.neuralNeuron,
    requiredTab: TutorialTab.neural,
    title: 'TAP THE NEURON',
    body: 'That glowing node is your first neuron. Tap it to open the upgrade panel.',
  ),
  TutorialStep.neuralUpgradeGradient: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.inSheet,
    requiredTab: TutorialTab.neural,
    title: 'UPGRADE THE GRADIENT',
    body:
        'Tap the neuron again and upgrade its GRADIENT. Higher gradient levels train the network faster.',
  ),
  TutorialStep.neuralChangeActivation: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.inSheet,
    requiredTab: TutorialTab.neural,
    title: 'CHANGE THE ACTIVATION',
    body:
        'Tap the neuron again and change its ACTIVATION FUNCTION. Each layer has a preferred function that trains 10% faster.',
  ),
  TutorialStep.neuralBranchNeuron: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.inSheet,
    requiredTab: TutorialTab.neural,
    title: 'BRANCH THE NEURON',
    body:
        'Tap the neuron again and BRANCH it. Branching grows the network into a new layer — more neurons means faster training.',
  ),
  TutorialStep.neuralViewAccuracy: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.tapToContinue,
    target: TutorialTarget.neuralHud,
    requiredTab: TutorialTab.neural,
    title: 'ACCURACY & MULTIPLIER',
    body:
        'ACCURACY shows how well your network is trained. The MULT multiplier is derived directly from accuracy — the higher it climbs, the more all your gains are boosted.',
  ),
  TutorialStep.neuralAccuracyLimit: TutorialStepSpec(
    scope: TutorialScope.neural,
    mode: TutorialMode.tapToContinue,
    requiredTab: TutorialTab.neural,
    title: 'ALWAYS TRAINING',
    body:
        'Accuracy can never reach 100% — it approaches the limit asymptotically. Even 95% accuracy yields a massive multiplier. Keep upgrading neurons and branching layers to train faster.',
  ),

  TutorialStep.done: TutorialStepSpec(
    scope: TutorialScope.none,
    mode: TutorialMode.floatingHint,
  ),
};

TutorialStepSpec specFor(TutorialStep step) =>
    tutorialSpecs[step] ?? tutorialSpecs[TutorialStep.done]!;
