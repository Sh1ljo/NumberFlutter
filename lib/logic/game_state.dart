import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/upgrade.dart';
import '../models/research_node.dart';
import '../models/player_progress.dart';
import '../data/nexus_data.dart';
import '../data/achievement_data.dart';
import '../data/artifact_data.dart';
import '../models/artifact.dart';
import '../models/neural_network.dart';
import '../models/upgrade_recommendation.dart';
import '../models/shop_product.dart';
import '../data/shop_catalog.dart';
import 'connectivity_service.dart';
import 'shop_inventory.dart';
import 'storage_service.dart';
import 'sync_service.dart';
import 'backend_service.dart';
import '../utils/big_number.dart';
import 'tutorial_step.dart';

class GameState extends ChangeNotifier with WidgetsBindingObserver {
  static const String clickCategory = 'click';
  static const String idleCategory = 'idle';
  static const List<int> upgradeMilestoneThresholds = [
    25,
    50,
    100,
    250,
    500,
    1000,
  ];

  static const String probabilityStrikeId = 'click_probability_strike';
  static const String momentumId = 'click_momentum';
  static const String kineticSynergyId = 'click_kinetic_synergy';
  static const String overclockId = 'click_overclock';
  static const String clickPowerId = 'click_power';
  static const String autoClickerId = 'idle_auto_clicker';
  static const String quantumMultiplierId = 'idle_quantum_multiplier';
  static const String dimensionalTapId = 'click_dimensional_tap';
  static const String cascadeResonatorId = 'idle_cascade_resonator';
  static const String temporalCollapseId = 'click_temporal_collapse';

  final StorageService _storageService = StorageService();
  final SyncService _syncService = SyncService();
  final Completer<void> _readyCompleter = Completer<void>();
  final math.Random _rng = math.Random();

  Future<void> get ready => _readyCompleter.future;

  BigInt number = BigInt.zero;
  BigInt clickPower = BigInt.from(productionBaseClickPower);
  Object _prestigeCurrency = 0.0;

  bool _testEnvironmentEnabled = false;
  bool get testEnvironmentEnabled => _testEnvironmentEnabled;
  double get prestigeCurrency {
    final value = _prestigeCurrency;
    if (value is num) return value.toDouble();
    if (value is BigInt) return value.toDouble();
    return 0.0;
  }

  set prestigeCurrency(double value) {
    _prestigeCurrency = value;
  }

  /// Starts at 1.0; each prestige adds a small increment that scales with progress.
  double prestigeMultiplier = 1.0;

  /// How many prestiges completed (used for incremental gains).
  int prestigeCount = 0;

  /// Whether the nexus has been stabilized (persisted).
  bool _nexusStabilized = false;
  bool get nexusStabilized => _nexusStabilized;

  /// True once the player has crossed the Nexus unlock threshold but hasn't
  /// stabilized it yet. Mirrors the gate in UnstabilizedView so UI and logic
  /// can't drift apart.
  bool get nexusReadyToStabilize => !_nexusStabilized && prestigeCount >= 3;

  int buyAmount = 1; // 1, 10, 100, -2 (NEXT), -1 (MAX)
  String selectedUpgradeCategory = clickCategory;

  double _idleAccumulator = 0.0;
  double autoClickRate = 0.0; // Per second Rate
  DateTime? _lastManualClickTime;
  int _clickStreak = 0;
  bool _overclockTriggeredThisChain = false;
  double _momentumMultiplier = 1.0;
  double _momentumProgress = 0.0;
  bool _overclockActive = false;
  bool _temporalCollapseActive = false;
  bool _temporalCollapseCoolingDown = false;

  /// Temporal Collapse doubles production while active. Kept as its own
  /// factor rather than written into [prestigeMultiplier]: that used to make
  /// the doubling permanent if the player prestiged or saved mid-window.
  double get _temporalCollapseFactor => _temporalCollapseActive ? 2.0 : 1.0;

  final List<double> _echoRecentGains = [];
  int _echoClickCounter = 0;
  double _overclockCoreElapsed = 0.0;
  double _compoundVaultElapsed = 0.0;

  BigInt offlineGainsThisSession = BigInt.zero;
  double offlineAccuracyGain = 0.0;
  BigInt highestNumber = BigInt.zero;
  DateTime? _lastSavedAt;
  DateTime? _lastCloudPushAt;

  /// Set when the save couldn't be loaded and the session started fresh.
  /// Until a sync succeeds, the fresh local game reports itself as older
  /// than anything in the cloud, so syncing restores the player's real
  /// progress instead of overwriting it.
  bool _loadFailed = false;

  /// Automatic pushes back off after failures. Every save used to retry a
  /// failed sync straight away, so offline play fired up to 3 network calls
  /// every 5s (and after every tap burst). Manual syncs ignore this.
  DateTime? _cloudRetryAfter;
  int _cloudFailureStreak = 0;
  static const Duration _cloudPushInterval = Duration(seconds: 20);
  static const Duration _cloudMaxBackoff = Duration(minutes: 5);
  bool _cloudSyncInProgress = false;
  String? _lastCloudSyncError;

  // ── Connectivity ──────────────────────────────────────────────────────
  StreamSubscription<bool>? _connectivitySub;
  bool _isOnline = true;
  bool _wasEverOffline = false;
  bool _justReconnected = false;

  bool isPrestigeAnimating = false;

  /// Which of PrestigeScreen's internal subtabs (0 = Prestige, 1 = Nexus) is
  /// showing. Transient UI state, not persisted — lets TutorialOverlay
  /// re-arm hole resolution when the player switches subtabs, since
  /// TabBarView only builds the visible page and MainLayout's own
  /// bottom-nav tab index never changes when this does.
  int prestigeSubTabIndex = 0;

  void setPrestigeSubTabIndex(int index) {
    if (prestigeSubTabIndex == index) return;
    prestigeSubTabIndex = index;
    notifyListeners();
  }

  bool get cloudSyncInProgress => _cloudSyncInProgress;
  String? get lastCloudSyncError => _lastCloudSyncError;
  bool get isOnline => _isOnline;

  /// One-shot: true exactly once, right after connectivity comes back and a
  /// reconnect attempt (and cloud sync, if signed in) has run.
  bool consumeJustReconnected() {
    final value = _justReconnected;
    _justReconnected = false;
    return value;
  }

  // ── Newly-unlocked upgrades ──────────────────────────────────────────────
  // Prestige-gated upgrades (see minPrestigeForUpgrade) become visible the
  // moment the player crosses their threshold. Queued here so the UI can pop
  // a "new upgrade" notice without polling the upgrade list every frame.
  final List<String> _pendingUnlockNotices = [];
  List<String> get pendingUnlockedUpgradeIds =>
      List.unmodifiable(_pendingUnlockNotices);
  void dismissUnlockNotice(String upgradeId) {
    _pendingUnlockNotices.remove(upgradeId);
  }

  // Upgrades the player has never bought (level 0) surface the same notice
  // the first moment their cost is affordable. Tracked separately so an
  // upgrade only ever announces itself once, even if the player's balance
  // dips back below its cost afterwards.
  final Set<String> _affordabilityNotified = {};

  List<ResearchNode> researchNodes = NexusData.allNodes();

  // ── Achievements ───────────────────────────────────────────────────────
  /// Manual taps across every run. Persisted; never reset by prestige.
  int lifetimeClicks = 0;
  final Set<String> _unlockedAchievements = {};
  final List<String> _pendingAchievementNotices = [];

  Set<String> get unlockedAchievements =>
      Set.unmodifiable(_unlockedAchievements);
  List<String> get pendingAchievementIds =>
      List.unmodifiable(_pendingAchievementNotices);
  void dismissAchievementNotice(String id) {
    _pendingAchievementNotices.remove(id);
  }

  /// Each unlocked achievement adds a flat 1% to all production.
  double get achievementBonus =>
      1.0 + _unlockedAchievements.length * Achievements.bonusPerAchievement;

  bool _unlockAchievement(String id) {
    if (!_unlockedAchievements.add(id)) return false;
    _pendingAchievementNotices.add(id);
    return true;
  }

  /// Polls every state-based achievement. Returns true if any unlocked.
  bool _checkAchievements() {
    var unlocked = false;
    for (final a in Achievements.all) {
      final check = a.isMet;
      if (check == null || _unlockedAchievements.contains(a.id)) continue;
      if (check(this) && _unlockAchievement(a.id)) unlocked = true;
    }
    if (unlocked) _scheduleStateSave();
    return unlocked;
  }

  // ── Artifacts ──────────────────────────────────────────────────────────
  ArtifactState artifactState = ArtifactState();

  int _artifactLevel(String id) => artifactState.levelOf(id);

  int get pendingArtifactChoices =>
      artifactState.pendingChoices(prestigeCount);

  /// The three artifacts on offer for the next unclaimed milestone.
  List<String>? get currentArtifactOffer =>
      artifactState.ensureOffer(prestigeCount, Artifacts.allIds);

  bool chooseArtifact(String id) {
    currentArtifactOffer;
    if (!artifactState.choose(id)) return false;
    _onArtifactsChanged();
    return true;
  }

  double empowerCostFor(String id) =>
      ArtifactState.empowerCost(_artifactLevel(id));

  bool empowerArtifact(String id) {
    final level = _artifactLevel(id);
    if (level <= 0) return false;
    final cost = ArtifactState.empowerCost(level);
    if (prestigeCurrency < cost) return false;
    prestigeCurrency -= cost;
    artifactState.levels[id] = level + 1;
    _onArtifactsChanged();
    return true;
  }

  void _onArtifactsChanged() {
    // Milestone Compass feeds click power / idle rate, Synapse Crown feeds
    // neural strength and costs.
    _recalculateDerivedStatsFromUpgrades();
    _neuralRevision++;
    _checkAchievements();
    notifyListeners();
    _saveState();
  }

  /// Resonance Prism: bonus per maxed Nexus node.
  double get resonancePrismMultiplier {
    final per = Artifacts.prismPerMaxedNode(
        _artifactLevel(Artifacts.resonancePrism));
    if (per <= 0) return 1.0;
    final maxed = researchNodes.where((n) => n.isMaxed).length;
    return 1.0 + per * maxed;
  }

  /// Everything that multiplies all production (idle and click) outside of
  /// the prestige multiplier: achievements, Resonance Prism, Epochs.
  double get globalProductionMultiplier =>
      achievementBonus * resonancePrismMultiplier * epochProductionMultiplier;

  NeuralNetwork neuralNetwork = NeuralNetwork.initial();
  bool get neuralNetworkUnlocked => _nexusLevel('neural_genesis') >= 1;

  // ── Tutorial ───────────────────────────────────────────────────────────
  TutorialStep _tutorialStep = TutorialStep.welcome;
  bool _tutorialCompleted = false;
  bool _tutorialNeedsCloudSync = false;
  // Later chapters run after chapter 1 ends. They reuse the same overlay and
  // step machine but each has its own "seen" flag so they fire exactly once
  // and don't roundtrip through cloud profile sync.
  bool _nexusTutorialSeen = false;
  bool _neuralTutorialSeen = false;
  bool _artifactTutorialSeen = false;

  /// One-shot chapters, tips and teasers already shown (or skipped), keyed
  /// by their first step.
  final Set<TutorialStep> _seenBeats = {};

  /// Milestones reached just before the most recent prestige, captured at
  /// prestige() time and consumed once the reveal animation finishes. Null
  /// when no prestige is pending a post-animation tutorial check.
  int? _artifactMilestonesBeforePrestige;
  VoidCallback? _onTutorialResetCallback;

  /// MainLayout tab on show, as reported through [onMainTabChanged]. Lets a
  /// "tap PRESTIGE below" step be skipped when the player is already there.
  int _mainTab = TutorialTab.generators;

  TutorialStep get tutorialStep => _tutorialStep;
  bool get tutorialCompleted => _tutorialCompleted;
  bool get isTutorialActive => _tutorialStep != TutorialStep.done;
  bool get nexusTutorialSeen => _nexusTutorialSeen;
  bool get neuralTutorialSeen => _neuralTutorialSeen;
  bool get artifactTutorialSeen => _artifactTutorialSeen;
  bool hasSeenTutorialBeat(TutorialStep step) => _seenBeats.contains(step);

  /// Test-only: jump straight to a step so the overlay's rendering for it can
  /// be exercised. Does not touch persistence.
  @visibleForTesting
  void debugSetTutorialStep(TutorialStep step) {
    _tutorialStep = step;
    // Only chapter 1 runs before the onboarding counts as finished.
    _tutorialCompleted = specFor(step).scope != TutorialScope.main;
    notifyListeners();
  }

  void registerTutorialResetCallback(VoidCallback cb) {
    _onTutorialResetCallback = cb;
  }

  /// Drop the callback when its owner is disposed. It is a single slot that
  /// captures a State's setState, so leaving it set retained the disposed
  /// MainLayout for the lifetime of the GameState.
  void unregisterTutorialResetCallback(VoidCallback cb) {
    if (_onTutorialResetCallback == cb) {
      _onTutorialResetCallback = null;
    }
  }

  void setPrestigeAnimating(bool value) {
    isPrestigeAnimating = value;
    // Prestige only fires partway through its reveal; the "DO IT" spotlight
    // must not sit dimmed over the animation until then.
    if (value && specFor(_tutorialStep).scope == TutorialScope.prestige) {
      _seenBeats.add(TutorialStep.prestigeReady);
      _tutorialStep = TutorialStep.done;
    }
    if (!value) _maybeStartPostPrestigeTutorial();
    notifyListeners();
  }

  void setTestEnvironmentEnabled(bool value) {
    if (_testEnvironmentEnabled == value) return;
    _testEnvironmentEnabled = value;
    _recalculateDerivedStatsFromUpgrades();
    notifyListeners();
    _saveState();
  }

  /// When the STABILIZE animation started, or null. Transient.
  DateTime? _nexusStabilizeStartedAt;

  /// Longer than the stabilize animation. If its screen is left mid-way the
  /// animation never reports back, so this can't be left set forever.
  static const Duration _nexusStabilizeGrace = Duration(seconds: 10);

  /// True while the stabilize animation plays. Popups and tutorial cards
  /// hold off rather than land on top of it.
  bool get isNexusStabilizing {
    final started = _nexusStabilizeStartedAt;
    return started != null &&
        DateTime.now().difference(started) < _nexusStabilizeGrace;
  }

  void stabilizeNexus() {
    _nexusStabilized = true;
    _nexusStabilizeStartedAt = null;
    _seenBeats.add(TutorialStep.nexusAwakens);
    // A tip that popped up during the stabilize animation gives way: it is
    // not marked seen, so it simply comes back later. The Nexus chapter
    // only ever gets this one chance.
    if (!_nexusTutorialSeen &&
        (_tutorialStep == TutorialStep.done ||
            specFor(_tutorialStep).scope == TutorialScope.tips)) {
      _tutorialStep = TutorialStep.nexusIntro;
    }
    notifyListeners();
    _scheduleStateSave();
  }

  /// The STABILIZE button was pressed. Its animation runs for several
  /// seconds before [stabilizeNexus]; the spotlight steps out of the way so
  /// the player actually gets to watch it.
  void onNexusStabilizeStarted() {
    _nexusStabilizeStartedAt = DateTime.now();
    if (_tutorialStep == TutorialStep.nexusAwakens ||
        _tutorialStep == TutorialStep.navPrestigeForNexus ||
        _tutorialStep == TutorialStep.nexusStabilize) {
      _tutorialStep = TutorialStep.done;
      notifyListeners();
    }
  }

  Timer? _ticker;
  Timer? _overclockTimer;
  Timer? _saveDebounceTimer;
  Timer? _temporalCollapseActiveTimer;
  Timer? _temporalCollapseCooldownTimerRef;
  Timer? _neuralSparkBoostTimer;
  Timer? _shopSparkSurgeTimer;
  double _neuralSparkBoostMultiplier = 1.0;
  double _shopSparkSurgeMultiplier = 1.0;
  static const Duration _saveDebounceDuration = Duration(milliseconds: 350);

  /// Owned shop permanents and timed boost expiry. Survives prestige; cleared
  /// on hard reset. Replace the mock grant in [purchaseShopProduct] with IAP.
  ShopInventory shopInventory = ShopInventory();

  /// When true, [purchaseShopProduct] grants immediately with no store billing.
  /// Flip to false and wire Play/App Store before release.
  static bool mockShopPurchases = true;

  /// True while a caught "Neural Spark" click-power boost is active.
  bool get isNeuralSparkBoostActive => _neuralSparkBoostMultiplier != 1.0;

  /// True while a paid Spark Surge production boost is active.
  bool get isShopSparkSurgeActive => _shopSparkSurgeMultiplier != 1.0;

  /// Multiplies all production (click + idle) from active shop timed boosts.
  double get shopTimedProductionMultiplier => _shopSparkSurgeMultiplier;

  /// Permanent shop click multiplier (primers + amplifiers).
  double get shopClickMultiplier => shopInventory.clickMultiplier;

  /// Permanent shop idle multiplier (primers + amplifiers).
  double get shopIdleMultiplier => shopInventory.idleMultiplier;

  /// Scale applied to Neural Spark spawn delays (Spark Magnet).
  double get neuralSparkSpawnDelayFactor =>
      shopInventory.neuralSparkSpawnDelayFactor;

  // Upgrades
  /// The upgrade catalog. Built fresh per call so each [GameState] owns its
  /// own mutable levels, and so tests can inspect the catalog without
  /// constructing a GameState (whose constructor starts the game loop).
  static List<Upgrade> defaultUpgrades() => [
    Upgrade(
      id: clickPowerId,
      name: 'Click Power',
      description: 'Adds +1 base click power per level.',
      baseCost: BigInt.from(15),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(1),
    ),
    Upgrade(
      id: 'click_reinforced_tap',
      name: 'Reinforced Tap',
      description: 'Adds +5 base click power per level.',
      baseCost: BigInt.from(4000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(5),
    ),
    Upgrade(
      id: probabilityStrikeId,
      name: 'Probability Strike',
      description:
          '5% chance for massive damage. Each level increases strike power.',
      baseCost: BigInt.from(25000),
      costMultiplier: 1.72,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: 'click_kinetic_amplifier',
      name: 'Kinetic Amplifier',
      description: 'Adds +25 base click power per level.',
      baseCost: BigInt.from(60000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(25),
    ),
    Upgrade(
      id: momentumId,
      name: 'Momentum',
      description: 'Each level improves combo growth, cap, and decay window.',
      baseCost: BigInt.from(80000),
      costMultiplier: 1.68,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: kineticSynergyId,
      name: 'Kinetic Synergy',
      description:
          'Each level adds +1% of your idle N/s to manual click power.',
      baseCost: BigInt.from(400000),
      costMultiplier: 1.75,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: 'click_resonant_touch',
      name: 'Resonant Touch',
      description: 'Adds +150 base click power per level.',
      baseCost: BigInt.from(750000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(150),
    ),
    Upgrade(
      id: overclockId,
      name: 'Overclock',
      description:
          'Each level boosts overclock power and duration, and lowers trigger streak.',
      baseCost: BigInt.from(1250000),
      costMultiplier: 1.82,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: 'click_quantum_fingertip',
      name: 'Quantum Fingertip',
      description: 'Adds +1,000 base click power per level.',
      baseCost: BigInt.from(10000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(1000),
    ),
    Upgrade(
      id: 'click_singularity_press',
      name: 'Singularity Press',
      description: 'Adds +7,500 base click power per level.',
      baseCost: BigInt.from(150000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(7500),
    ),
    Upgrade(
      id: 'click_subatomic_tap',
      name: 'Subatomic Tap',
      description: 'Adds +50,000 base click power per level.',
      baseCost: BigInt.from(2000000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(50000),
    ),
    Upgrade(
      id: 'click_quantum_forge',
      name: 'Quantum Forge',
      description: 'Adds +500,000 base click power per level.',
      baseCost: BigInt.from(40000000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(500000),
    ),
    Upgrade(
      id: 'click_chronos_press',
      name: 'Chronos Press',
      description:
          'Adds +5,000,000 base click power per level. Requires 2 prestiges.',
      baseCost: BigInt.from(800000000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(5000000),
    ),
    Upgrade(
      id: 'click_hyperdimensional_strike',
      name: 'Hyperdimensional Strike',
      description:
          'Adds +50,000,000 base click power per level. Requires 4 prestiges.',
      baseCost: BigInt.from(16000000000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(50000000),
    ),
    Upgrade(
      id: 'click_omni_touch',
      name: 'Omni-Touch Engine',
      description:
          'Adds +1,000,000,000 base click power per level. Requires 7 prestiges.',
      baseCost: BigInt.from(640000000000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(1000000000),
    ),
    Upgrade(
      id: autoClickerId,
      name: 'Auto-Clicker',
      description: 'Adds +1 base number per second per level.',
      baseCost: BigInt.from(150),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 1.0,
    ),
    Upgrade(
      id: quantumMultiplierId,
      name: 'Quantum Multiplier',
      description: 'Adds +10 base numbers per second per level.',
      baseCost: BigInt.from(1500),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 10.0,
    ),
    Upgrade(
      id: 'idle_fractal_engine',
      name: 'Fractal Engine',
      description: 'Adds +100 base numbers per second per level.',
      baseCost: BigInt.from(15000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 100.0,
    ),
    Upgrade(
      id: 'idle_singularity_core',
      name: 'Singularity Core',
      description: 'Adds +1,000 base numbers per second per level.',
      baseCost: BigInt.from(150000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 1000.0,
    ),
    Upgrade(
      id: 'idle_tesseract_array',
      name: 'Tesseract Array',
      description: 'Adds +10,000 base numbers per second per level.',
      baseCost: BigInt.from(1500000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 10000.0,
    ),
    Upgrade(
      id: 'idle_entropy_harvester',
      name: 'Entropy Harvester',
      description: 'Adds +100,000 base numbers per second per level.',
      baseCost: BigInt.from(15000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 100000.0,
    ),
    Upgrade(
      id: 'idle_void_resonance',
      name: 'Void Resonance',
      description: 'Adds +1,000,000 base numbers per second per level.',
      baseCost: BigInt.from(150000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 1000000.0,
    ),
    Upgrade(
      id: 'idle_dark_matter',
      name: 'Dark Matter Collector',
      description: 'Adds +10,000,000 base numbers per second per level.',
      baseCost: BigInt.from(1500000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 10000000.0,
    ),
    Upgrade(
      id: 'idle_neutron_reactor',
      name: 'Neutron Reactor',
      description:
          'Adds +100,000,000 base numbers per second per level. Requires 3 prestiges.',
      baseCost: BigInt.from(15000000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 100000000.0,
    ),
    Upgrade(
      id: 'idle_multiverse_synthesizer',
      name: 'Multiverse Synthesizer',
      description:
          'Adds +1,000,000,000 base numbers per second per level. Requires 6 prestiges.',
      baseCost: BigInt.from(150000000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 1000000000.0,
    ),
    Upgrade(
      id: 'idle_tachyon_accelerator',
      name: 'Tachyon Accelerator',
      description:
          'Adds +10,000,000,000 base numbers per second per level. Requires 10 prestiges.',
      baseCost: BigInt.from(1500000000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 10000000000.0,
    ),
    Upgrade(
      id: dimensionalTapId,
      name: 'Dimensional Tap',
      description:
          'Each level adds click power equal to 500× your prestige multiplier. Scales with every prestige. Requires 1 prestige.',
      baseCost: BigInt.from(500000000),
      costMultiplier: 2.10,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: cascadeResonatorId,
      name: 'Cascade Resonator',
      description:
          'Doubles your total idle rate per level (×2, ×4, ×8…). Requires 5 prestiges.',
      baseCost: BigInt.from(5000000000),
      costMultiplier: 4.0,
      maxLevel: 5,
      effectType: idleCategory,
      effectValue: 0.0,
    ),
    Upgrade(
      id: temporalCollapseId,
      name: 'Temporal Collapse',
      description:
          'Active: collapses 60s of idle into an instant burst and doubles your prestige multiplier for a short time. Cooldown decreases per level. Requires 8 prestiges.',
      baseCost: BigInt.from(50000000000),
      costMultiplier: 3.5,
      maxLevel: 5,
      effectType: clickCategory,
      effectValue: 0,
    ),
  ];

  List<Upgrade> upgrades = defaultUpgrades();

  GameState() {
    _init();
  }

  /// ── NEXUS research getters ─────────────────────────────────────────────

  int _nexusLevel(String id) => _researchNodeById(id)?.level ?? 0;

  // Id -> index lookups. These getters run several times per tick and per
  // tap, and used to linearly scan the lists each time. The index only maps
  // ids to positions; levels are always read live, so nothing can go stale.
  List<ResearchNode>? _indexedResearchNodes;
  Map<String, int> _researchNodeIndex = const {};
  List<Upgrade>? _indexedUpgrades;
  Map<String, int> _upgradeIndex = const {};

  ResearchNode? _researchNodeById(String id) {
    final nodes = researchNodes;
    if (!identical(nodes, _indexedResearchNodes) ||
        _researchNodeIndex.length != nodes.length) {
      _indexedResearchNodes = nodes;
      _researchNodeIndex = {
        for (int i = nodes.length - 1; i >= 0; i--) nodes[i].id: i,
      };
    }
    final idx = _researchNodeIndex[id];
    return idx == null ? null : nodes[idx];
  }

  Upgrade? _upgradeById(String id) {
    final list = upgrades;
    if (!identical(list, _indexedUpgrades) ||
        _upgradeIndex.length != list.length) {
      _indexedUpgrades = list;
      _upgradeIndex = {
        for (int i = list.length - 1; i >= 0; i--) list[i].id: i,
      };
    }
    final idx = _upgradeIndex[id];
    return idx == null ? null : list[idx];
  }

  /// Factor to multiply upgrade costs by. e.g. 0.93 = 7% cheaper.
  double get upgradeCostReductionFactor {
    final level = _nexusLevel('opt_protocol');
    return (1.0 - level * 0.01).clamp(0.01, 1.0);
  }

  /// Basis points (1/100 of 1%) of pre-prestige net worth paid after prestige.
  int get surgeProtocolNetWorthCarryBps =>
      _nexusLevel('surge_protocol') * 50 + shopInventory.surgeCarryBps;

  /// Multiplier applied to the prestige delta (Enhanced Extraction).
  double get prestigeDeltaMultiplier {
    final level = _nexusLevel('enhanced_extraction');
    return 1.0 + level * 0.10;
  }

  /// Permanent flat idle rate bonus that survives prestige resets.
  double get permanentIdleBonus => _nexusLevel('idle_foundation') * 1.0;

  /// Multiplier on offline gains (Quick Resume nexus + Chrono Lens + shop).
  double get offlineGainMultiplier {
    final level = _nexusLevel('quick_resume');
    return (1.0 + level * 0.10) *
        Artifacts.chronoOfflineMultiplier(_artifactLevel(Artifacts.chronoLens)) *
        shopInventory.offlineGainMultiplier;
  }

  /// Offline time beyond this is not credited (idle income only; neural
  /// training still runs for the whole absence).
  static const double baseOfflineCapHours = 12.0;
  double get offlineCapHours =>
      baseOfflineCapHours +
      Artifacts.chronoCapBonusHours(_artifactLevel(Artifacts.chronoLens)) +
      shopInventory.offlineCapBonusHours;

  /// Flat addition to the momentum cap (Kinetic Surge).
  double get momentumCapBonus => _nexusLevel('kinetic_surge') * 0.1;

  /// Additional idle rate multiplier from Resonance Core: 1.05 ^ level.
  double get resonanceMultiplier {
    final level = _nexusLevel('resonance_core');
    return math.pow(1.05, level).toDouble();
  }

  /// Multiplier on prestige points earned (Echo Protocol + shop Dividend).
  double get prestigePointsMultiplier {
    final level = _nexusLevel('echo_protocol');
    return (1.0 + level * 0.10) * shopInventory.prestigePointsMultiplier;
  }

  /// Tithe Engine: extra PP per artifact owned.
  double get titheMultiplier =>
      1.0 +
      Artifacts.titheBonusPerArtifact(_artifactLevel(Artifacts.titheEngine)) *
          artifactState.ownedCount;

  void purchaseResearch(String nodeId) {
    final node = researchNodes.where((n) => n.id == nodeId).firstOrNull;
    if (node == null || node.isMaxed) return;
    if (!node.prereqsMet(researchNodes)) return;
    final cost = node.costForNextLevel;
    if (prestigeCurrency < cost) return;
    prestigeCurrency -= cost;
    node.level++;
    if (nodeId == 'neural_genesis' && !neuralNetwork.unlocked) {
      _neuralRevision++;
      neuralNetwork.unlocked = true;
      neuralNetwork.layers = [
        NeuralLayer(
          index: 0,
          neurons: [NeuralNeuron(id: 'layer_0_neuron_0')],
        ),
      ];
    }
    if (nodeId == 'neural_genesis') {
      // Nothing left to tease once the network is awake.
      _seenBeats
        ..add(TutorialStep.neuralWhisper)
        ..add(TutorialStep.neuralGenesisReady);
    }
    if (nodeId == 'neural_genesis' &&
        !_neuralTutorialSeen &&
        (_tutorialStep == TutorialStep.done ||
            specFor(_tutorialStep).scope == TutorialScope.tips)) {
      // Exactly what the three guided actions cost. This used to be a flat
      // 100M, most of which the tutorial never asked the player to spend.
      number += neuralTutorialGrant;
      _tutorialStep = TutorialStep.neuralUnlocked;
    }
    if (nodeId == 'opt_protocol' &&
        _tutorialStep == TutorialStep.nexusResearchOptProtocol) {
      _tutorialStep = TutorialStep.nexusGoal;
    }
    _maybeStartNexusTeaser(node);
    _checkAchievements();
    notifyListeners();
    _saveState();
  }

  /// ── end NEXUS ──────────────────────────────────────────────────────────

  // ── Neural Network ─────────────────────────────────────────────────────

  /// Prestige counts at which deep layers 7, 8, 9 and 10 become growable.
  static const List<int> deepLayerPrestigeGates = [18, 22, 26, 30];

  /// How many layers the network may have at the current prestige count.
  int get neuralLayerLimit =>
      NeuralNetwork.pyramidLayerCount +
      deepLayerPrestigeGates.where((g) => prestigeCount >= g).length;

  /// Prestige count that unlocks the next deep layer, or null if all are.
  int? get nextDeepLayerGate {
    for (final g in deepLayerPrestigeGates) {
      if (g > prestigeCount) return g;
    }
    return null;
  }

  bool canBranchNeuron(String neuronId) =>
      neuralNetwork.canNeuronBranch(neuronId, layerLimit: neuralLayerLimit);

  NeuronBranchBlock? neuronBranchBlockReason(String neuronId) =>
      neuralNetwork.branchBlockReason(neuronId, layerLimit: neuralLayerLimit);

  int get neuralActiveExpansionLayer =>
      neuralNetwork.activeExpansionLayerIndex(layerLimit: neuralLayerLimit);

  BigInt _applyNeuralDiscount(BigInt cost) {
    final factor =
        Artifacts.synapseCostFactor(_artifactLevel(Artifacts.synapseCrown)) *
            shopInventory.neuralCostFactor;
    if (factor >= 1.0) return cost;
    return cost * BigInt.from((factor * 10000).round()) ~/ BigInt.from(10000);
  }

  /// Activation-change cost after Synapse Crown / Neural Patron discounts.
  BigInt neuronActivationCost(NeuralNeuron neuron, String fn) =>
      _applyNeuralDiscount(neuron.activationChangeCost(fn));

  BigInt get neuralBranchCost => _applyNeuralDiscount(
      neuralNetwork.addLayerCost(neuralNetwork.layers.length));

  BigInt neuronGradientCost(NeuralNeuron neuron) =>
      _applyNeuralDiscount(neuralNetwork.gradientUpgradeCost(neuron));

  /// Budget for the neural tutorial: one gradient upgrade, one paid
  /// activation change and one branch on the first neuron.
  BigInt get neuralTutorialGrant {
    final first = neuralNetwork.layers.isEmpty ||
            neuralNetwork.layers.first.neurons.isEmpty
        ? null
        : neuralNetwork.layers.first.neurons.first;
    if (first == null) return BigInt.zero;
    final paidActivation = neuronActivationCost(first, 'relu');
    return neuronGradientCost(first) + paidActivation + neuralBranchCost;
  }

  double get _neuralPreferredBonus =>
      Artifacts.synapsePreferredBonus(_artifactLevel(Artifacts.synapseCrown));
  double get neuralPreferredBonus => _neuralPreferredBonus;

  // ── Epochs ──
  bool get canStartEpoch =>
      neuralNetworkUnlocked && neuralNetwork.canStartEpoch;

  /// Permanent production bonus from completed Epochs.
  double get epochProductionMultiplier => 1.0 + 0.1 * neuralNetwork.epochs;

  /// Each Epoch trains 15% slower, so the loop keeps getting longer.
  double get _effectiveNeuralDecayK =>
      _neuralDecayK * math.pow(0.85, neuralNetwork.epochs).toDouble();

  bool startEpoch() {
    if (!canStartEpoch) return false;
    neuralNetwork.startEpoch();
    _neuralRevision++;
    _unlockAchievement(Achievements.firstEpoch);
    _checkAchievements();
    notifyListeners();
    _saveState();
    return true;
  }

  bool upgradeNeuronGradient(String neuronId) {
    final neuron = neuralNetwork.findNeuron(neuronId);
    if (neuron == null || neuralNetwork.isGradientMaxed(neuron)) return false;
    final cost = neuronGradientCost(neuron);
    if (number < cost) return false;
    number -= cost;
    neuron.gradientLevel++;
    _neuralRevision++;
    if (_tutorialStep == TutorialStep.neuralUpgradeGradient) {
      _tutorialStep = TutorialStep.neuralChangeActivation;
    }
    notifyListeners();
    _scheduleStateSave();
    return true;
  }

  bool changeNeuronActivation(String neuronId, String fn) {
    final neuron = neuralNetwork.findNeuron(neuronId);
    if (neuron == null || neuron.activationFn == fn) return false;
    final cost = neuronActivationCost(neuron, fn);
    if (cost > BigInt.zero && number < cost) return false;
    if (cost > BigInt.zero) number -= cost;
    neuron.activationFn = fn;
    if (fn != 'linear') neuron.unlockedActivations.add(fn);
    _neuralRevision++;
    if (_tutorialStep == TutorialStep.neuralChangeActivation) {
      _tutorialStep = TutorialStep.neuralBranchNeuron;
    }
    notifyListeners();
    _scheduleStateSave();
    return true;
  }

  bool branchNeuron(String neuronId) {
    if (!canBranchNeuron(neuronId)) return false;
    final cost = neuralBranchCost;
    if (number < cost) return false;

    final neuron = neuralNetwork.findNeuron(neuronId);
    final layer = neuralNetwork.findNeuronLayer(neuronId);
    if (neuron == null || layer == null) return false;

    number -= cost;
    neuron.hasBranched = true;
    _neuralRevision++;

    // Spawn this parent's slice of the next layer immediately, so children
    // appear as each sibling branches rather than all at once at the end.
    final nextIdx = layer.index + 1;
    final targetNext = NeuralNetwork.targetNeuronCountForLayer(nextIdx);
    if (targetNext > 0) {
      int eligibleCount = 0;
      int eligibleIndexOfParent = -1;
      for (int i = 0; i < layer.neurons.length; i++) {
        if (!NeuralNetwork.isEligibleParentIndex(layer.index, i,
            layerLimit: neuralLayerLimit)) {
          continue;
        }
        if (layer.neurons[i].id == neuron.id) {
          eligibleIndexOfParent = eligibleCount;
        }
        eligibleCount++;
      }

      if (eligibleCount > 0 && eligibleIndexOfParent >= 0) {
        NeuralLayer? nextLayer = neuralNetwork.layers
            .where((l) => l.index == nextIdx)
            .firstOrNull;
        if (nextLayer == null) {
          nextLayer = NeuralLayer(index: nextIdx, neurons: []);
          neuralNetwork.layers.add(nextLayer);
        }

        final perParent = targetNext ~/ eligibleCount;
        final startSlot = eligibleIndexOfParent * perParent;
        final existingIds = nextLayer.neurons.map((n) => n.id).toSet();
        for (int c = 0; c < perParent; c++) {
          final slot = startSlot + c;
          final id = 'layer_${nextIdx}_neuron_$slot';
          if (!existingIds.contains(id)) {
            nextLayer.neurons.add(NeuralNeuron(id: id));
          }
        }
        // Keep neurons ordered by slot so the painter draws stable positions.
        nextLayer.neurons.sort((a, b) {
          final aSlot = int.tryParse(a.id.split('_').last) ?? 0;
          final bSlot = int.tryParse(b.id.split('_').last) ?? 0;
          return aSlot.compareTo(bSlot);
        });
      }
    }

    if (_tutorialStep == TutorialStep.neuralBranchNeuron) {
      // Hold the advance until the sheet has actually finished dismissing.
      // Switching to neuralViewAccuracy here meant the overlay spotlit the
      // loss HUD from a frame where the sheet was still covering it.
      _pendingNeuralAccuracyStep = true;
    }
    _checkAchievements();
    notifyListeners();
    _scheduleStateSave();
    return true;
  }

  void onNeuronTapped() {
    if (_tutorialStep == TutorialStep.neuralTapNeuron) {
      _tutorialStep = TutorialStep.neuralUpgradeGradient;
      notifyListeners();
    }
  }

  /// Set by [branchNeuron] during the neural tutorial, flushed by
  /// [onNeuronSheetDismissed] once the detail sheet is gone.
  bool _pendingNeuralAccuracyStep = false;

  /// Called for **every** dismissal path of NeuronDetailSheet — branch, close
  /// button, backdrop tap and swipe-down.
  ///
  /// The in-sheet steps used to have no handling for dismissal at all: the
  /// overlay rendered nothing and no SKIP, so swiping the sheet away left the
  /// player permanently stuck.
  void onNeuronSheetDismissed() {
    if (_pendingNeuralAccuracyStep) {
      _pendingNeuralAccuracyStep = false;
      _tutorialStep = TutorialStep.neuralViewAccuracy;
      notifyListeners();
      _scheduleStateSave();
    }
  }

  // ── end Neural Network ────────────────────────────────────────────────

  /// Increment added on the prestige with index [prestigeIndex] (0 = first prestige).
  static double prestigeDeltaAtIndex(int prestigeIndex) {
    const base = 0.20;
    const perStep = 0.05;
    return base + prestigeIndex * perStep;
  }

  /// Delta for the next prestige, boosted by Enhanced Extraction.
  double get nextPrestigeDelta =>
      prestigeDeltaAtIndex(prestigeCount) * prestigeDeltaMultiplier;

  /// Total prestige multiplier after exactly [count] completed prestiges.
  static double multiplierAfterPrestigeCount(int count) {
    double m = 1.0;
    for (int i = 0; i < count; i++) {
      m += prestigeDeltaAtIndex(i);
    }
    return m;
  }

  /// Multiplier value after the next prestige (preview).
  double get prestigeMultiplierAfterNext =>
      prestigeMultiplier + nextPrestigeDelta;

  /// Base requirement for the very first prestige.
  static final BigInt prestigeBaseRequirement = BigInt.from(100000000); // 100M
  static final BigInt prestigeTestBaseRequirement = BigInt.from(10000);

  /// How much more each successive prestige costs, as an exact rational.
  ///
  /// This is the single most important pacing constant in the game. The reward
  /// grows at [prestigeRewardGrowth] (1.35), so if the requirement were flat
  /// the loop would run *backwards* — every prestige cheaper in real terms than
  /// the last, with PP/hour compounding without limit. 2.1 is tuned so run
  /// times bottom out around prestige 7 and then grow, putting prestige 13 at
  /// roughly 36 cumulative hours with PP/hour declining after run 10.
  ///
  /// Held as 21/10 rather than a double on purpose: computing
  /// `base * pow(2.1, n)` in floating point and handing the result to
  /// `BigInt.from` saturates at int64 max around prestige 35, which silently
  /// flattens the curve back into the bug this constant exists to fix.
  static final BigInt _prestigeGrowthNumerator = BigInt.from(21);
  static final BigInt _prestigeGrowthDenominator = BigInt.from(10);

  /// Convenience view of the growth factor for docs and tests.
  static const double prestigeRequirementGrowth = 2.1;

  /// Hard ceiling on the exponent. 100M x 2.1^1000 is about 1e338 — far past
  /// anything reachable — so clamping here costs nothing and keeps the BigInt
  /// arithmetic from blowing up if a corrupt save reports a wild count.
  static const int maxPrestigeRequirementExponent = 1000;

  /// Number required to perform the next prestige.
  ///
  /// Memoized: MainLayout's listener reads this on every notify (~10x/s) and
  /// it is a pair of BigInt powers, but it only moves with [prestigeCount] or
  /// the test-environment flag.
  BigInt get prestigeRequirement {
    final cached = _prestigeRequirementCache;
    if (cached != null &&
        _prestigeRequirementCacheCount == prestigeCount &&
        _prestigeRequirementCacheTestEnv == _testEnvironmentEnabled) {
      return cached;
    }
    final value = _prestigeRequirementAtCount(
      prestigeCount,
      testEnvironment: _testEnvironmentEnabled,
    );
    _prestigeRequirementCache = value;
    _prestigeRequirementCacheCount = prestigeCount;
    _prestigeRequirementCacheTestEnv = _testEnvironmentEnabled;
    return value;
  }

  BigInt? _prestigeRequirementCache;
  int _prestigeRequirementCacheCount = -1;
  bool _prestigeRequirementCacheTestEnv = false;

  /// Fixed reward for the next prestige activation.
  double get nextPrestigeReward => prestigeRewardAtCount(prestigeCount);

  /// Requirement for the prestige at [count] completed prestiges.
  /// Grows geometrically so later prestiges stay meaningful.
  static BigInt prestigeRequirementAtCount(int count) =>
      _prestigeRequirementAtCount(count, testEnvironment: false);

  static BigInt _prestigeRequirementAtCount(
    int count, {
    required bool testEnvironment,
  }) {
    final base =
        testEnvironment ? prestigeTestBaseRequirement : prestigeBaseRequirement;
    var exponent = count < 0 ? 0 : count;
    if (exponent > maxPrestigeRequirementExponent) {
      exponent = maxPrestigeRequirementExponent;
    }
    return base *
        _prestigeGrowthNumerator.pow(exponent) ~/
        _prestigeGrowthDenominator.pow(exponent);
  }

  /// Base PP awarded by the first prestige.
  static const double prestigeBaseReward = 3.0;

  /// Growth of the PP reward per prestige. Must stay below
  /// [prestigeRequirementGrowth] or the loop runs backwards.
  static const double prestigeRewardGrowth = 1.35;

  /// Fixed prestige point reward for the next prestige (independent of current number).
  static double prestigeRewardAtCount(int count) {
    final safeCount = count < 0 ? 0 : count;
    return prestigeBaseReward * math.pow(prestigeRewardGrowth, safeCount);
  }

  /// Calculates fixed prestige points from [currentNumber] for the next prestige.
  double calculatePrestigePoints(BigInt currentNumber) {
    final requirement = prestigeRequirement;
    if (currentNumber < requirement) return 0.0;
    return nextPrestigeReward * prestigePointsMultiplier * titheMultiplier;
  }

  // Testing utility: add prestige currency directly
  void addPrestigePointsForTesting(int amount) {
    prestigeCurrency = prestigeCurrency + amount;
    notifyListeners();
  }

  // Testing utility: add number without touching anything else.
  void addNumberForTesting(BigInt amount) {
    number += amount;
    _updateHighestNumber();
    _checkAchievements();
    notifyListeners();
    _saveState();
  }

  // Testing utility: count [count] prestiges (and their multiplier gain)
  // without resetting the run, so deep layers and artifact milestones can
  // be reached quickly.
  void addPrestigesForTesting(int count) {
    final old = prestigeCount;
    for (var i = 0; i < count; i++) {
      prestigeMultiplier += nextPrestigeDelta;
      prestigeCount++;
    }
    _queueNewlyUnlockedUpgrades(old, prestigeCount);
    _queueNexusReadyNotice(old, prestigeCount);
    _recalculateDerivedStatsFromUpgrades();
    _checkAchievements();
    notifyListeners();
    _saveState();
  }

  // Testing utility: jump neural training to the loss floor so Epochs can
  // be tried without waiting days.
  void finishNeuralTrainingForTesting() {
    if (!neuralNetworkUnlocked) return;
    neuralNetwork.loss = _neuralMinLoss;
    if (neuralNetwork.loss < neuralNetwork.lowestLossEver) {
      neuralNetwork.lowestLossEver = neuralNetwork.loss;
    }
    _checkAchievements();
    notifyListeners();
    _saveState();
  }

  /// Resolve a persisted step by name; null for anything unrecognised.
  static TutorialStep? _tutorialStepFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final step in TutorialStep.values) {
      if (step.name == name) return step;
    }
    return null;
  }

  /// Restores tutorial progress from a loaded save. Runs after the rest of
  /// the save is in place, since the backfill reads prestige count, the
  /// Nexus and the network.
  void _restoreTutorialState(Map<String, dynamic> data) {
    _tutorialCompleted = (data['tutorialCompleted'] as bool?) ?? false;
    _nexusTutorialSeen = (data['nexusTutorialSeen'] as bool?) ?? false;
    _neuralTutorialSeen = (data['neuralTutorialSeen'] as bool?) ?? false;
    _artifactTutorialSeen = (data['artifactTutorialSeen'] as bool?) ?? false;

    final savedBeats = data['tutorialBeatsSeen'] as List<String>?;
    _seenBeats.clear();
    for (final name in savedBeats ?? const <String>[]) {
      final step = _tutorialStepFromName(name);
      if (step != null) _seenBeats.add(step);
    }

    final stepName = data['tutorialStep'] as String?;
    final saved = _tutorialStepFromName(stepName);
    final legacyStep = legacyTutorialStepNames.contains(stepName);
    if (_tutorialCompleted) {
      // Resume a later chapter the app was killed in the middle of — they
      // fire on one-time events, so dropping one here would lose it for
      // good. Chapter 1 steps cannot apply once it is finished.
      _tutorialStep = saved != null && specFor(saved).scope != TutorialScope.main
          ? saved
          : TutorialStep.done;
    } else if (saved != null && specFor(saved).scope == TutorialScope.main) {
      // Mid chapter 1: resume exactly where the player left off.
      _tutorialStep = saved;
    } else if (saved != null || legacyStep) {
      // An older build's onboarding ran past its first minute (upgrade
      // deep-dive, prestige cards) before calling itself complete. That
      // player has done everything chapter 1 teaches.
      if (legacyStep &&
          prestigeCount == 0 &&
          number >= _legacyUpgradeTutorialGrant &&
          stepName != 'learnPrestige' &&
          stepName != 'goodLuck') {
        // Builds before the deep-dive snapshot baked its 100M grant into
        // the save. It only ever ran minutes into a new game, so a balance
        // that large is the grant — take it back.
        number -= _legacyUpgradeTutorialGrant;
        highestNumber = number;
        _upgradeById(probabilityStrikeId)?.level = 0;
        _upgradeById(momentumId)?.level = 0;
        _recalculateDerivedStatsFromUpgrades();
      }
      _tutorialCompleted = true;
      _tutorialNeedsCloudSync = true;
      _tutorialStep = TutorialStep.done;
    } else {
      _tutorialStep = TutorialStep.welcome;
    }

    if (savedBeats == null && _tutorialCompleted) {
      _backfillSeenBeats(
        legacyDeepDiveSeen:
            (data['upgradeTutorialSeen'] as bool?) == true || legacyStep,
      );
    }
  }

  /// The flat grant very old builds added to `number` for the upgrade
  /// deep-dive. Only used to repair saves written by those builds.
  static final BigInt _legacyUpgradeTutorialGrant = BigInt.from(100000000);

  /// Marks every tip and teaser the player is already past as seen. Used
  /// for progress that arrives without a record of which cards were shown —
  /// a save from before they existed, or a cloud restore on a new device —
  /// so a veteran isn't walked through things they already know.
  void _backfillSeenBeats({bool legacyDeepDiveSeen = false}) {
    if (legacyDeepDiveSeen || prestigeCount >= 1) {
      _seenBeats.addAll(const [
        TutorialStep.tipAdvisor,
        TutorialStep.tipProbabilityStrike,
        TutorialStep.tipMomentum,
        TutorialStep.tipKineticSynergy,
        TutorialStep.tipOverclock,
      ]);
    }
    if (prestigeCount >= 1) _seenBeats.add(TutorialStep.prestigeReady);
    if (prestigeCount >= 2) _seenBeats.add(TutorialStep.nexusSignal);
    if (_nexusStabilized) _seenBeats.add(TutorialStep.nexusAwakens);
    if (prestigeCount >= minPrestigeForUpgrade(temporalCollapseId)) {
      _seenBeats.add(TutorialStep.tipTemporalCollapse);
    }
    if (neuralNetworkUnlocked) {
      _seenBeats
        ..add(TutorialStep.neuralWhisper)
        ..add(TutorialStep.neuralGenesisReady);
    }
    if (prestigeCount >= deepLayerPrestigeGates.first) {
      _seenBeats.add(TutorialStep.tipDeepLayers);
    }
    if (neuralNetwork.epochs > 0) _seenBeats.add(TutorialStep.tipEpoch);
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initConnectivityMonitoring());
    try {
      final data = await _storageService.loadGame();
      number = data['number'] as BigInt;

      _testEnvironmentEnabled = (data['testEnvironmentEnabled'] as bool?) ?? false;

      // clickPower is fully derived from base + upgrade levels by
      // _recalculateDerivedStatsFromUpgrades() below, so the saved value is
      // only a floor against a corrupt/empty blob.
      final savedClickPower = data['clickPower'] as BigInt;
      clickPower = savedClickPower > BigInt.zero
          ? savedClickPower
          : BigInt.from(productionBaseClickPower);

      final savedAutoClickRate = data['autoClickRate'] as double? ?? 0.0;
      autoClickRate = savedAutoClickRate.isFinite && savedAutoClickRate > 0.0
          ? savedAutoClickRate
          : 0.0;

      final loadedPrestigeCurrency = data['prestigeCurrency'];
      if (loadedPrestigeCurrency is BigInt) {
        prestigeCurrency = loadedPrestigeCurrency.toDouble();
      } else if (loadedPrestigeCurrency is num) {
        prestigeCurrency = loadedPrestigeCurrency.toDouble();
      } else {
        prestigeCurrency = 0.0;
      }

      final legacy = data['legacyGlobalMultiplier'] as BigInt?;
      if (legacy != null) {
        prestigeCount = (legacy - BigInt.one).toInt().clamp(0, 999999);
        prestigeMultiplier = multiplierAfterPrestigeCount(prestigeCount);
        await _saveState();
      } else {
        prestigeMultiplier = (data['prestigeMultiplier'] as double?) ?? 1.0;
        if (prestigeMultiplier < 1.0 || !prestigeMultiplier.isFinite) {
          prestigeMultiplier = 1.0;
        }
        prestigeCount = (data['prestigeCount'] as int?) ?? 0;
        if (prestigeCount < 0) prestigeCount = 0;
      }

      final upgradeLevels =
          (data['upgradeLevels'] as Map<String, int>?) ?? <String, int>{};

      for (final upgrade in upgrades) {
        final savedLevel = upgradeLevels[upgrade.id] ?? 0;
        final normalizedLevel = upgrade.maxLevel == -1
            ? savedLevel
            : savedLevel.clamp(0, upgrade.maxLevel);
        upgrade.level = normalizedLevel;
      }
      _recalculateDerivedStatsFromUpgrades();

      final savedHighest = data['highestNumber'] as BigInt? ?? BigInt.zero;
      highestNumber = savedHighest > number ? savedHighest : number;
      final nexusLevelMap =
          (data['nexusLevels'] as Map<String, int>?) ?? <String, int>{};
      for (final node in researchNodes) {
        node.level = (nexusLevelMap[node.id] ?? 0).clamp(0, node.maxLevel);
      }

      _nexusStabilized = (data['nexusStabilized'] as bool?) ?? false;

      lifetimeClicks = (data['lifetimeClicks'] as int?) ?? 0;
      _unlockedAchievements
        ..clear()
        ..addAll((data['achievements'] as List<String>?) ?? const []);
      final artifactsJson = data['artifacts'] as String?;
      if (artifactsJson != null) {
        try {
          artifactState = ArtifactState.fromJson(
              jsonDecode(artifactsJson) as Map<String, dynamic>);
        } catch (_) {
          artifactState = ArtifactState();
        }
      }
      final shopJson = data['shop'] as String?;
      if (shopJson != null) {
        try {
          shopInventory = ShopInventory.fromJson(
              jsonDecode(shopJson) as Map<String, dynamic>);
        } catch (_) {
          shopInventory = ShopInventory();
        }
      }
      _restoreShopSparkSurgeFromInventory();
      _recalculateDerivedStatsFromUpgrades();

      final nnJson = data['neuralNetwork'] as String?;
      if (nnJson != null) {
        try {
          neuralNetwork = NeuralNetwork.fromJsonString(nnJson);
        } catch (_) {
          neuralNetwork = NeuralNetwork.initial();
        }
      }

      _restoreTutorialState(data);

      final lastPlayed = data['lastPlayed'] as DateTime?;
      _lastSavedAt = lastPlayed;
      _calculateOfflineProgress(lastPlayed);

      _startTicker();
      notifyListeners();
    } catch (error, stack) {
      // A load that throws part-way used to leave half-loaded state and no
      // ticker, and the next tap then saved that over the real save. Keep a
      // copy of what was stored, then start a clean game that runs normally.
      debugPrint('Failed to load save, starting fresh: $error\n$stack');
      try {
        await _storageService.backupRawSave();
      } catch (backupError) {
        debugPrint('Failed to back up unreadable save: $backupError');
      }
      _loadFailed = true;
      _testEnvironmentEnabled = false;
      _resetToFreshState(preserveTutorial: false);
      _lastSavedAt = null;
      _startTicker();
      notifyListeners();
    } finally {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    }
  }

  void _calculateOfflineProgress(DateTime? lastPlayed, {DateTime? now}) {
    if (lastPlayed != null) {
      final diff = (now ?? DateTime.now()).difference(lastPlayed).inSeconds;
      if (diff <= 0) return;
      if (diff >= 8 * 3600) _unlockAchievement(Achievements.longAbsence);

      final capSeconds = (offlineCapHours * 3600).floor();
      final credited = diff < capSeconds ? diff : capSeconds;
      if (totalIdleRate > 0) {
        final offlineGains = totalIdleRate * credited * offlineGainMultiplier;
        offlineGainsThisSession = wholeBigInt(offlineGains);
        number += offlineGainsThisSession;
        _updateHighestNumber();
        if (offlineGains.isFinite) {
          _idleAccumulator += offlineGains - offlineGains.floorToDouble();
        }
      }

      if (neuralNetworkUnlocked && neuralNetwork.loss > _neuralMinLoss) {
        final s = neuralNetworkStrength;
        if (s > 0) {
          final oldAccuracy = neuralNetwork.accuracy;
          final newLoss =
              neuralNetwork.loss * math.exp(-_effectiveNeuralDecayK * s * diff);
          neuralNetwork.loss =
              newLoss < _neuralMinLoss ? _neuralMinLoss : newLoss;
          if (neuralNetwork.loss < neuralNetwork.lowestLossEver) {
            neuralNetwork.lowestLossEver = neuralNetwork.loss;
          }
          offlineAccuracyGain = neuralNetwork.accuracy - oldAccuracy;
        }
      }
    }
  }

  void clearOfflineGains() {
    offlineGainsThisSession = BigInt.zero;
    offlineAccuracyGain = 0.0;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Prestige and a cloud restore restart the loop; if either finishes
    // while the app is minimised, resuming will start it instead.
    if (_backgroundedAt != null) {
      _ticker = null;
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      bool hasStateChange = _updateMomentumDecay();

      final effectiveRate = totalIdleRate;
      if (effectiveRate > 0) {
        _idleAccumulator += effectiveRate / 10; // 10 ticks per second
        if (_idleAccumulator >= 1.0) {
          final added = _idleAccumulator.floorToDouble();
          number += wholeBigInt(added);
          _updateHighestNumber();
          _advanceTutorialOnNumberReached();
          _idleAccumulator -= added;
          hasStateChange = true;
        }
      }

      // Neural network loss decay — runs every tick when unlocked, regardless
      // of whether the player has an auto-clicker. Loss generally decays
      // (driven by network strength) but includes realistic training noise.
      if (neuralNetworkUnlocked && neuralNetwork.loss > _neuralMinLoss) {
        final s = neuralNetworkStrength;
        if (s > 0) {
          final next =
              neuralNetwork.loss * math.exp(-_effectiveNeuralDecayK * s * _neuralDt);

          // Temporarily disable stochastic jitter so accuracy progression is
          // strictly monotonic from live training updates.
          neuralNetwork.loss = next.clamp(_neuralMinLoss, 1.0);
          if (neuralNetwork.loss < neuralNetwork.lowestLossEver) {
            neuralNetwork.lowestLossEver = neuralNetwork.loss;
          }
          hasStateChange = true;
        }
      }

      if (_tickArtifacts()) hasStateChange = true;
      // Twice a second is plenty for a card that waits on a balance.
      if (timer.tick % 5 == 0 && _checkTutorialTriggers()) {
        hasStateChange = true;
      }
      if (timer.tick % 10 == 0 && _checkAchievements()) {
        hasStateChange = true;
      }

      // Periodically persist — pulled out of the autoClickRate>0 block so
      // loss decay and lowestLossEver still get saved for players without
      // an auto-clicker yet.
      if (timer.tick % 50 == 0) {
        _saveState();
      }

      // Only notify if there's an actual change that affects UI
      if (hasStateChange) {
        notifyListeners();
      }
    });
  }

  /// Overclock Core and Compound Vault, advanced once per 100ms tick.
  bool _tickArtifacts() {
    var changed = false;
    final coreInterval = Artifacts.overclockCoreInterval(
        _artifactLevel(Artifacts.overclockCore));
    if (coreInterval != null) {
      _overclockCoreElapsed += _neuralDt;
      if (_overclockCoreElapsed >= coreInterval) {
        _overclockCoreElapsed = 0.0;
        if (!_overclockActive) {
          _activateOverclock();
          changed = true;
        }
      }
    }

    final vaultLevel = _artifactLevel(Artifacts.compoundVault);
    if (vaultLevel > 0) {
      _compoundVaultElapsed += _neuralDt;
      if (_compoundVaultElapsed >= Artifacts.compoundIntervalSeconds) {
        _compoundVaultElapsed = 0.0;
        final share = number.toDouble() * Artifacts.compoundShare(vaultLevel);
        final cap = totalIdleRate *
            60 *
            Artifacts.compoundCapMinutes(vaultLevel);
        final payout = share < cap ? share : cap;
        if (payout.isFinite && payout >= 1) {
          number += wholeBigInt(payout);
          _updateHighestNumber();
          changed = true;
        }
      }
    }
    return changed;
  }

  // ── Neural network decay tuning ────────────────────────────────────────
  // Tuned so a fully maxed network (all 22 neurons at GL9, all preferred
  // activations, strength ≈ 5.85) reaches loss ≈ 0.001 in ~2.7 days of real
  // time (including offline). Partial networks scale proportionally: a
  // mid-game build (~strength 3) takes ~5.3 days, so upgrading is the lever.
  //
  // The previous value (1e-6) put a *maxed* network at ~13.7 days of pure
  // waiting with no interaction available — a timer, not an end game.
  static const double _neuralDt = 0.1; // ticker period in seconds
  static const double _neuralDecayK = 0.000005;

  /// Exposed for the economy tests, which assert the training arc stays in
  /// the "days" band rather than drifting back into a multi-week timer.
  static double get neuralDecayK => _neuralDecayK;
  static const double _neuralMinLoss = 0.001; // floor: max accuracy ≈ 99.96%
  static const double _neuralBaseBoostScale = 30.0;
  static const double _neuralBoostPerDeepLayer = 10.0;
  static const double _neuralBaseSoftCapPerPrestige = 5.0;

  /// Max multiplier from a fully trained network. Deep layers raise the
  /// ceiling instead of only making training faster.
  double get _neuralBoostScale =>
      _neuralBaseBoostScale +
      _neuralBoostPerDeepLayer * neuralNetwork.deepLayerCount;

  /// Each Epoch lifts the per-prestige soft cap by one.
  double get _neuralSoftCapPerPrestige =>
      _neuralBaseSoftCapPerPrestige + neuralNetwork.epochs;

  bool get isOverclockActive => _overclockActive;
  double get momentumMultiplier => _momentumMultiplier;
  double get momentumProgress => _momentumProgress;
  bool get hasMomentumUpgrade => _isUpgradeActive(momentumId);

  int get _cascadeResonatorLevel =>
      _upgradeById(cascadeResonatorId)?.level ?? 0;

  /// Combined multiplicative bonus applied on top of raw production: prestige,
  /// achievements, Resonance Prism, Epochs, neural efficiency, Resonance Core,
  /// plus Temporal Collapse / Overclock / Cascade Resonator while active. This
  /// is every factor in [totalIdleRate] except the base auto-click rate
  /// itself, so it answers "how much is everything multiplying my output by"
  /// independent of whether any idle upgrades are owned yet.
  double get totalMultiplier {
    double multiplier = prestigeMultiplier *
        _temporalCollapseFactor *
        resonanceMultiplier *
        neuralLossMultiplier *
        globalProductionMultiplier *
        shopIdleMultiplier *
        shopTimedProductionMultiplier;
    if (_overclockActive) {
      multiplier *= _overclockIdleMultiplier;
    }
    final cascadeLvl = _cascadeResonatorLevel;
    if (cascadeLvl > 0) {
      multiplier *= math.pow(2.0, cascadeLvl);
    }
    return multiplier;
  }

  double get totalIdleRate {
    // Require at least one actual idle generator upgrade before any idle
    // production can happen. This prevents post-prestige passive gain when
    // upgrade levels are reset to zero.
    if (autoClickRate <= 0.0) return 0.0;

    double idleRate = (autoClickRate + permanentIdleBonus) *
        prestigeMultiplier *
        _temporalCollapseFactor *
        resonanceMultiplier *
        neuralLossMultiplier *
        globalProductionMultiplier *
        shopIdleMultiplier *
        shopTimedProductionMultiplier;
    if (_overclockActive) {
      idleRate *= _overclockIdleMultiplier;
    }
    final cascadeLvl = _cascadeResonatorLevel;
    if (cascadeLvl > 0) {
      idleRate *= math.pow(2.0, cascadeLvl);
    }
    // Past ~1.8e308 the product overflows to Infinity, which would poison
    // the idle accumulator (Infinity - Infinity is NaN) and stop idle gain.
    return idleRate.isFinite ? idleRate : double.maxFinite;
  }

  /// Raw (uncapped) multiplier from the network's current loss. Exposed so
  /// the HUD can detect when the soft cap is the binding constraint without
  /// having to know `_neuralBoostScale` itself.
  /// Bumped by every in-place mutation of [neuralNetwork]'s shape: neuron
  /// count, gradient level, activation, branching. Replacing the network
  /// object is caught by identity instead.
  int _neuralRevision = 0;

  /// Cheap value-equality handle on the network's *shape*.
  ///
  /// Lets the neural canvas rebuild only when the topology actually changes,
  /// instead of on every 100ms loss tick. This used to build and join a
  /// string over every neuron on each notify just to compare it.
  (NeuralNetwork, int) get neuralTopologyKey =>
      (neuralNetwork, _neuralRevision);

  NeuralNetwork? _strengthCacheNetwork;
  int _strengthCacheRevision = -1;
  double _strengthCacheBonus = -1;
  double _strengthCache = 0.0;

  /// [NeuralNetwork.computeStrength], cached against [neuralTopologyKey].
  /// Strength depends only on the shape, but the ticker needs it 10x/s.
  double get neuralNetworkStrength {
    final bonus = _neuralPreferredBonus;
    if (!identical(_strengthCacheNetwork, neuralNetwork) ||
        _strengthCacheRevision != _neuralRevision ||
        _strengthCacheBonus != bonus) {
      _strengthCache = neuralNetwork.computeStrength(preferredBonus: bonus);
      _strengthCacheNetwork = neuralNetwork;
      _strengthCacheRevision = _neuralRevision;
      _strengthCacheBonus = bonus;
    }
    return _strengthCache;
  }

  double get neuralLossRawMultiplier {
    if (!neuralNetworkUnlocked) return 1.0;
    final raw = 1.0 + (1.0 - neuralNetwork.loss) * _neuralBoostScale;
    return raw < 1.0 ? 1.0 : raw;
  }

  /// Multiplier applied to all number gain (idle + click) based on how well
  /// the neural network is trained. Loss=1.0 → 1.0× (no boost). Loss→0 →
  /// up to 1 + (1 − loss) × scale, soft-capped by prestigeCount so a returning
  /// player can't trivialize the early prestige curve.
  double get neuralLossMultiplier {
    if (!neuralNetworkUnlocked) return 1.0;
    final raw = neuralLossRawMultiplier;
    final softCap = 1.0 + prestigeCount * _neuralSoftCapPerPrestige;
    return raw < softCap ? raw : softCap;
  }

  /// Live decay rate (loss-units per second per current loss) for HUD display.
  double get neuralDecayRate {
    if (!neuralNetworkUnlocked) return 0.0;
    return _effectiveNeuralDecayK * neuralNetworkStrength;
  }

  int upgradeMilestoneMultiplierForLevel(int level) {
    if (level <= 0) return 1;

    int reachedMilestones = 0;
    for (final threshold in upgradeMilestoneThresholds) {
      if (level >= threshold) {
        reachedMilestones++;
      }
    }
    final base =
        Artifacts.milestoneBase(_artifactLevel(Artifacts.milestoneCompass));
    if (base == 2.0) return 1 << reachedMilestones;
    return math.pow(base, reachedMilestones).round();
  }

  int upgradeMilestoneMultiplier(Upgrade upgrade) {
    return upgradeMilestoneMultiplierForLevel(upgrade.level);
  }

  /// Base value of a manual click before upgrades and multipliers.
  ///
  /// A fresh save clicks for exactly 1. The click branch stays competitive
  /// through its upgrades instead of the base: the flat click upgrades (Click
  /// Power +1, Reinforced Tap +5, … Singularity Press +7,500) add their raw
  /// `effectValue` per level, and Probability Strike, Momentum, Kinetic
  /// Synergy and Overclock all multiply on top of that.
  static const int productionBaseClickPower = 1;

  void _recalculateDerivedStatsFromUpgrades() {
    final baseClick = _testEnvironmentEnabled ? 10000 : productionBaseClickPower;
    clickPower = BigInt.from(baseClick);
    autoClickRate = 0.0;

    for (final upgrade in upgrades) {
      if (upgrade.level <= 0) continue;
      if (upgrade.id == cascadeResonatorId) continue; // handled in totalIdleRate
      if (upgrade.id == temporalCollapseId) continue; // active ability only

      if (upgrade.id == dimensionalTapId) {
        // Prestige-synergy: each level adds 500 × prestigeMultiplier to click power
        clickPower +=
            wholeBigInt(prestigeMultiplier * upgrade.level * 500);
        continue;
      }

      final milestoneMultiplier = upgradeMilestoneMultiplier(upgrade);
      if (upgrade.effectType == idleCategory && upgrade.effectValue is double) {
        autoClickRate += (upgrade.effectValue as double) *
            upgrade.level *
            milestoneMultiplier;
      } else if (upgrade.effectType == clickCategory &&
          upgrade.effectValue is BigInt) {
        final effectValue = upgrade.effectValue as BigInt;
        clickPower += effectValue *
            BigInt.from(upgrade.level * milestoneMultiplier);
      }
    }
  }

  int _upgradeLevel(String id) {
    final upgrade = _upgradeById(id);
    if (upgrade == null) return 0;
    return upgrade.level * upgradeMilestoneMultiplier(upgrade);
  }

  double get _probabilityStrikeChance {
    final level = _upgradeLevel(probabilityStrikeId);
    if (level <= 0) return 0.0;
    return Artifacts.strikeChance(_artifactLevel(Artifacts.loadedDice));
  }

  double get _probabilityStrikeMultiplier {
    final level = _upgradeLevel(probabilityStrikeId);
    if (level <= 0) return 1.0;
    return 10.0 + (level - 1) * 2.0;
  }

  double get _kineticSynergyShare {
    final level = _upgradeLevel(kineticSynergyId);
    if (level <= 0) return 0.0;
    return 0.01 * level;
  }

  double get _momentumPerClickBonus {
    final level = _upgradeLevel(momentumId);
    if (level <= 0) return 0.0;
    return 0.02 + (level - 1) * 0.006;
  }

  double get _momentumCap {
    final level = _upgradeLevel(momentumId);
    if (level <= 0) return 1.0;
    return 2.0 + (level - 1) * 0.35 + momentumCapBonus;
  }

  int get _momentumDecayWindowMs {
    final level = _upgradeLevel(momentumId);
    if (level <= 0) return 1000;
    return math.min(2500, 1000 + (level - 1) * 120);
  }

  int get _momentumGracePeriodMs => 2000; // 2 second grace period before decay

  int get _momentumClicksToCap {
    final level = _upgradeLevel(momentumId);
    if (level <= 0) return 50;
    final perClick = _momentumPerClickBonus;
    final cap = _momentumCap;
    final needed = ((cap - 1.0) / perClick).ceil() + 1;
    return math.max(5, needed);
  }

  int get _overclockStreakRequirement {
    final level = _upgradeLevel(overclockId);
    if (level <= 0) return 50;
    return math.max(20, 50 - (level - 1) * 3);
  }

  double get _overclockIdleMultiplier {
    final level = _upgradeLevel(overclockId);
    if (level <= 0) return 2.0;
    return 2.0 + (level - 1) * 0.4;
  }

  int get _overclockDurationSeconds {
    final level = _upgradeLevel(overclockId);
    if (level <= 0) return 30;
    return math.min(180, 30 + (level - 1) * 5);
  }

  bool _isUpgradeActive(String id) => (_upgradeById(id)?.level ?? 0) > 0;

  bool _updateMomentumDecay() {
    if (!_isUpgradeActive(momentumId) || _lastManualClickTime == null) {
      if (_momentumProgress != 0.0 || _momentumMultiplier != 1.0) {
        _momentumProgress = 0.0;
        _momentumMultiplier = 1.0;
        return true;
      }
      return false;
    }

    final elapsedMs =
        DateTime.now().difference(_lastManualClickTime!).inMilliseconds;
    if (elapsedMs <= 0) return false;

    bool changed = false;
    final baseProgress = (_clickStreak / _momentumClicksToCap).clamp(0.0, 1.0);
    final fullMomentumMultiplier =
        (1.0 + ((_clickStreak - 1) * _momentumPerClickBonus))
            .clamp(1.0, _momentumCap);

    // Grace period: keep momentum at full for 2 seconds after last click
    if (elapsedMs < _momentumGracePeriodMs) {
      // Keep current values, no decay yet
      if ((_momentumProgress - baseProgress).abs() > 0.001) {
        _momentumProgress = baseProgress;
        changed = true;
      }
      if ((_momentumMultiplier - fullMomentumMultiplier).abs() > 0.001) {
        _momentumMultiplier = fullMomentumMultiplier;
        changed = true;
      }
      return changed;
    }

    // After grace period, check if total time exceeded
    final totalDecayWindow = _momentumGracePeriodMs + _momentumDecayWindowMs;
    if (elapsedMs >= totalDecayWindow) {
      if (_momentumProgress != 0.0 ||
          _momentumMultiplier != 1.0 ||
          _clickStreak != 0 ||
          _overclockTriggeredThisChain) {
        _momentumProgress = 0.0;
        _momentumMultiplier = 1.0;
        _clickStreak = 0;
        _overclockTriggeredThisChain = false;
        changed = true;
      }
      return changed;
    }

    // Start decaying after grace period
    final decayElapsed = elapsedMs - _momentumGracePeriodMs;
    final decayFactor = 1.0 - (decayElapsed / _momentumDecayWindowMs);
    final decayedProgress = baseProgress * decayFactor;
    final decayedMultiplier =
        1.0 + (fullMomentumMultiplier - 1.0) * decayFactor;

    if ((_momentumProgress - decayedProgress).abs() > 0.001) {
      _momentumProgress = decayedProgress;
      changed = true;
    }
    if ((_momentumMultiplier - decayedMultiplier).abs() > 0.001) {
      _momentumMultiplier = decayedMultiplier;
      changed = true;
    }
    return changed;
  }

  ({
    BigInt gain,
    bool probabilityStrikeTriggered,
    bool personalBestReached,
  }) click() {
    final now = DateTime.now();
    final bool chainBroken = _lastManualClickTime == null ||
        now.difference(_lastManualClickTime!).inMilliseconds > 1000;

    if (chainBroken) {
      _clickStreak = 0;
      _overclockTriggeredThisChain = false;
      _momentumMultiplier = 1.0;
      _momentumProgress = 0.0;
    }

    _clickStreak++;
    lifetimeClicks++;
    _lastManualClickTime = now;
    _recordClickForRate(now.millisecondsSinceEpoch);

    if (_isUpgradeActive(momentumId)) {
      final comboBonus = (_clickStreak - 1) * _momentumPerClickBonus;
      final newMultiplier = (1.0 + comboBonus).clamp(1.0, _momentumCap);
      final newProgress = (_clickStreak / _momentumClicksToCap).clamp(0.0, 1.0);

      // Always update on click to ensure UI stays responsive
      _momentumMultiplier = newMultiplier;
      _momentumProgress = newProgress;
    } else {
      _momentumMultiplier = 1.0;
      _momentumProgress = 0.0;
    }

    if (_isUpgradeActive(overclockId) &&
        _clickStreak >= _overclockStreakRequirement &&
        !_overclockTriggeredThisChain) {
      _overclockTriggeredThisChain = true;
      _activateOverclock();
    }

    final bool probabilityStrikeTriggered =
        _isUpgradeActive(probabilityStrikeId) &&
            _rng.nextDouble() < _probabilityStrikeChance;

    final baseClickGain = clickPower.toDouble() *
        prestigeMultiplier *
        _temporalCollapseFactor *
        neuralLossMultiplier *
        globalProductionMultiplier *
        shopClickMultiplier *
        shopTimedProductionMultiplier;
    // kineticBonus inherits every multiplier via totalIdleRate, so we don't
    // multiply it again here.
    final kineticBonus = totalIdleRate * _kineticSynergyShare;

    double gain = (baseClickGain + kineticBonus) * _effectiveMomentumMultiplier;
    if (probabilityStrikeTriggered) {
      _unlockAchievement(Achievements.firstStrike);
      final unstruck = gain;
      gain *= _probabilityStrikeMultiplier;
      // Loaded Dice: each chain pays another full strike.
      final chainChance =
          Artifacts.strikeChainChance(_artifactLevel(Artifacts.loadedDice));
      var chains = 0;
      while (chains < 3 && _rng.nextDouble() < chainChance) {
        gain += unstruck * _probabilityStrikeMultiplier;
        chains++;
      }
    }
    if (_neuralSparkBoostMultiplier != 1.0) {
      gain *= _neuralSparkBoostMultiplier;
    }
    gain += _echoChamberBonus(gain);
    if (_momentumProgress >= 1.0) {
      _unlockAchievement(Achievements.maxMomentum);
    }

    final previousHighest = highestNumber;
    final gained = wholeBigInt(gain);
    number += gained;
    _updateHighestNumber();
    _advanceTutorialOnNumberReached();
    _checkTutorialTriggers();
    final personalBestReached = highestNumber > previousHighest;

    // The number always changes on a click, so this always notifies;
    // Selectors keep the resulting rebuilds narrow.
    notifyListeners();

    _scheduleStateSave();
    return (
      gain: gained,
      probabilityStrikeTriggered: probabilityStrikeTriggered,
      personalBestReached: personalBestReached,
    );
  }

  /// Perpetual Motion keeps momentum from dropping below a share of its cap.
  double get _effectiveMomentumMultiplier {
    final floorShare =
        Artifacts.momentumFloor(_artifactLevel(Artifacts.perpetualMotion));
    if (floorShare <= 0 || !_isUpgradeActive(momentumId)) {
      return _momentumMultiplier;
    }
    final floor = 1.0 + (_momentumCap - 1.0) * floorShare;
    return _momentumMultiplier > floor ? _momentumMultiplier : floor;
  }

  /// Echo Chamber: records [gain], and on every Nth tap returns a share of
  /// the last few taps' total as a bonus.
  double _echoChamberBonus(double gain) {
    final level = _artifactLevel(Artifacts.echoChamber);
    if (level <= 0) return 0.0;
    _echoRecentGains.add(gain);
    if (_echoRecentGains.length > Artifacts.echoWindow) {
      _echoRecentGains.removeAt(0);
    }
    _echoClickCounter++;
    if (_echoClickCounter < Artifacts.echoInterval) return 0.0;
    _echoClickCounter = 0;
    final total = _echoRecentGains.fold<double>(0.0, (a, b) => a + b);
    return total * Artifacts.echoShare(level);
  }

  /// Called when the player catches a "Neural Spark" — the tap minigame
  /// spawned by [MainGameScreen]. Grants a temporary click-power multiplier
  /// so catching one rewards a short burst of active play, distinct from the
  /// idle-focused Temporal Collapse ability.
  void activateNeuralSparkBoost({
    double multiplier = 2.0,
    Duration duration = const Duration(seconds: 10),
  }) {
    _neuralSparkBoostTimer?.cancel();
    _neuralSparkBoostMultiplier = multiplier;
    _unlockAchievement(Achievements.sparkCatcher);
    if (_tutorialStep == TutorialStep.catchSpark) {
      _tutorialStep = TutorialStep.roadAhead;
      _scheduleStateSave();
    }
    notifyListeners();

    _neuralSparkBoostTimer = Timer(duration, () {
      _neuralSparkBoostMultiplier = 1.0;
      notifyListeners();
    });
  }

  void _activateOverclock({int? durationOverrideSeconds}) {
    _overclockTimer?.cancel();
    final durationSeconds =
        durationOverrideSeconds ?? _overclockDurationSeconds;
    _overclockActive = true;
    _unlockAchievement(Achievements.firstOverclock);
    notifyListeners();

    _overclockTimer = Timer(Duration(seconds: durationSeconds), () {
      _overclockActive = false;
      notifyListeners();
    });
  }

  // ── Temporal Collapse active ability ──────────────────────────────────────

  bool get isTemporalCollapseActive => _temporalCollapseActive;
  bool get isTemporalCollapseCoolingDown => _temporalCollapseCoolingDown;

  int get _temporalCollapseLevel =>
      _upgradeById(temporalCollapseId)?.level ?? 0;

  int get temporalCollapseDurationSeconds {
    final lvl = _temporalCollapseLevel;
    final factor =
        Artifacts.tempoDurationFactor(_artifactLevel(Artifacts.tempoAnchor));
    return ((30 + lvl * 15) * factor).round();
  }

  int get temporalCollapseCooldownSeconds {
    final lvl = _temporalCollapseLevel;
    final base = math.max(80, 180 - lvl * 20);
    final anchor = _artifactLevel(Artifacts.tempoAnchor);
    final afterAnchor = anchor <= 0
        ? base
        : math.max(Artifacts.tempoCooldownFloorSeconds,
            (base * Artifacts.tempoCooldownFactor(anchor)).round());
    return math.max(
      1,
      (afterAnchor * shopInventory.collapseCooldownFactor).round(),
    );
  }

  bool get canActivateTemporalCollapse =>
      _temporalCollapseLevel > 0 &&
      !_temporalCollapseActive &&
      !_temporalCollapseCoolingDown;

  void activateTemporalCollapse() {
    if (!canActivateTemporalCollapse) return;

    final level = _temporalCollapseLevel;
    // Instant burst: level × 60 seconds of current idle production
    final burst = wholeBigInt(totalIdleRate * 60 * level);
    number += burst;
    _updateHighestNumber();

    // Doubles production for the duration via _temporalCollapseFactor.
    _temporalCollapseActive = true;
    _unlockAchievement(Achievements.firstCollapse);
    notifyListeners();

    _temporalCollapseActiveTimer?.cancel();
    _temporalCollapseActiveTimer =
        Timer(Duration(seconds: temporalCollapseDurationSeconds), () {
      _temporalCollapseActive = false;
      _temporalCollapseCoolingDown = true;
      notifyListeners();

      _temporalCollapseCooldownTimerRef?.cancel();
      _temporalCollapseCooldownTimerRef =
          Timer(Duration(seconds: temporalCollapseCooldownSeconds), () {
        _temporalCollapseCoolingDown = false;
        notifyListeners();
      });
    });
  }

  // ── Real-money shop (mock grant until IAP is wired) ─────────────────────

  bool ownsShopProduct(String productId) => shopInventory.owns(productId);

  Duration? shopSparkSurgeRemaining() {
    final expires = shopInventory.sparkSurgeExpiresAt;
    if (expires == null) return null;
    final left = expires.difference(DateTime.now().toUtc());
    if (left.isNegative) return null;
    return left;
  }

  /// Whether [productId] can be granted right now (owned check, gates, etc.).
  ShopPurchaseResult shopPurchaseAvailability(String productId) {
    final product = ShopCatalog.byId(productId);
    if (product == null) return ShopPurchaseResult.unknownProduct;
    if (product.isPermanent && shopInventory.owns(productId)) {
      return ShopPurchaseResult.alreadyOwned;
    }
    switch (product.effect) {
      case ShopEffect.collapseReady:
        if (_temporalCollapseLevel <= 0 || !_temporalCollapseCoolingDown) {
          return ShopPurchaseResult.notAvailable;
        }
        return ShopPurchaseResult.success;
      case ShopEffect.quickResume:
        if (totalIdleRate <= 0) return ShopPurchaseResult.noIdleToClaim;
        return ShopPurchaseResult.success;
      default:
        return ShopPurchaseResult.success;
    }
  }

  /// Mock purchase: grants the effect immediately while [mockShopPurchases]
  /// is true. Before release, set that flag false and replace this body with
  /// store billing + receipt validation, then call [_grantShopProduct].
  Future<ShopPurchaseResult> purchaseShopProduct(String productId) async {
    final availability = shopPurchaseAvailability(productId);
    if (availability != ShopPurchaseResult.success) return availability;

    if (!mockShopPurchases) {
      // TODO(iap): launch billing, verify receipt, then _grantShopProduct.
      return ShopPurchaseResult.notAvailable;
    }
    return _grantShopProduct(productId);
  }

  /// Dev/test helper: grant without going through [purchaseShopProduct].
  @visibleForTesting
  ShopPurchaseResult debugGrantShopProduct(String productId) =>
      _grantShopProduct(productId);

  ShopPurchaseResult _grantShopProduct(String productId) {
    final product = ShopCatalog.byId(productId);
    if (product == null) return ShopPurchaseResult.unknownProduct;

    final availability = shopPurchaseAvailability(productId);
    if (availability != ShopPurchaseResult.success) return availability;

    switch (product.effect) {
      case ShopEffect.sparkSurge:
        _activateShopSparkSurge();
        break;
      case ShopEffect.overclockCharge:
        _activateOverclock(durationOverrideSeconds: 60);
        break;
      case ShopEffect.collapseReady:
        _temporalCollapseCooldownTimerRef?.cancel();
        _temporalCollapseCoolingDown = false;
        break;
      case ShopEffect.quickResume:
        final claim = wholeBigInt(totalIdleRate * 3600);
        if (claim <= BigInt.zero) return ShopPurchaseResult.noIdleToClaim;
        number += claim;
        _updateHighestNumber();
        break;
      case ShopEffect.clickPrimer:
      case ShopEffect.idlePrimer:
      case ShopEffect.chronoChip:
      case ShopEffect.sparkMagnet:
      case ShopEffect.kineticAmplifier:
      case ShopEffect.idleAmplifier:
      case ShopEffect.chronoLensPro:
      case ShopEffect.collapseEfficiency:
      case ShopEffect.surgeProtocol:
      case ShopEffect.neuralPatron:
      case ShopEffect.prestigeDividend:
        shopInventory.grantPermanent(productId);
        break;
    }

    notifyListeners();
    _scheduleStateSave();
    return ShopPurchaseResult.success;
  }

  void _activateShopSparkSurge({
    Duration duration = const Duration(minutes: 5),
  }) {
    _shopSparkSurgeTimer?.cancel();
    final expires = DateTime.now().toUtc().add(duration);
    shopInventory.sparkSurgeExpiresAt = expires;
    _shopSparkSurgeMultiplier = 1.5;
    notifyListeners();

    _shopSparkSurgeTimer = Timer(duration, () {
      _shopSparkSurgeMultiplier = 1.0;
      shopInventory.sparkSurgeExpiresAt = null;
      notifyListeners();
      _scheduleStateSave();
    });
  }

  /// Restore a Spark Surge timer after load if the expiry is still in the future.
  void _restoreShopSparkSurgeFromInventory() {
    _shopSparkSurgeTimer?.cancel();
    final expires = shopInventory.sparkSurgeExpiresAt;
    if (expires == null) {
      _shopSparkSurgeMultiplier = 1.0;
      return;
    }
    final remaining = expires.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      shopInventory.sparkSurgeExpiresAt = null;
      _shopSparkSurgeMultiplier = 1.0;
      return;
    }
    _shopSparkSurgeMultiplier = 1.5;
    _shopSparkSurgeTimer = Timer(remaining, () {
      _shopSparkSurgeMultiplier = 1.0;
      shopInventory.sparkSurgeExpiresAt = null;
      notifyListeners();
      _scheduleStateSave();
    });
  }

  void _clearShopTimedBoosts() {
    _shopSparkSurgeTimer?.cancel();
    _shopSparkSurgeMultiplier = 1.0;
    shopInventory.sparkSurgeExpiresAt = null;
  }

  void setBuyAmount(int amount) {
    buyAmount = amount;
    notifyListeners();
  }

  void setSelectedUpgradeCategory(String category) {
    if (category != clickCategory && category != idleCategory) return;

    // Advance the tutorial BEFORE the no-op early return. With the check
    // after it, `selectIdle` was unreachable whenever the category already
    // happened to be IDLE — which is exactly the state a resumed tutorial
    // can start in, wedging the step permanently.
    final advancing =
        _tutorialStep == TutorialStep.selectIdle && category == idleCategory;
    if (advancing) {
      _tutorialStep = TutorialStep.buyAutoClicker;
    }

    if (selectedUpgradeCategory == category) {
      if (advancing) notifyListeners();
      return;
    }
    selectedUpgradeCategory = category;
    notifyListeners();
  }

  final Map<String, (int, int, BigInt, double, ({BigInt cost, int amount}))> _purchaseInfoCache = {};

  ({BigInt cost, int amount}) getPurchaseInfo(Upgrade upgrade) {
    final costFactor = upgradeCostReductionFactor;
    final cached = _purchaseInfoCache[upgrade.id];
    if (cached != null &&
        cached.$1 == upgrade.level &&
        cached.$2 == buyAmount &&
        cached.$3 == number &&
        cached.$4 == costFactor) {
      return cached.$5;
    }

    int toBuy;
    if (buyAmount == -1) {
      toBuy = 999999;
    } else if (buyAmount == -2) {
      final nextMilestone = upgradeMilestoneThresholds
          .where((threshold) => threshold > upgrade.level)
          .firstOrNull;
      if (nextMilestone == null) {
        toBuy = 1;
      } else {
        toBuy = nextMilestone - upgrade.level;
      }
    } else {
      toBuy = buyAmount;
    }
    if (upgrade.maxLevel != -1) {
      final remainingLevels = upgrade.maxLevel - upgrade.level;
      if (remainingLevels <= 0) {
        final zeroRes = (cost: BigInt.zero, amount: 0);
        _purchaseInfoCache[upgrade.id] = (upgrade.level, buyAmount, number, costFactor, zeroRes);
        return zeroRes;
      }
      toBuy = math.min(toBuy, remainingLevels);
    }

    final isMaxMode = buyAmount == -1;
    int bought = 0;
    BigInt totalCost = BigInt.zero;
    BigInt remainingNumber = number;

    double currentMultiplier = _costMultiplierAtLevel(upgrade);

    while (bought < toBuy) {
      BigInt cost = BigInt.from(
          upgrade.baseCost.toDouble() * currentMultiplier * costFactor);
      if (remainingNumber >= cost) {
        remainingNumber -= cost;
        totalCost += cost;
        bought++;
        currentMultiplier *= upgrade.costMultiplier;
      } else {
        if (isMaxMode) {
          break; // Max reached
        } else {
          // Calculate remaining cost anyway
          totalCost += cost;
          bought++;
          currentMultiplier *= upgrade.costMultiplier;
          while (bought < toBuy) {
            cost = BigInt.from(
                upgrade.baseCost.toDouble() * currentMultiplier * costFactor);
            totalCost += cost;
            bought++;
            currentMultiplier *= upgrade.costMultiplier;
          }
          break;
        }
      }
    }

    int finalAmount = isMaxMode ? bought : toBuy;
    final ({BigInt cost, int amount}) result;
    if (isMaxMode && finalAmount == 0) {
      final singleCost = BigInt.from(
          upgrade.baseCost.toDouble() * currentMultiplier * costFactor);
      result = (cost: singleCost, amount: 0);
    } else {
      result = (cost: totalCost, amount: finalAmount);
    }

    _purchaseInfoCache[upgrade.id] = (upgrade.level, buyAmount, number, costFactor, result);
    return result;
  }

  /// `costMultiplier ^ level`, computed as the repeated product it has always
  /// been (not `math.pow`, which can round differently) but extended
  /// incrementally from the last level seen instead of from zero. The
  /// upgrades list rebuilds every row on each tick, so the from-zero loop
  /// cost O(level) per row per tick.
  final Map<String, (int, double)> _costMultiplierCache = {};

  double _costMultiplierAtLevel(Upgrade upgrade) {
    final level = upgrade.level;
    final cached = _costMultiplierCache[upgrade.id];
    int i = 0;
    double multiplier = 1.0;
    if (cached != null && cached.$1 <= level) {
      i = cached.$1;
      multiplier = cached.$2;
    }
    for (; i < level; i++) {
      multiplier *= upgrade.costMultiplier;
    }
    _costMultiplierCache[upgrade.id] = (level, multiplier);
    return multiplier;
  }

  int minPrestigeForUpgrade(String id) {
    if (id == dimensionalTapId) return 1;
    if (id == 'click_chronos_press') return 2;
    if (id == 'idle_neutron_reactor') return 3;
    if (id == 'click_hyperdimensional_strike') return 4;
    if (id == cascadeResonatorId) return 5;
    if (id == 'idle_multiverse_synthesizer') return 6;
    if (id == 'click_omni_touch') return 7;
    if (id == temporalCollapseId) return 8;
    if (id == 'idle_tachyon_accelerator') return 10;
    return 0;
  }

  /// Exact price of [count] levels starting at [fromLevel], computed the
  /// same way as [getPurchaseInfo] (a repeated product, then the Nexus
  /// discount per level) so quoted and charged prices always agree.
  BigInt _costOfLevels(Upgrade upgrade, int fromLevel, int count) {
    double multiplier = 1.0;
    for (int i = 0; i < fromLevel; i++) {
      multiplier *= upgrade.costMultiplier;
    }
    final costFactor = upgradeCostReductionFactor;
    final base = upgrade.baseCost.toDouble();
    BigInt total = BigInt.zero;
    for (int i = 0; i < count; i++) {
      total += BigInt.from(base * multiplier * costFactor);
      multiplier *= upgrade.costMultiplier;
    }
    return total;
  }

  bool _canBuy(Upgrade upgrade) =>
      !upgrade.isMaxed &&
      prestigeCount >= minPrestigeForUpgrade(upgrade.id);

  void buyUpgrade(String id) {
    final upgrade = upgrades.firstWhere((u) => u.id == id);
    if (!_canBuy(upgrade)) return;

    final info = getPurchaseInfo(upgrade);

    if (info.amount == 0) return;
    _completePurchase(upgrade, info.amount, info.cost);
  }

  /// Buys exactly [count] levels of [id], ignoring the buy-amount toggle.
  /// Used by the recommendation card, which picks its own amount.
  bool buyUpgradeLevels(String id, int count) {
    final upgrade = _upgradeById(id);
    if (upgrade == null || count <= 0 || !_canBuy(upgrade)) return false;
    if (upgrade.maxLevel != -1) {
      count = math.min(count, upgrade.maxLevel - upgrade.level);
      if (count <= 0) return false;
    }
    return _completePurchase(
        upgrade, count, _costOfLevels(upgrade, upgrade.level, count));
  }

  bool _completePurchase(Upgrade upgrade, int amount, BigInt cost) {
    if (number < cost) return false;
    number -= cost;
    upgrade.level += amount;
    _recalculateDerivedStatsFromUpgrades();
    _recommendationComputedAtMs = 0;
    _advanceTutorialOnPurchase(upgrade.id);
    _checkAchievements();
    notifyListeners();
    _saveState();
    return true;
  }

  // ── Upgrade gain previews & the upgrade advisor ────────────────────────
  //
  // Both run the real production formulas against temporarily raised
  // upgrade levels (see [_withExtraLevels]) instead of re-deriving them, so a
  // new multiplier anywhere in the game is picked up automatically.

  /// Manual tap timestamps (ms since epoch) from the last minute.
  final List<int> _recentClickMs = [];
  static const int _clickRateWindowMs = 60000;

  /// Test hook: pins [recentClickRate] instead of measuring taps.
  @visibleForTesting
  double? debugClickRateOverride;

  /// Test hook: re-derive click power / idle rate after editing levels.
  @visibleForTesting
  void debugRecalculateDerivedStats() {
    _recalculateDerivedStatsFromUpgrades();
    _recommendationComputedAtMs = 0;
  }

  /// Test hook: force Temporal Collapse into cooldown for shop grant tests.
  @visibleForTesting
  void debugSetTemporalCollapseCoolingDown(bool value) {
    _temporalCollapseCoolingDown = value;
    notifyListeners();
  }

  void _recordClickForRate(int nowMs) {
    _recentClickMs.add(nowMs);
    final cutoff = nowMs - _clickRateWindowMs;
    var drop = 0;
    while (drop < _recentClickMs.length && _recentClickMs[drop] < cutoff) {
      drop++;
    }
    if (drop > 0) _recentClickMs.removeRange(0, drop);
  }

  /// Taps per second over the last minute. Divides by the time actually
  /// observed (at least 10s), so the first seconds of a tapping burst don't
  /// read as a slow pace.
  double get recentClickRate {
    final override = debugClickRateOverride;
    if (override != null) return override;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoff = nowMs - _clickRateWindowMs;
    final first = _recentClickMs.indexWhere((t) => t >= cutoff);
    if (first < 0) return 0.0;
    final count = _recentClickMs.length - first;
    final spanMs =
        (nowMs - _recentClickMs[first]).clamp(10000, _clickRateWindowMs);
    return count / (spanMs / 1000.0);
  }

  /// Runs [body] with [extra] levels added on top of the real ones, then
  /// puts everything back. Nests safely. Purely synchronous and never
  /// notifies, so no listener can observe the borrowed levels.
  T _withExtraLevels<T>(Map<String, int> extra, T Function() body) {
    final saved = <Upgrade, int>{};
    for (final entry in extra.entries) {
      if (entry.value == 0) continue;
      final upgrade = _upgradeById(entry.key);
      if (upgrade == null) continue;
      saved[upgrade] = upgrade.level;
      upgrade.level += entry.value;
    }
    if (saved.isEmpty) return body();
    // Both are derived purely from levels, so putting them back is exact
    // and saves a second full recalculation per simulated purchase.
    final savedClickPower = clickPower;
    final savedAutoClickRate = autoClickRate;
    _recalculateDerivedStatsFromUpgrades();
    try {
      return body();
    } finally {
      saved.forEach((upgrade, level) => upgrade.level = level);
      clickPower = savedClickPower;
      autoClickRate = savedAutoClickRate;
    }
  }

  /// Idle rate and per-tap value with every permanent multiplier, but none
  /// of the timed boosts (Overclock, Temporal Collapse, Neural Spark, shop
  /// Spark Surge) or the momentum combo — the numbers the player keeps.
  ({double idle, double perClick}) _steadyProduction() {
    final overclock = _overclockActive;
    final collapse = _temporalCollapseActive;
    final surge = _shopSparkSurgeMultiplier;
    _overclockActive = false;
    _temporalCollapseActive = false;
    _shopSparkSurgeMultiplier = 1.0;
    try {
      final idle = totalIdleRate;
      final perClick = clickPower.toDouble() *
              prestigeMultiplier *
              neuralLossMultiplier *
              globalProductionMultiplier *
              shopClickMultiplier +
          idle * _kineticSynergyShare;
      return (idle: idle, perClick: perClick);
    } finally {
      _overclockActive = overclock;
      _temporalCollapseActive = collapse;
      _shopSparkSurgeMultiplier = surge;
    }
  }

  static String _x(double v, [int digits = 2]) => '×${v.toStringAsFixed(digits)}';
  static String _pctOf(double v) {
    final p = v * 100;
    return p == p.roundToDouble()
        ? '${p.toStringAsFixed(0)}%'
        : '${p.toStringAsFixed(1)}%';
  }

  /// What buying [levels] more levels of [upgrade] actually adds, after all
  /// multipliers. The upgrade rows show this instead of the raw base effect
  /// ("+1 click power"), which stopped meaning anything once prestige,
  /// milestones, neural and artifact multipliers stacked up.
  UpgradeGainPreview upgradeGainPreview(Upgrade upgrade, int levels) {
    var count = levels < 1 ? 1 : levels;
    if (upgrade.maxLevel != -1) {
      count = math.min(count, upgrade.maxLevel - upgrade.level);
    }
    if (count <= 0) return const UpgradeGainPreview();

    final before = _steadyProduction();
    final bStrike = _probabilityStrikeMultiplier;
    final bCap = _momentumCap;
    final bSurge = _overclockIdleMultiplier;
    final bSurgeSecs = _overclockDurationSeconds;
    final bStreak = _overclockStreakRequirement;
    final bShare = _kineticSynergyShare;
    final bCollapseLvl = _temporalCollapseLevel;
    final bCollapseSecs = temporalCollapseDurationSeconds;
    final bCooldown = temporalCollapseCooldownSeconds;
    final bCascade = math.pow(2.0, _cascadeResonatorLevel).toDouble();
    final owned = upgrade.level > 0;

    return _withExtraLevels({upgrade.id: count}, () {
      final after = _steadyProduction();
      switch (upgrade.id) {
        case probabilityStrikeId:
          final chance = _probabilityStrikeChance;
          final aStrike = _probabilityStrikeMultiplier;
          return UpgradeGainPreview(
            // Average over many taps: chance × the extra strike payout.
            perClick: after.perClick * chance * (aStrike - bStrike),
            qualifier: 'avg',
            detail: owned
                ? 'Strikes ${_x(bStrike, 0)} → ${_x(aStrike, 0)} · ${_pctOf(chance)} chance'
                : '${_pctOf(chance)} of taps strike for ${_x(aStrike, 0)}',
          );
        case momentumId:
          final aCap = _momentumCap;
          return UpgradeGainPreview(
            perClick: after.perClick * (aCap - bCap),
            qualifier: 'at max combo',
            detail: 'Max combo ${_x(bCap)} → ${_x(aCap)}',
          );
        case overclockId:
          final aSurge = _overclockIdleMultiplier;
          final aSecs = _overclockDurationSeconds;
          final aStreak = _overclockStreakRequirement;
          return UpgradeGainPreview(
            perSecond: after.idle * (owned ? aSurge - bSurge : aSurge - 1),
            qualifier: 'while surging',
            detail: owned
                ? 'Surge ${_x(bSurge, 1)} → ${_x(aSurge, 1)} · ${bSurgeSecs}s → ${aSecs}s · streak $bStreak → $aStreak'
                : '$aStreak-tap streak surges idle ${_x(aSurge, 1)} for ${aSecs}s',
          );
        case temporalCollapseId:
          final aLvl = _temporalCollapseLevel;
          return UpgradeGainPreview(
            perSecond: 0,
            detail: bCollapseLvl > 0
                ? 'Burst ${bCollapseLvl * 60}s → ${aLvl * 60}s of idle · ×2 for ${bCollapseSecs}s → ${temporalCollapseDurationSeconds}s · cooldown ${bCooldown}s → ${temporalCollapseCooldownSeconds}s'
                : 'Burst ${aLvl * 60}s of idle, then ×2 for ${temporalCollapseDurationSeconds}s · cooldown ${temporalCollapseCooldownSeconds}s',
          );
        case kineticSynergyId:
          return UpgradeGainPreview(
            perClick: after.perClick - before.perClick,
            detail: 'Taps add ${_pctOf(bShare)} → ${_pctOf(_kineticSynergyShare)} of idle/s',
          );
        case cascadeResonatorId:
          final aCascade = math.pow(2.0, _cascadeResonatorLevel).toDouble();
          return UpgradeGainPreview(
            perSecond: after.idle - before.idle,
            detail: 'Idle ${_x(bCascade, 0)} → ${_x(aCascade, 0)}',
          );
      }
      if (upgrade.effectType == idleCategory) {
        return UpgradeGainPreview(perSecond: after.idle - before.idle);
      }
      return UpgradeGainPreview(perClick: after.perClick - before.perClick);
    });
  }

  // ── Advisor ──

  /// Pace the advisor assumes. A player with no idle income yet has to tap,
  /// so they are assumed to tap at a relaxed pace rather than having every
  /// upgrade valued at zero before their first measured taps.
  double get _advisorClickRate {
    final measured = recentClickRate;
    if (measured < 0.5 && autoClickRate <= 0) return 4.0;
    return measured;
  }

  /// Average momentum multiplier over a ~2 minute tapping burst: the combo
  /// climbs every tap until the cap. Tap chains break after a 1s gap, so a
  /// pace under 1 tap/s never builds combo at all.
  double _expectedMomentumFactor(double rate) {
    if (!_isUpgradeActive(momentumId)) return 1.0;
    final cap = _momentumCap;
    final floorShare =
        Artifacts.momentumFloor(_artifactLevel(Artifacts.perpetualMotion));
    final floor = 1.0 + (cap - 1.0) * floorShare;
    final engagement = ((rate - 1.0) / 0.5).clamp(0.0, 1.0);
    if (engagement <= 0) return floor;
    final per = _momentumPerClickBonus;
    const burstTaps = 120;
    var sum = 0.0;
    for (var n = 1; n <= burstTaps; n++) {
      final m = math.min(1.0 + (n - 1) * per, cap);
      sum += m > floor ? m : floor;
    }
    return floor + (sum / burstTaps - floor) * engagement;
  }

  /// Expected payout of a tap relative to an unstruck tap, chains included.
  double get _expectedStrikeFactor {
    if (!_isUpgradeActive(probabilityStrikeId)) return 1.0;
    final chance = _probabilityStrikeChance;
    final c =
        Artifacts.strikeChainChance(_artifactLevel(Artifacts.loadedDice));
    final chains = c + c * c + c * c * c;
    return 1.0 + chance * (_probabilityStrikeMultiplier * (1.0 + chains) - 1.0);
  }

  double get _expectedEchoFactor =>
      1.0 +
      Artifacts.echoShare(_artifactLevel(Artifacts.echoChamber)) *
          Artifacts.echoWindow /
          Artifacts.echoInterval;

  /// Share of the time an Overclock surge is running. One surge per
  /// unbroken tap chain, modelled as ~1 minute bursts with short breaks,
  /// plus Overclock Core's automatic surges.
  double _expectedOverclockUptime(double rate) {
    final duration = _overclockDurationSeconds.toDouble();
    var uptime = 0.0;
    if (_isUpgradeActive(overclockId) && rate >= 1.0) {
      const burstSeconds = 60.0;
      const cycleSeconds = burstSeconds + 15.0;
      final secondsToTrigger = _overclockStreakRequirement / rate;
      if (secondsToTrigger < burstSeconds) {
        uptime += math.min(duration, cycleSeconds - secondsToTrigger) /
            cycleSeconds;
      }
    }
    final core =
        Artifacts.overclockCoreInterval(_artifactLevel(Artifacts.overclockCore));
    if (core != null) uptime += duration / core;
    return uptime.clamp(0.0, 1.0);
  }

  /// Numbers per second the player can expect to earn at [rate] taps/s,
  /// averaging in every tap and timed effect they own. The advisor ranks
  /// purchases by how much they raise this.
  double _expectedValuePerSecond(double rate) {
    final p = _steadyProduction();
    final tap = p.perClick *
        _expectedMomentumFactor(rate) *
        _expectedStrikeFactor *
        _expectedEchoFactor;
    final uptime = _expectedOverclockUptime(rate);
    final idle = p.idle * (1.0 + uptime * (_overclockIdleMultiplier - 1.0));
    var total = idle + rate * tap;
    final collapseLevel = _temporalCollapseLevel;
    if (collapseLevel > 0) {
      // Assumes the ability is fired whenever it comes off cooldown.
      final active = temporalCollapseDurationSeconds.toDouble();
      final cycle = active + temporalCollapseCooldownSeconds;
      total = total * (1.0 + active / cycle) + p.idle * 60 * collapseLevel / cycle;
    }
    return total;
  }

  /// Test hook for the pacing simulation: expected income at [rate] taps/s,
  /// split into what idle pays and what tapping adds on top.
  @visibleForTesting
  ({double idle, double tapping}) debugExpectedIncome(double rate) {
    final total = _expectedValuePerSecond(rate);
    final idle = _steadyProduction().idle;
    return (idle: idle, tapping: total - idle);
  }

  UpgradeRecommendation? _cachedRecommendation;
  int _recommendationSignature = 0;
  int _recommendationComputedAtMs = 0;
  static const int _recommendationRefreshMs = 1000;

  /// The advisor hides while onboarding is steering purchases.
  bool get _tutorialSteersPurchases =>
      specFor(_tutorialStep).scope == TutorialScope.main;

  /// The single best purchase right now, and how many levels of it.
  ///
  /// Every candidate (1 level, or enough levels to reach the next ×2
  /// milestone) is scored by `time to afford + time to pay back`:
  ///
  ///     max(0, cost − number) / income  +  cost / Δincome
  ///
  /// where income is [_expectedValuePerSecond] at the player's measured tap
  /// pace. That is the time until the purchase has been paid for *and*
  /// earned itself back, so it naturally prefers cheap quick wins early,
  /// values a milestone jump when one is close, weighs click upgrades by
  /// how much this player actually taps, and never points at something
  /// hours away when a good buy is available now.
  ///
  /// The pick is then extended by planning the whole current balance
  /// greedily — buy the winner (in simulation), rescore everything, repeat
  /// while affordable — and recommending every level of the first pick
  /// that plan contains. The result is "buy 7×", not "buy one, then look
  /// again".
  ///
  /// Cached for a second, and refreshed immediately after any purchase.
  UpgradeRecommendation? get recommendedUpgrade {
    if (_tutorialSteersPurchases) return null;
    final nowMs = clock().millisecondsSinceEpoch;
    final signature = Object.hash(
      Object.hashAll(upgrades.map((u) => u.level)),
      prestigeCount,
      _recentClickMs.isEmpty,
    );
    if (signature == _recommendationSignature &&
        nowMs - _recommendationComputedAtMs < _recommendationRefreshMs) {
      return _cachedRecommendation;
    }
    _recommendationSignature = signature;
    _recommendationComputedAtMs = nowMs;
    return _cachedRecommendation = _computeRecommendation();
  }

  UpgradeRecommendation? _computeRecommendation() {
    final rate = _advisorClickRate;
    final baseValue = _expectedValuePerSecond(rate);
    if (!(baseValue > 0)) return null;

    // Plan how the current balance is best spent, one greedy pick at a time.
    // The idle tiers share one cost-per-effect, so the best pick often
    // alternates between neighbours level by level; the recommendation is
    // the first pick plus every other level of it the plan also buys.
    final plan = <String, int>{};
    Upgrade? pick;
    var budget = number;
    var value = baseValue;

    for (var step = 0; step < 30; step++) {
      final best =
          _withExtraLevels(plan, () => _bestCandidate(budget, value, rate));
      if (best == null) break;
      if (pick != null && best.cost > budget) break;
      pick ??= best.upgrade;
      plan[best.upgrade.id] = (plan[best.upgrade.id] ?? 0) + best.count;
      budget -= best.cost;
      value = best.valueAfter;
      if (budget < BigInt.zero) break;
    }
    if (pick == null) return null;

    final amount = plan[pick.id]!;
    final totalCost = _costOfLevels(pick, pick.level, amount);
    final gain = _withExtraLevels(
            {pick.id: amount}, () => _expectedValuePerSecond(rate)) -
        baseValue;
    final shortfall = (totalCost - number).toDouble();
    return UpgradeRecommendation(
      upgradeId: pick.id,
      category: pick.effectType,
      amount: amount,
      cost: totalCost,
      gainPerSecond: gain,
      paybackSeconds: gain > 0 ? totalCost.toDouble() / gain : double.infinity,
      secondsToAfford: shortfall > 0 ? shortfall / baseValue : 0,
      assumedClickRate: rate,
    );
  }

  /// Best single candidate at the current (possibly simulated) levels.
  /// Returns the upgrade, how many levels, their cost and the income after.
  ({Upgrade upgrade, int count, BigInt cost, double valueAfter})?
      _bestCandidate(
    BigInt budget,
    double value,
    double rate,
  ) {
    final budgetD = budget.toDouble();
    ({Upgrade upgrade, int count, BigInt cost, double valueAfter})? best;
    var bestScore = double.infinity;

    for (final upgrade in upgrades) {
      if (prestigeCount < minPrestigeForUpgrade(upgrade.id)) continue;
      if (upgrade.isMaxed) continue;
      final level = upgrade.level;
      final counts = <int>{1};
      final nextMilestone = upgradeMilestoneThresholds
          .where((t) => t > level)
          .firstOrNull;
      if (nextMilestone != null) {
        final gap = nextMilestone - level;
        if (gap > 1 && gap <= 100) counts.add(gap);
      }
      for (var count in counts) {
        if (upgrade.maxLevel != -1) {
          count = math.min(count, upgrade.maxLevel - level);
        }
        if (count <= 0) continue;
        final cost = _costOfLevels(upgrade, level, count);
        final after = _withExtraLevels(
            {upgrade.id: count}, () => _expectedValuePerSecond(rate));
        final gain = after - value;
        if (!(gain > 0)) continue;
        final costD = cost.toDouble();
        final toAfford = costD > budgetD ? (costD - budgetD) / value : 0.0;
        final score = toAfford + costD / gain;
        if (score < bestScore) {
          bestScore = score;
          best = (
            upgrade: upgrade,
            count: count,
            cost: cost,
            valueAfter: after,
          );
        }
      }
    }
    return best;
  }

  Future<void> prestige() async {
    final netWorthBeforePrestige = number;
    final pointsToEarn = calculatePrestigePoints(number);
    if (pointsToEarn <= 0.0) return;

    final userId = _syncService.currentUserId;

    // Archive the current session before resetting if cloud sync is available
    if (userId != null && _syncService.isAvailable) {
      _updateHighestNumber();
      final sessionSnapshot = _buildLocalProgress(userId);
      try {
        await BackendService.instance.archiveSession(
          userId: userId,
          sessionProgress: sessionSnapshot,
        );
      } catch (e) {
        // Log error but don't prevent prestige
        debugPrint('Failed to archive session: $e');
      }
    }

    final previousPrestigeCount = prestigeCount;
    prestigeCurrency += pointsToEarn;
    prestigeMultiplier += nextPrestigeDelta;
    prestigeCount += 1;
    _queueNewlyUnlockedUpgrades(previousPrestigeCount, prestigeCount);
    _queueNexusReadyNotice(previousPrestigeCount, prestigeCount);
    // prestige() fires partway through the reveal animation (at
    // kPrestigeFirePoint), well before it visually finishes — don't start the
    // tutorial yet or its card would pop up over the still-playing reveal.
    // setPrestigeAnimating(false) picks this up once the reveal is done.
    _artifactMilestonesBeforePrestige =
        ArtifactState.milestonesReached(previousPrestigeCount);

    number = BigInt.zero;
    clickPower = BigInt.from(
        _testEnvironmentEnabled ? 10000 : productionBaseClickPower);
    autoClickRate = 0.0;
    _idleAccumulator = 0.0;
    _lastManualClickTime = null;
    _clickStreak = 0;
    _overclockTriggeredThisChain = false;
    _momentumMultiplier = 1.0;
    _momentumProgress = 0.0;
    _overclockActive = false;
    _overclockTimer?.cancel();
    _temporalCollapseActive = false;
    _temporalCollapseCoolingDown = false;
    _temporalCollapseActiveTimer?.cancel();
    _temporalCollapseCooldownTimerRef?.cancel();
    _neuralSparkBoostMultiplier = 1.0;
    _neuralSparkBoostTimer?.cancel();
    _clearShopTimedBoosts();

    for (var u in upgrades) {
      u.level = 0;
    }
    final genesisLevel =
        Artifacts.genesisStartLevel(_artifactLevel(Artifacts.genesisKit));
    if (genesisLevel > 0) {
      for (final id in Artifacts.genesisKitTiers) {
        _upgradeById(id)?.level = genesisLevel;
      }
    }
    _echoRecentGains.clear();
    _echoClickCounter = 0;
    _recalculateDerivedStatsFromUpgrades();

    final carryBps = surgeProtocolNetWorthCarryBps;
    if (carryBps > 0 && netWorthBeforePrestige > BigInt.zero) {
      final carried = (netWorthBeforePrestige * BigInt.from(carryBps)) ~/
          BigInt.from(10000);
      if (carried > BigInt.zero) {
        number += carried;
        _updateHighestNumber();
      }
    }

    // However the player got here, the prestige chapter has done its job.
    _seenBeats.add(TutorialStep.prestigeReady);
    if (specFor(_tutorialStep).scope == TutorialScope.prestige) {
      _tutorialStep = TutorialStep.done;
    }
    _checkAchievements();
    _startTicker();
    notifyListeners();
    _saveState();
  }

  /// Calculates how many prestige points would be earned on prestige
  double get prestigePointsOnPrestige => nextPrestigeReward;

  Future<void> hardReset({bool preserveTutorial = false}) async {
    _resetToFreshState(preserveTutorial: preserveTutorial);

    await _storageService.clearAllData();
    _lastSavedAt = DateTime.now();
    await _persistState(skipCloudUpload: true);
    if (_syncService.isAvailable && _syncService.currentUserId != null) {
      await syncWithCloud(forceUpload: true);
    }

    notifyListeners();
    if (!preserveTutorial) {
      _onTutorialResetCallback?.call();
    }
  }

  /// Puts every piece of game state back to a brand-new game. Touches no
  /// storage and no cloud; callers decide what to persist.
  void _resetToFreshState({required bool preserveTutorial}) {
    number = BigInt.zero;
    clickPower = BigInt.from(
        _testEnvironmentEnabled ? 10000 : productionBaseClickPower);
    autoClickRate = 0.0;
    _idleAccumulator = 0.0;
    _lastManualClickTime = null;
    _clickStreak = 0;
    _overclockTriggeredThisChain = false;
    _momentumMultiplier = 1.0;
    _momentumProgress = 0.0;
    _overclockActive = false;
    _overclockTimer?.cancel();
    _temporalCollapseActive = false;
    _temporalCollapseCoolingDown = false;
    _temporalCollapseActiveTimer?.cancel();
    _temporalCollapseCooldownTimerRef?.cancel();
    _neuralSparkBoostMultiplier = 1.0;
    _neuralSparkBoostTimer?.cancel();
    _clearShopTimedBoosts();
    shopInventory.clear();
    offlineGainsThisSession = BigInt.zero;
    highestNumber = BigInt.zero;
    prestigeCurrency = 0.0;
    prestigeMultiplier = 1.0;
    prestigeCount = 0;
    _nexusStabilized = false;
    buyAmount = 1;
    selectedUpgradeCategory = clickCategory;

    for (var u in upgrades) {
      u.level = 0;
    }
    for (var n in researchNodes) {
      n.level = 0;
    }
    _affordabilityNotified.clear();
    _pendingUnlockNotices.clear();
    lifetimeClicks = 0;
    _unlockedAchievements.clear();
    _pendingAchievementNotices.clear();
    artifactState = ArtifactState();
    _echoRecentGains.clear();
    _echoClickCounter = 0;
    _overclockCoreElapsed = 0.0;
    _compoundVaultElapsed = 0.0;
    neuralNetwork = NeuralNetwork.initial();
    if (!preserveTutorial) {
      _tutorialCompleted = false;
      _tutorialStep = TutorialStep.welcome;
      _tutorialNeedsCloudSync = false;
      _nexusTutorialSeen = false;
      _neuralTutorialSeen = false;
      _artifactTutorialSeen = false;
      _seenBeats.clear();
      _mainTab = TutorialTab.generators;
    }
    _recalculateDerivedStatsFromUpgrades();
  }

  void _updateHighestNumber() {
    if (number > highestNumber) {
      highestNumber = number;
    }
    _checkAffordabilityUnlocks();
  }

  PlayerProgress _buildLocalProgress(String userId) {
    final upgradedLevels = <String, int>{
      for (final upgrade in upgrades) upgrade.id: upgrade.level,
    };
    final nexusLevelMap = <String, int>{
      for (final node in researchNodes) node.id: node.level,
    };
    final currentHigh = number > highestNumber ? number : highestNumber;
    final now = DateTime.now().toUtc();
    return PlayerProgress(
      userId: userId,
      number: number,
      clickPower: clickPower,
      autoClickRate: autoClickRate,
      prestigeCurrency: prestigeCurrency,
      prestigeMultiplier: prestigeMultiplier,
      prestigeCount: prestigeCount,
      upgradeLevels: upgradedLevels,
      nexusLevels: nexusLevelMap,
      highestNumber: currentHigh,
      progressScore: PlayerProgress.calculateProgressScore(
        number: number,
        prestigeCount: prestigeCount,
        prestigeCurrency: prestigeCurrency,
        upgradeLevels: upgradedLevels,
      ),
      neuralLoss: neuralNetwork.loss,
      neuralLowestLoss: neuralNetwork.lowestLossEver,
      neuralNetworkJson: neuralNetwork.toJsonString(),
      achievements: _unlockedAchievements.toList()..sort(),
      lifetimeClicks: lifetimeClicks,
      artifactsJson: jsonEncode(artifactState.toJson()),
      updatedAt: _loadFailed
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : (_lastSavedAt?.toUtc() ?? now),
    );
  }

  void _applyCloudProgress(PlayerProgress progress) {
    number = progress.number;
    clickPower = progress.clickPower > BigInt.zero
        ? progress.clickPower
        : BigInt.from(productionBaseClickPower);
    autoClickRate =
        progress.autoClickRate.isFinite && progress.autoClickRate > 0
            ? progress.autoClickRate
            : 0.0;
    prestigeCurrency = progress.prestigeCurrency;
    prestigeMultiplier =
        progress.prestigeMultiplier < 1.0 ? 1.0 : progress.prestigeMultiplier;
    prestigeCount = progress.prestigeCount.clamp(0, 999999);
    highestNumber = progress.normalizedHighestNumber;

    for (final upgrade in upgrades) {
      final remoteLevel = progress.upgradeLevels[upgrade.id] ?? 0;
      upgrade.level = upgrade.maxLevel == -1
          ? remoteLevel
          : remoteLevel.clamp(0, upgrade.maxLevel);
    }
    for (final node in researchNodes) {
      node.level = (progress.nexusLevels[node.id] ?? 0).clamp(0, node.maxLevel);
    }

    // The cloud copy carries the whole network when it was uploaded by a
    // build that syncs topology; older rows only have the loss values.
    final remoteNetworkJson = progress.neuralNetworkJson;
    if (remoteNetworkJson != null) {
      try {
        final bestLocal = neuralNetwork.lowestLossEver;
        neuralNetwork = NeuralNetwork.fromJsonString(remoteNetworkJson);
        if (bestLocal < neuralNetwork.lowestLossEver) {
          neuralNetwork.lowestLossEver = bestLocal;
        }
      } catch (_) {}
    }

    _unlockedAchievements.addAll(progress.achievements);
    if (progress.lifetimeClicks > lifetimeClicks) {
      lifetimeClicks = progress.lifetimeClicks;
    }
    final remoteArtifacts = progress.artifactsJson;
    if (remoteArtifacts != null) {
      try {
        artifactState = ArtifactState.fromJson(
            jsonDecode(remoteArtifacts) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Carry forward neural loss from the cloud — keep whichever loss is
    // lower (more progress) so a stale upload can never wipe a better
    // training run on a different device.
    if (remoteNetworkJson == null && progress.neuralLoss < neuralNetwork.loss) {
      neuralNetwork.loss = progress.neuralLoss.clamp(0.0, 1.0);
    }
    final remoteBest = progress.neuralLowestLoss.clamp(0.0, 1.0);
    if (remoteBest < neuralNetwork.lowestLossEver) {
      neuralNetwork.lowestLossEver = remoteBest;
    }

    _recalculateDerivedStatsFromUpgrades();

    _idleAccumulator = 0.0;
    _lastManualClickTime = null;
    _clickStreak = 0;
    _overclockTriggeredThisChain = false;
    _momentumMultiplier = 1.0;
    _momentumProgress = 0.0;
    _overclockActive = false;
    _overclockTimer?.cancel();
    _temporalCollapseActive = false;
    _temporalCollapseCoolingDown = false;
    _temporalCollapseActiveTimer?.cancel();
    _temporalCollapseCooldownTimerRef?.cancel();
    _neuralSparkBoostMultiplier = 1.0;
    _neuralSparkBoostTimer?.cancel();
    _clearShopTimedBoosts();

    // The cloud copy carries no record of which tutorial cards were shown;
    // don't walk a returning player through what they are already past.
    if (_tutorialCompleted) _backfillSeenBeats();
  }

  /// Starts watching device connectivity so the game can retry the cloud
  /// backend the moment a connection comes back, instead of staying stuck in
  /// offline mode for the rest of the session.
  Future<void> _initConnectivityMonitoring() async {
    try {
      _isOnline = await ConnectivityService.instance.checkConnection();
      if (!_isOnline) _wasEverOffline = true;
    } catch (_) {
      _isOnline = true;
    }

    _connectivitySub = ConnectivityService.instance.onStatusChange.listen(
      (online) {
        final cameBackOnline = online && !_isOnline;
        _isOnline = online;
        if (!online) {
          _wasEverOffline = true;
        } else if (cameBackOnline && _wasEverOffline) {
          unawaited(_reconnectToCloud());
        }
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  /// Re-attempts the Firebase handshake and, if signed in, a cloud sync.
  /// [BackendService.initialize] is idempotent, so this is safe to call even
  /// when the service booted successfully the first time around.
  Future<void> _reconnectToCloud() async {
    if (!BackendService.instance.isInitialized) {
      try {
        await BackendService.initialize().timeout(const Duration(seconds: 6));
      } catch (_) {
        // Still unreachable — the next connectivity transition retries.
        return;
      }
    }

    if (!BackendService.instance.isSignedIn) {
      // No account to sync, but the connection itself is back — still worth
      // telling the player they're no longer running in offline mode.
      _justReconnected = true;
      notifyListeners();
      return;
    }

    await syncWithCloud();
    if (_lastCloudSyncError == null) {
      _justReconnected = true;
      notifyListeners();
    }
  }

  /// Queues a notice for every prestige-gated upgrade whose threshold sits
  /// strictly between [oldCount] and [newCount], i.e. was just crossed.
  void _queueNewlyUnlockedUpgrades(int oldCount, int newCount) {
    for (final upgrade in upgrades) {
      final required = minPrestigeForUpgrade(upgrade.id);
      if (required > 0 && oldCount < required && newCount >= required) {
        _pendingUnlockNotices.add(upgrade.id);
      }
    }
  }

  /// Sentinel id (not a real upgrade) queued into [_pendingUnlockNotices]
  /// the moment the Nexus becomes stabilizable, so the same banner pipeline
  /// used for upgrade unlocks can surface it too.
  static const String nexusReadyNoticeId = 'nexus_stabilize';

  /// Queues a one-time notice the moment [oldCount] → [newCount] crosses the
  /// Nexus unlock threshold, mirroring [_queueNewlyUnlockedUpgrades].
  void _queueNexusReadyNotice(int oldCount, int newCount) {
    if (!_nexusStabilized && oldCount < 3 && newCount >= 3) {
      _pendingUnlockNotices.add(nexusReadyNoticeId);
    }
  }

  /// Queues a notice the first time a never-bought upgrade's cost becomes
  /// affordable, so the player is told "new upgrade available" as soon as
  /// they can actually buy it rather than having to notice it themselves in
  /// the upgrades list.
  void _checkAffordabilityUnlocks() {
    if (_affordabilityNotified.length >= upgrades.length) return;
    for (final upgrade in upgrades) {
      if (upgrade.level != 0) continue;
      if (_affordabilityNotified.contains(upgrade.id)) continue;
      if (prestigeCount < minPrestigeForUpgrade(upgrade.id)) continue;
      if (number < upgrade.currentCost) continue;
      _affordabilityNotified.add(upgrade.id);
      _pendingUnlockNotices.add(upgrade.id);
    }
  }

  Future<void> syncWithCloud({bool forceUpload = false}) async {
    if (_cloudSyncInProgress || !_syncService.isAvailable) return;
    final userId = _syncService.currentUserId;
    if (userId == null) return;

    _cloudSyncInProgress = true;
    _lastCloudSyncError = null;
    notifyListeners();

    try {
      _updateHighestNumber();
      final local = _buildLocalProgress(userId);
      final result = await _syncService.syncProgress(
        localProgress: local,
        forceUpload: forceUpload,
      );
      if (result == null) return;

      // Either the cloud copy was restored or there was none to protect.
      _loadFailed = false;
      if (result.winner == SyncWinner.remote) {
        _applyCloudProgress(result.resolved);
        _startTicker();
      } else {
        highestNumber = result.resolved.normalizedHighestNumber;
      }

      _lastCloudPushAt = DateTime.now().toUtc();
      _cloudFailureStreak = 0;
      _cloudRetryAfter = null;
      await _persistState(skipCloudUpload: true);
      notifyListeners();
    } catch (error) {
      _lastCloudSyncError = error.toString();
      // 20s, 40s, 80s, ... capped at 5 minutes.
      final backoff = _cloudPushInterval * (1 << _cloudFailureStreak.clamp(0, 4));
      _cloudRetryAfter = DateTime.now().add(
        backoff > _cloudMaxBackoff ? _cloudMaxBackoff : backoff,
      );
      _cloudFailureStreak++;
      notifyListeners();
    } finally {
      _cloudSyncInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _saveState() async {
    await _persistState(skipCloudUpload: false);
  }

  /// Saves run one at a time, in order. The ticker, the tap debounce and
  /// purchases can all ask for a save at once, and overlapping saves used to
  /// interleave their writes key by key, which could mix two snapshots. A
  /// request that arrives while one is already queued joins it, since the
  /// queued save reads the state when it starts.
  Future<void> _persistTail = Future<void>.value();
  Future<void>? _queuedPersist;
  bool _queuedPersistSkipsCloud = true;

  Future<void> _persistState({required bool skipCloudUpload}) {
    _queuedPersistSkipsCloud = _queuedPersistSkipsCloud && skipCloudUpload;
    final queued = _queuedPersist;
    if (queued != null) return queued;
    final run = _persistTail.then((_) {
      _queuedPersist = null;
      final skip = _queuedPersistSkipsCloud;
      _queuedPersistSkipsCloud = true;
      return _writeState(skipCloudUpload: skip);
    });
    _queuedPersist = run;
    _persistTail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _writeState({required bool skipCloudUpload}) async {
    _updateHighestNumber();
    await _storageService.saveGame(
      number: number,
      clickPower: clickPower,
      autoClickRate: autoClickRate,
      prestigeCurrency: prestigeCurrency,
      prestigeMultiplier: prestigeMultiplier,
      prestigeCount: prestigeCount,
      upgradeLevels: {
        for (final upgrade in upgrades) upgrade.id: upgrade.level,
      },
      highestNumber: highestNumber,
      nexusLevels: {
        for (final node in researchNodes) node.id: node.level,
      },
      tutorialCompleted: _tutorialCompleted,
      tutorialStep: _tutorialStep.name,
      nexusTutorialSeen: _nexusTutorialSeen,
      neuralTutorialSeen: _neuralTutorialSeen,
      artifactTutorialSeen: _artifactTutorialSeen,
      tutorialBeatsSeen: [for (final step in _seenBeats) step.name]..sort(),
      nexusStabilized: _nexusStabilized,
      neuralNetworkJson: neuralNetwork.toJsonString(),
      testEnvironmentEnabled: _testEnvironmentEnabled,
      lifetimeClicks: lifetimeClicks,
      achievements: _unlockedAchievements.toList()..sort(),
      artifactsJson: jsonEncode(artifactState.toJson()),
      shopJson: jsonEncode(shopInventory.toJson()),
    );
    _lastSavedAt = DateTime.now();

    if (skipCloudUpload ||
        !_syncService.isAvailable ||
        _syncService.currentUserId == null) {
      return;
    }

    final now = DateTime.now();
    final retryAfter = _cloudRetryAfter;
    if (retryAfter != null && now.isBefore(retryAfter)) return;
    final shouldPush = _lastCloudPushAt == null ||
        now.difference(_lastCloudPushAt!) >= _cloudPushInterval;
    if (shouldPush) {
      unawaited(syncWithCloud());
    }
  }

  void _scheduleStateSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounceDuration, _saveState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _backgroundedAt == null) {
      // Minimising works like closing the app: the loop stops (it used to
      // keep ticking, saving and syncing until the OS froze the process,
      // which on Android could be minutes) and the time away is credited
      // as offline progress on return.
      _backgroundedAt = clock();
      _ticker?.cancel();
      _ticker = null;
      // The OS may kill a backgrounded app without warning. Flush now so the
      // last few seconds since the periodic save aren't lost.
      _saveDebounceTimer?.cancel();
      unawaited(_saveState());
    }
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt != null) {
        _creditTimeAway(backgroundedAt);
      }
      _lastSavedAt = clock();
      _startTicker();
      notifyListeners();
    }
  }

  /// Time source for the minimise/resume handling, swappable in tests.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// When the app was minimised; null while it is in the foreground.
  DateTime? _backgroundedAt;

  /// Away for less than this and the offline gains are credited silently
  /// instead of popping the offline-gains dialog.
  static const Duration offlineDialogMinAway = Duration(seconds: 60);

  /// Credits time spent minimised exactly like time spent with the app
  /// closed (including Quick Resume), via [_calculateOfflineProgress].
  void _creditTimeAway(DateTime backgroundedAt) {
    // Any gains still waiting on an unacknowledged dialog were already
    // added to the number; only the new amount is reported.
    offlineGainsThisSession = BigInt.zero;
    offlineAccuracyGain = 0.0;
    _calculateOfflineProgress(backgroundedAt, now: clock());
    if (clock().difference(backgroundedAt) < offlineDialogMinAway) {
      offlineGainsThisSession = BigInt.zero;
      offlineAccuracyGain = 0.0;
    }
  }

  // ── Tutorial methods ───────────────────────────────────────────────────

  /// Apply the cloud profile's tutorial flag.
  ///
  /// Completion only ever syncs **upward**. A fresh profile doc defaults
  /// `tutorial_completed` to false, and this runs on every profile fetch, so
  /// honouring a remote `false` meant signing in could restart onboarding on
  /// top of a mature local save.
  void setTutorialCompletionFromProfile(bool completed) {
    if (!completed) {
      if (_tutorialCompleted) {
        // Local says done, remote disagrees: push our truth up instead.
        _tutorialNeedsCloudSync = true;
        unawaited(syncTutorialCompletedToProfileIfNeeded());
      }
      return;
    }
    if (_tutorialCompleted) return;
    _tutorialCompleted = true;
    _tutorialStep = TutorialStep.done;
    // Finished on another device: skip whatever this progress is past.
    _backfillSeenBeats();
    notifyListeners();
    _scheduleStateSave();
  }

  Future<void> syncTutorialCompletedToProfileIfNeeded() async {
    if (!_tutorialNeedsCloudSync) return;
    final userId = _syncService.currentUserId;
    if (userId == null) return;
    _tutorialNeedsCloudSync = false;
    try {
      await BackendService.instance.setProfileTutorialCompleted(
        userId: userId,
        completed: _tutorialCompleted,
      );
    } catch (_) {
      _tutorialNeedsCloudSync = true;
    }
  }

  Future<void> refreshTutorialFromCloud() async {
    final userId = _syncService.currentUserId;
    if (userId == null) return;
    try {
      final profile =
          await BackendService.instance.fetchProfile(userId: userId);
      if (profile != null) {
        setTutorialCompletionFromProfile(profile.tutorialCompleted);
      }
    } catch (_) {}
  }

  /// Moves to [step]. A "tap X below" step is passed straight through when
  /// the player is already on X: the nav bar ignores a tap on the current
  /// tab, so the step could otherwise never advance.
  void _enterStep(TutorialStep step) {
    _tutorialStep = step;
    final spec = specFor(step);
    if (spec.mode == TutorialMode.passthroughHint) {
      final next = _stepAfterTab(step, _mainTab);
      if (next != null) _tutorialStep = next;
    }
    _applyStepSideEffects(_tutorialStep);
    notifyListeners();
    _scheduleStateSave();
  }

  /// Puts the Upgrades screen on the category a step's target lives under.
  void _applyStepSideEffects(TutorialStep step) {
    final category = specFor(step).requiredCategory;
    if (category != null && step != TutorialStep.buyAutoClicker) {
      selectedUpgradeCategory = category;
    }
  }

  /// Where a nav step leads once the player is on [tab], or null if [tab]
  /// isn't the one it asks for.
  static TutorialStep? _stepAfterTab(TutorialStep step, int tab) {
    switch (step) {
      case TutorialStep.navUpgrades:
        return tab == TutorialTab.upgrades ? TutorialStep.selectIdle : null;
      case TutorialStep.navGenerators:
        return tab == TutorialTab.generators ? TutorialStep.watchIdle : null;
      case TutorialStep.navUpgradesForClick:
        return tab == TutorialTab.upgrades ? TutorialStep.buyClickPower : null;
      case TutorialStep.navGeneratorsForSpark:
        return tab == TutorialTab.generators ? TutorialStep.catchSpark : null;
      case TutorialStep.navPrestige:
        return tab == TutorialTab.prestige
            ? TutorialStep.learnPrestigeDetails
            : null;
      case TutorialStep.navPrestigeForNexus:
        return tab == TutorialTab.prestige ? TutorialStep.nexusStabilize : null;
      case TutorialStep.navNeural:
        return tab == TutorialTab.neural ? TutorialStep.neuralIntro : null;
      default:
        return null;
    }
  }

  void onTutorialTapToContinue() {
    switch (_tutorialStep) {
      case TutorialStep.welcome:
        _enterStep(TutorialStep.clickToFifty);
      case TutorialStep.roadAhead:
        _finishFirstChapter(reward: true);
      case TutorialStep.prestigeReady:
        _enterStep(TutorialStep.navPrestige);
      case TutorialStep.learnPrestigeDetails:
        _enterStep(TutorialStep.prestigeMultiplierHint);
      case TutorialStep.prestigeMultiplierHint:
        _enterStep(TutorialStep.prestigeGainHint);
      case TutorialStep.prestigeGainHint:
        _enterStep(TutorialStep.doPrestige);
      case TutorialStep.artifactsIntro:
        _enterStep(TutorialStep.artifactsEmpower);
      case TutorialStep.artifactsEmpower:
        // The Nexus teaser only makes sense while it is still ahead.
        if (_nexusStabilized || prestigeCount >= nexusPrestigeRequirement) {
          _completeArtifactsTutorial();
        } else {
          _enterStep(TutorialStep.nexusWhisper);
        }
      case TutorialStep.nexusWhisper:
        _completeArtifactsTutorial();
      case TutorialStep.nexusAwakens:
        _enterStep(TutorialStep.navPrestigeForNexus);
      case TutorialStep.nexusIntro:
        _enterStep(TutorialStep.nexusUpgrades);
      case TutorialStep.nexusUpgrades:
        _enterStep(TutorialStep.nexusResearchOptProtocol);
      case TutorialStep.nexusGoal:
        _completeNexusTutorial();
      case TutorialStep.neuralUnlocked:
        _enterStep(TutorialStep.navNeural);
      case TutorialStep.neuralIntro:
        _enterStep(TutorialStep.neuralTapNeuron);
      case TutorialStep.neuralViewAccuracy:
        _enterStep(TutorialStep.neuralAccuracyLimit);
      case TutorialStep.neuralAccuracyLimit:
        _completeNeuralTutorial();
      default:
        if (specFor(_tutorialStep).scope == TutorialScope.tips) {
          _finishBeat(_tutorialStep);
        }
    }
  }

  /// Prestiges needed before the Nexus can be stabilized.
  static const int nexusPrestigeRequirement = 3;

  /// Ends chapter 1. Finishing it (rather than skipping) earns a Spark
  /// Surge, which doubles as the player's first look at a shop boost.
  void _finishFirstChapter({required bool reward}) {
    _tutorialCompleted = true;
    _tutorialStep = TutorialStep.done;
    _tutorialNeedsCloudSync = true;
    if (reward) _activateShopSparkSurge();
    notifyListeners();
    _scheduleStateSave();
    unawaited(syncTutorialCompletedToProfileIfNeeded());
  }

  /// Ends a one-shot chapter, tip or teaser keyed by [beat].
  void _finishBeat(TutorialStep beat) {
    _seenBeats.add(beat);
    _tutorialStep = TutorialStep.done;
    notifyListeners();
    _scheduleStateSave();
  }

  void _completeNexusTutorial() {
    _nexusTutorialSeen = true;
    _seenBeats.add(TutorialStep.nexusAwakens);
    _tutorialStep = TutorialStep.done;
    notifyListeners();
    _scheduleStateSave();
  }

  void _completeNeuralTutorial() {
    _neuralTutorialSeen = true;
    _tutorialStep = TutorialStep.done;
    notifyListeners();
    _scheduleStateSave();
  }

  void _completeArtifactsTutorial() {
    _artifactTutorialSeen = true;
    _tutorialStep = TutorialStep.done;
    notifyListeners();
    _scheduleStateSave();
  }

  /// Ends whatever is on screen, and only that: skipping chapter 1 does not
  /// opt out of the chapters that explain systems the player hasn't met.
  void skipTutorial() {
    final step = _tutorialStep;
    switch (specFor(step).scope) {
      case TutorialScope.main:
        _finishFirstChapter(reward: false);
      case TutorialScope.prestige:
        _finishBeat(TutorialStep.prestigeReady);
      case TutorialScope.artifacts:
        _completeArtifactsTutorial();
      case TutorialScope.nexus:
        _completeNexusTutorial();
      case TutorialScope.neural:
        _completeNeuralTutorial();
      case TutorialScope.tips:
        _finishBeat(step);
      case TutorialScope.none:
        return;
    }
  }

  void onMainTabChanged(int index) {
    _mainTab = index;
    final next = _stepAfterTab(_tutorialStep, index);
    if (next != null) {
      _tutorialStep = next;
      _applyStepSideEffects(next);
      notifyListeners();
      _scheduleStateSave();
      return;
    }
    // First visit to UPGRADES after chapter 1: introduce the advisor, as
    // long as it has something to point at.
    if (index == TutorialTab.upgrades &&
        _tutorialStep == TutorialStep.done &&
        _tutorialCompleted &&
        !_seenBeats.contains(TutorialStep.tipAdvisor) &&
        recommendedUpgrade != null) {
      _enterStep(TutorialStep.tipAdvisor);
    }
    // No `else` for other tabs on purpose: the overlay reads
    // TutorialStepSpec.requiredTab and shows only SKIP when the player is
    // somewhere the current step doesn't apply, rather than pointing a
    // spotlight at a nav item while a different screen is on show.
  }

  void _advanceTutorialOnPurchase(String upgradeId) {
    if (_tutorialStep == TutorialStep.buyAutoClicker &&
        upgradeId == autoClickerId) {
      _enterStep(TutorialStep.navGenerators);
    } else if (_tutorialStep == TutorialStep.buyClickPower &&
        upgradeId == clickPowerId) {
      _enterStep(TutorialStep.navGeneratorsForSpark);
    }
  }

  /// Number the player must reach before the tutorial sends them to buy the
  /// first Auto-Clicker. Derived from the Auto-Clicker's own base cost so a
  /// future price change can't strand the step on an unaffordable purchase.
  static final BigInt tutorialFirstClickTarget =
      defaultUpgrades().firstWhere((u) => u.id == autoClickerId).baseCost;

  /// Number the player must reach while watching idle income accumulate,
  /// before being sent to buy Click Power.
  static final BigInt tutorialIdleWatchTarget =
      defaultUpgrades().firstWhere((u) => u.id == clickPowerId).baseCost * BigInt.two;

  void _advanceTutorialOnNumberReached() {
    if (_tutorialStep == TutorialStep.clickToFifty &&
        number >= tutorialFirstClickTarget) {
      _enterStep(TutorialStep.navUpgrades);
    } else if (_tutorialStep == TutorialStep.watchIdle &&
        number >= tutorialIdleWatchTarget) {
      _enterStep(TutorialStep.navUpgradesForClick);
    }
  }

  /// Starts a chapter, tip or teaser whose moment has come. Called twice a
  /// second from the ticker and after every tap; returns whether the step
  /// changed.
  bool _checkTutorialTriggers() {
    // The prestige chapter needs the requirement met. If the player spent
    // their way back under it, stand down; it starts again next time.
    if (specFor(_tutorialStep).scope == TutorialScope.prestige &&
        prestigeCount == 0 &&
        number < prestigeRequirement) {
      _tutorialStep = TutorialStep.done;
      return true;
    }
    if (_tutorialStep != TutorialStep.done ||
        !_tutorialCompleted ||
        isPrestigeAnimating ||
        isNexusStabilizing) {
      return false;
    }
    final next = _nextTriggeredBeat();
    if (next == null) return false;
    _enterStep(next);
    return true;
  }

  TutorialStep? _nextTriggeredBeat() {
    if (prestigeCount == 0 &&
        !_seenBeats.contains(TutorialStep.prestigeReady) &&
        number >= prestigeRequirement) {
      return TutorialStep.prestigeReady;
    }
    for (final entry in upgradeTipSteps.entries) {
      final tip = entry.value;
      if (_seenBeats.contains(tip)) continue;
      final upgrade = _upgradeById(entry.key);
      if (upgrade == null) continue;
      if (upgrade.level > 0) {
        // Bought without ever seeing the card: nothing left to announce.
        _seenBeats.add(tip);
        continue;
      }
      if (prestigeCount < minPrestigeForUpgrade(upgrade.id)) continue;
      if (number >= _costOfLevels(upgrade, 0, 1)) return tip;
    }
    if (!_seenBeats.contains(TutorialStep.tipEpoch) && canStartEpoch) {
      return TutorialStep.tipEpoch;
    }
    return null;
  }

  /// Starts the chapter or teaser a prestige just earned, once its reveal
  /// animation has finished (see the capture site in [prestige]) so the
  /// card doesn't pop up over it.
  void _maybeStartPostPrestigeTutorial() {
    final before = _artifactMilestonesBeforePrestige;
    _artifactMilestonesBeforePrestige = null;
    if (before == null) return;
    if (_tutorialStep != TutorialStep.done || !_tutorialCompleted) return;

    TutorialStep? next;
    if (!_artifactTutorialSeen &&
        before == 0 &&
        ArtifactState.milestonesReached(prestigeCount) > 0) {
      next = TutorialStep.artifactsIntro;
    } else if (!_nexusStabilized &&
        prestigeCount >= nexusPrestigeRequirement &&
        !_seenBeats.contains(TutorialStep.nexusAwakens)) {
      next = TutorialStep.nexusAwakens;
    } else if (!_nexusStabilized &&
        prestigeCount == nexusPrestigeRequirement - 1 &&
        !_seenBeats.contains(TutorialStep.nexusSignal)) {
      next = TutorialStep.nexusSignal;
    } else if (neuralNetworkUnlocked &&
        prestigeCount >= deepLayerPrestigeGates.first &&
        !_seenBeats.contains(TutorialStep.tipDeepLayers)) {
      next = TutorialStep.tipDeepLayers;
    }
    if (next != null) _enterStep(next);
  }

  /// Teasers on the long walk down the Nexus tree to Neural Genesis.
  void _maybeStartNexusTeaser(ResearchNode purchased) {
    if (neuralNetworkUnlocked) return;
    if (_tutorialStep != TutorialStep.done || !_tutorialCompleted) return;
    final genesis =
        researchNodes.where((n) => n.id == 'neural_genesis').firstOrNull;
    if (genesis != null &&
        genesis.level == 0 &&
        genesis.prereqsMet(researchNodes) &&
        !_seenBeats.contains(TutorialStep.neuralGenesisReady)) {
      _seenBeats.add(TutorialStep.neuralWhisper);
      _enterStep(TutorialStep.neuralGenesisReady);
      return;
    }
    if (purchased.tier == 3 &&
        !_seenBeats.contains(TutorialStep.neuralWhisper)) {
      _enterStep(TutorialStep.neuralWhisper);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _ticker?.cancel();
    _overclockTimer?.cancel();
    _temporalCollapseActiveTimer?.cancel();
    _temporalCollapseCooldownTimerRef?.cancel();
    _neuralSparkBoostTimer?.cancel();
    _shopSparkSurgeTimer?.cancel();
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
}
