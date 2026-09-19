import '../logic/game_state.dart';
import '../models/achievement.dart';

/// Every achievement in the game. Each one unlocked adds
/// [Achievements.bonusPerAchievement] to all production.
class Achievements {
  static const double bonusPerAchievement = 0.01;

  // Event achievements, unlocked by GameState where they happen.
  static const String firstStrike = 'first_strike';
  static const String firstOverclock = 'first_overclock';
  static const String firstCollapse = 'first_collapse';
  static const String maxMomentum = 'max_momentum';
  static const String longAbsence = 'long_absence';
  static const String sparkCatcher = 'spark_catcher';
  static const String firstEpoch = 'epoch_1';

  static const List<String> idleTierIds = [
    'idle_auto_clicker',
    'idle_quantum_multiplier',
    'idle_fractal_engine',
    'idle_singularity_core',
    'idle_tesseract_array',
    'idle_entropy_harvester',
    'idle_void_resonance',
  ];

  static AchievementDef _number(String id, String title, int exponent) =>
      AchievementDef(
        id: id,
        category: AchievementCategory.numbers,
        title: title,
        description: 'Reach 1e$exponent.',
        isMet: (s) => s.highestNumber >= BigInt.from(10).pow(exponent),
      );

  static AchievementDef _clicks(String id, String title, int count) =>
      AchievementDef(
        id: id,
        category: AchievementCategory.clicks,
        title: title,
        description: 'Tap $count times in total.',
        isMet: (s) => s.lifetimeClicks >= count,
      );

  static AchievementDef _prestige(String id, String title, int count) =>
      AchievementDef(
        id: id,
        category: AchievementCategory.prestige,
        title: title,
        description: 'Prestige $count ${count == 1 ? 'time' : 'times'}.',
        isMet: (s) => s.prestigeCount >= count,
      );

  static int _totalUpgradeLevels(GameState s) =>
      s.upgrades.fold<int>(0, (sum, u) => sum + u.level);

  static int _neuronCount(GameState s) =>
      s.neuralNetwork.layers.fold<int>(0, (sum, l) => sum + l.neurons.length);

  static final List<AchievementDef> all = [
    _number('num_1k', 'First Steps', 3),
    _number('num_1m', 'Millionaire', 6),
    _number('num_1b', 'Billionaire', 9),
    _number('num_1t', 'Trillionaire', 12),
    _number('num_1qa', 'Quadrillion', 15),
    _number('num_1qi', 'Quintillion', 18),
    _number('num_1sp', 'Septillion', 24),
    _number('num_1no', 'Nonillion', 30),
    _clicks('clicks_100', 'Warm Up', 100),
    _clicks('clicks_1k', 'Tapper', 1000),
    _clicks('clicks_10k', 'Relentless', 10000),
    _clicks('clicks_100k', 'Unstoppable Finger', 100000),
    AchievementDef(
      id: 'first_idle',
      category: AchievementCategory.upgrades,
      title: 'Automation',
      description: 'Buy your first Auto-Clicker.',
      isMet: (s) =>
          s.upgrades.any((u) => u.id == GameState.autoClickerId && u.level > 0),
    ),
    AchievementDef(
      id: 'all_idle_tiers',
      category: AchievementCategory.upgrades,
      title: 'Full Stack',
      description: 'Own every idle tier at once.',
      isMet: (s) => idleTierIds
          .every((id) => s.upgrades.any((u) => u.id == id && u.level > 0)),
    ),
    AchievementDef(
      id: 'upgrade_lv100',
      category: AchievementCategory.upgrades,
      title: 'Specialist',
      description: 'Get any upgrade to level 100.',
      isMet: (s) => s.upgrades.any((u) => u.level >= 100),
    ),
    AchievementDef(
      id: 'total_levels_500',
      category: AchievementCategory.upgrades,
      title: 'Investor',
      description: 'Hold 500 upgrade levels in one run.',
      isMet: (s) => _totalUpgradeLevels(s) >= 500,
    ),
    AchievementDef(
      id: 'total_levels_2000',
      category: AchievementCategory.upgrades,
      title: 'Tycoon',
      description: 'Hold 2,000 upgrade levels in one run.',
      isMet: (s) => _totalUpgradeLevels(s) >= 2000,
    ),
    _prestige('prestige_1', 'Rebirth', 1),
    _prestige('prestige_5', 'Cycle Breaker', 5),
    _prestige('prestige_10', 'Ascendant', 10),
    _prestige('prestige_20', 'Eternal Return', 20),
    _prestige('prestige_30', 'Ouroboros', 30),
    _prestige('prestige_50', 'Beyond Recursion', 50),
    AchievementDef(
      id: 'nexus_stabilized',
      category: AchievementCategory.nexus,
      title: 'Stabilized',
      description: 'Stabilize the Nexus.',
      isMet: (s) => s.nexusStabilized,
    ),
    AchievementDef(
      id: 'nexus_first_node',
      category: AchievementCategory.nexus,
      title: 'Researcher',
      description: 'Research your first Nexus node.',
      isMet: (s) => s.researchNodes.any((n) => n.level > 0),
    ),
    AchievementDef(
      id: 'nexus_max_node',
      category: AchievementCategory.nexus,
      title: 'Mastery',
      description: 'Max out any Nexus node.',
      isMet: (s) => s.researchNodes.any((n) => n.isMaxed),
    ),
    AchievementDef(
      id: 'nexus_complete',
      category: AchievementCategory.nexus,
      title: 'Omniscient',
      description: 'Max out the entire Nexus tree.',
      isMet: (s) => s.researchNodes.every((n) => n.isMaxed),
    ),
    AchievementDef(
      id: 'neural_genesis',
      category: AchievementCategory.nexus,
      title: 'Spark of Mind',
      description: 'Unlock the neural network.',
      isMet: (s) => s.neuralNetworkUnlocked,
    ),
    AchievementDef(
      id: 'neural_first_branch',
      category: AchievementCategory.neural,
      title: 'Synapse',
      description: 'Branch your first neuron.',
      isMet: (s) => s.neuralNetwork.layers.length >= 2,
    ),
    AchievementDef(
      id: 'neural_pyramid',
      category: AchievementCategory.neural,
      title: 'The Pyramid',
      description: 'Complete the 22-neuron pyramid.',
      isMet: (s) => _neuronCount(s) >= 22,
    ),
    AchievementDef(
      id: 'neural_deep',
      category: AchievementCategory.neural,
      title: 'Going Deeper',
      description: 'Grow your first deep layer.',
      isMet: (s) => s.neuralNetwork.deepLayerCount > 0,
    ),
    AchievementDef(
      id: 'neural_deep_complete',
      category: AchievementCategory.neural,
      title: 'Abyssal Mind',
      description: 'Grow all 31 neurons.',
      isMet: (s) => _neuronCount(s) >= 31,
    ),
    AchievementDef(
      id: 'acc_90',
      category: AchievementCategory.neural,
      title: 'Learning',
      description: 'Reach 90% accuracy.',
      isMet: (s) => s.neuralNetworkUnlocked && s.neuralNetwork.accuracy >= 0.90,
    ),
    AchievementDef(
      id: 'acc_99',
      category: AchievementCategory.neural,
      title: 'Converged',
      description: 'Reach 99% accuracy.',
      isMet: (s) => s.neuralNetworkUnlocked && s.neuralNetwork.accuracy >= 0.99,
    ),
    AchievementDef(
      id: 'acc_999',
      category: AchievementCategory.neural,
      title: 'Overfit',
      description: 'Reach 99.9% accuracy.',
      isMet: (s) =>
          s.neuralNetworkUnlocked && s.neuralNetwork.accuracy >= 0.999,
    ),
    const AchievementDef(
      id: firstEpoch,
      category: AchievementCategory.neural,
      title: 'New Epoch',
      description: 'Send the network into its first Epoch.',
    ),
    AchievementDef(
      id: 'epoch_5',
      category: AchievementCategory.neural,
      title: 'Veteran Network',
      description: 'Complete 5 Epochs.',
      isMet: (s) => s.neuralNetwork.epochs >= 5,
    ),
    const AchievementDef(
      id: firstStrike,
      category: AchievementCategory.mechanics,
      title: 'Lucky Strike',
      description: 'Land a Probability Strike.',
    ),
    const AchievementDef(
      id: firstOverclock,
      category: AchievementCategory.mechanics,
      title: 'Overclocked',
      description: 'Trigger Overclock.',
    ),
    const AchievementDef(
      id: firstCollapse,
      category: AchievementCategory.mechanics,
      title: 'Time Bender',
      description: 'Activate Temporal Collapse.',
    ),
    const AchievementDef(
      id: maxMomentum,
      category: AchievementCategory.mechanics,
      title: 'Full Momentum',
      description: 'Fill the momentum bar completely.',
    ),
    AchievementDef(
      id: 'artifact_first',
      category: AchievementCategory.artifacts,
      title: 'Relic Hunter',
      description: 'Claim your first artifact.',
      isMet: (s) => s.artifactState.ownedCount >= 1,
    ),
    AchievementDef(
      id: 'artifact_8',
      category: AchievementCategory.artifacts,
      title: 'Curator',
      description: 'Own 8 artifacts.',
      isMet: (s) => s.artifactState.ownedCount >= 8,
    ),
    AchievementDef(
      id: 'artifact_lv10',
      category: AchievementCategory.artifacts,
      title: 'Empowered',
      description: 'Empower any artifact to level 10.',
      isMet: (s) => s.artifactState.highestLevel >= 10,
    ),
    const AchievementDef(
      id: longAbsence,
      category: AchievementCategory.secret,
      title: 'The Long Sleep',
      description: 'Come back after 8 hours away.',
      hidden: true,
    ),
    const AchievementDef(
      id: sparkCatcher,
      category: AchievementCategory.secret,
      title: 'Spark Catcher',
      description: 'Catch a Neural Spark.',
      hidden: true,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
