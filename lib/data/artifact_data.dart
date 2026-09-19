import 'dart:math' as math;

import '../models/artifact.dart';

/// Every artifact and its effect curve. Each formula takes the artifact's
/// level, where 0 means not owned and must return the neutral value.
class Artifacts {
  static const String chronoLens = 'chrono_lens';
  static const String echoChamber = 'echo_chamber';
  static const String titheEngine = 'tithe_engine';
  static const String genesisKit = 'genesis_kit';
  static const String perpetualMotion = 'perpetual_motion';
  static const String loadedDice = 'loaded_dice';
  static const String overclockCore = 'overclock_core';
  static const String synapseCrown = 'synapse_crown';
  static const String compoundVault = 'compound_vault';
  static const String tempoAnchor = 'tempo_anchor';
  static const String resonancePrism = 'resonance_prism';
  static const String milestoneCompass = 'milestone_compass';

  // ── Effect curves ──────────────────────────────────────────────────────

  static double chronoCapBonusHours(int l) => l <= 0 ? 0 : 4.0 + (l - 1);
  static double chronoOfflineMultiplier(int l) =>
      l <= 0 ? 1.0 : 1.2 + 0.05 * (l - 1);

  static const int echoInterval = 50;
  static const int echoWindow = 10;
  static double echoShare(int l) => l <= 0 ? 0.0 : 1.0 + 0.1 * (l - 1);

  static double titheBonusPerArtifact(int l) =>
      l <= 0 ? 0.0 : 0.03 + 0.005 * (l - 1);

  static const List<String> genesisKitTiers = [
    'idle_auto_clicker',
    'idle_quantum_multiplier',
    'idle_fractal_engine',
  ];
  static int genesisStartLevel(int l) =>
      l <= 0 ? 0 : math.min(100, 10 + 2 * (l - 1));

  static double momentumFloor(int l) =>
      l <= 0 ? 0.0 : math.min(0.9, 0.4 + 0.03 * (l - 1));

  static const double baseStrikeChance = 0.05;
  static double strikeChance(int l) =>
      l <= 0 ? baseStrikeChance : math.min(0.15, 0.08 + 0.0025 * (l - 1));
  static double strikeChainChance(int l) => l <= 0 ? 0.0 : 0.25;

  /// Seconds between automatic Overclocks, or null when not owned.
  static int? overclockCoreInterval(int l) =>
      l <= 0 ? null : math.max(300, 900 - 30 * (l - 1));

  static double synapseCostFactor(int l) =>
      l <= 0 ? 1.0 : math.max(0.4, 0.75 * math.pow(0.97, l - 1).toDouble());
  static double synapsePreferredBonus(int l) => l <= 0 ? 1.10 : 1.25;

  static const int compoundIntervalSeconds = 60;
  static double compoundShare(int l) =>
      l <= 0 ? 0.0 : math.min(0.03, 0.005 + 0.001 * (l - 1));
  static double compoundCapMinutes(int l) => l <= 0 ? 0.0 : 5.0 + (l - 1);

  static double tempoCooldownFactor(int l) =>
      l <= 0 ? 1.0 : 1.0 - math.min(0.7, 0.25 + 0.03 * (l - 1));
  static double tempoDurationFactor(int l) =>
      l <= 0 ? 1.0 : 1.5 + 0.05 * (l - 1);
  static const int tempoCooldownFloorSeconds = 40;

  static double prismPerMaxedNode(int l) =>
      l <= 0 ? 0.0 : 0.03 + 0.005 * (l - 1);

  static double milestoneBase(int l) =>
      l <= 0 ? 2.0 : math.min(2.6, 2.2 + 0.02 * (l - 1));

  // ── Catalog ────────────────────────────────────────────────────────────

  static String _pct(double v) {
    final p = v * 100;
    return p == p.roundToDouble()
        ? '${p.toStringAsFixed(0)}%'
        : '${p.toStringAsFixed(1)}%';
  }

  static final List<ArtifactDef> all = [
    ArtifactDef(
      id: chronoLens,
      name: 'Chrono Lens',
      tagline: 'Time away is never wasted.',
      describe: (l) =>
          'Offline cap +${chronoCapBonusHours(l).toStringAsFixed(0)}h, '
          'offline gains ×${chronoOfflineMultiplier(l).toStringAsFixed(2)}',
    ),
    ArtifactDef(
      id: echoChamber,
      name: 'Echo Chamber',
      tagline: 'Your taps come back around.',
      describe: (l) =>
          'Every ${echoInterval}th tap also pays ${_pct(echoShare(l))} of '
          'your last $echoWindow taps',
    ),
    ArtifactDef(
      id: titheEngine,
      name: 'Tithe Engine',
      tagline: 'Every relic pays its dues.',
      describe: (l) =>
          '+${_pct(titheBonusPerArtifact(l))} PP from prestige per artifact owned',
    ),
    ArtifactDef(
      id: genesisKit,
      name: 'Genesis Kit',
      tagline: 'Never start from nothing again.',
      describe: (l) =>
          'After prestige, your first 3 idle tiers start at Lv ${genesisStartLevel(l)}',
    ),
    ArtifactDef(
      id: perpetualMotion,
      name: 'Perpetual Motion',
      tagline: 'Momentum that refuses to die.',
      describe: (l) =>
          'Momentum never falls below ${_pct(momentumFloor(l))} of its cap',
    ),
    ArtifactDef(
      id: loadedDice,
      name: 'Loaded Dice',
      tagline: 'Luck, engineered.',
      describe: (l) => 'Strike chance ${_pct(strikeChance(l))}, '
          '${_pct(strikeChainChance(l))} chance a strike chains',
    ),
    ArtifactDef(
      id: overclockCore,
      name: 'Overclock Core',
      tagline: 'The machine overclocks itself.',
      describe: (l) => 'Overclock fires on its own every '
          '${(overclockCoreInterval(l)! / 60).toStringAsFixed(1)} min',
    ),
    ArtifactDef(
      id: synapseCrown,
      name: 'Synapse Crown',
      tagline: 'A mind built cheaper and sharper.',
      describe: (l) =>
          'Neural costs −${_pct(1 - synapseCostFactor(l))}, preferred '
          'activation bonus ×${synapsePreferredBonus(l).toStringAsFixed(2)}',
    ),
    ArtifactDef(
      id: compoundVault,
      name: 'Compound Vault',
      tagline: 'Wealth that breeds wealth.',
      describe: (l) =>
          'Every ${compoundIntervalSeconds}s gain ${_pct(compoundShare(l))} of '
          'your number (max ${compoundCapMinutes(l).toStringAsFixed(0)} min of idle)',
    ),
    ArtifactDef(
      id: tempoAnchor,
      name: 'Tempo Anchor',
      tagline: 'Collapse time more often, for longer.',
      describe: (l) =>
          'Temporal Collapse cooldown −${_pct(1 - tempoCooldownFactor(l))}, '
          'duration ×${tempoDurationFactor(l).toStringAsFixed(2)}',
    ),
    ArtifactDef(
      id: resonancePrism,
      name: 'Resonance Prism',
      tagline: 'Mastery refracts into power.',
      describe: (l) =>
          '+${_pct(prismPerMaxedNode(l))} all production per maxed Nexus node',
    ),
    ArtifactDef(
      id: milestoneCompass,
      name: 'Milestone Compass',
      tagline: 'Every milestone hits harder.',
      describe: (l) =>
          'Upgrade milestones multiply by ×${milestoneBase(l).toStringAsFixed(2)} instead of ×2',
    ),
  ];

  static List<String> get allIds => [for (final a in all) a.id];

  static ArtifactDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
