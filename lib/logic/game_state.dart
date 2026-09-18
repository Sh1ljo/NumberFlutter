import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/upgrade.dart';
import '../models/research_node.dart';
import '../models/player_progress.dart';
import '../data/nexus_data.dart';
import '../models/neural_network.dart';
import 'connectivity_service.dart';
import 'storage_service.dart';
import 'sync_service.dart';
import 'backend_service.dart';
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

  NeuralNetwork neuralNetwork = NeuralNetwork.initial();
  bool get neuralNetworkUnlocked => _nexusLevel('neural_genesis') >= 1;

  // ── Tutorial ───────────────────────────────────────────────────────────
  TutorialStep _tutorialStep = TutorialStep.welcome;
  bool _tutorialCompleted = false;
  bool _tutorialNeedsCloudSync = false;
  // Secondary tutorials run after the main onboarding ends. They reuse the
  // same overlay and step machine but each has its own "seen" flag so they
  // fire exactly once and don't roundtrip through cloud profile sync.
  bool _nexusTutorialSeen = false;
  bool _neuralTutorialSeen = false;
  bool _upgradeTutorialSeen = false;
  VoidCallback? _onTutorialResetCallback;

  /// Pre-deep-dive progress, restored by [_completeUpgradeTutorial].
  BigInt? _upgradeTutorialNumberSnapshot;
  Map<String, int>? _upgradeTutorialLevelSnapshot;

  TutorialStep get tutorialStep => _tutorialStep;
  bool get tutorialCompleted => _tutorialCompleted;
  bool get isTutorialActive => _tutorialStep != TutorialStep.done;
  bool get nexusTutorialSeen => _nexusTutorialSeen;
  bool get neuralTutorialSeen => _neuralTutorialSeen;
  bool get upgradeTutorialSeen => _upgradeTutorialSeen;

  /// Test-only: jump straight to a step so the overlay's rendering for it can
  /// be exercised. Does not touch persistence.
  @visibleForTesting
  void debugSetTutorialStep(TutorialStep step) {
    _tutorialStep = step;
    _tutorialCompleted = step == TutorialStep.done;
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
    notifyListeners();
  }

  void setTestEnvironmentEnabled(bool value) {
    if (_testEnvironmentEnabled == value) return;
    _testEnvironmentEnabled = value;
    _recalculateDerivedStatsFromUpgrades();
    notifyListeners();
    _saveState();
  }

  void stabilizeNexus() {
    _nexusStabilized = true;
    if (!_nexusTutorialSeen && _tutorialStep == TutorialStep.done) {
      _tutorialStep = TutorialStep.nexusIntro;
    }
    notifyListeners();
    _scheduleStateSave();
  }

  Timer? _ticker;
  Timer? _overclockTimer;
  Timer? _saveDebounceTimer;
  Timer? _temporalCollapseActiveTimer;
  Timer? _temporalCollapseCooldownTimerRef;
  Timer? _neuralSparkBoostTimer;
  double _neuralSparkBoostMultiplier = 1.0;
  static const Duration _saveDebounceDuration = Duration(milliseconds: 350);

  /// True while a caught "Neural Spark" click-power boost is active.
  bool get isNeuralSparkBoostActive => _neuralSparkBoostMultiplier != 1.0;

  // Upgrades
  /// The upgrade catalog. Built fresh per call so each [GameState] owns its
  /// own mutable levels, and so tests can inspect the catalog without
  /// constructing a GameState (whose constructor starts the game loop).
  static List<Upgrade> defaultUpgrades() => [
    Upgrade(
      id: clickPowerId,
      name: 'Click Power',
      description: 'Adds +1 click power each level.',
      baseCost: BigInt.from(15),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(1),
    ),
    Upgrade(
      id: 'click_reinforced_tap',
      name: 'Reinforced Tap',
      description: 'Adds +5 click power each level.',
      baseCost: BigInt.from(400),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(5),
    ),
    Upgrade(
      id: probabilityStrikeId,
      name: 'Probability Strike',
      description:
          '5% chance for massive damage. Each level increases strike power.',
      baseCost: BigInt.from(2500),
      costMultiplier: 1.72,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: 'click_kinetic_amplifier',
      name: 'Kinetic Amplifier',
      description: 'Adds +25 click power each level.',
      baseCost: BigInt.from(6000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(25),
    ),
    Upgrade(
      id: momentumId,
      name: 'Momentum',
      description: 'Each level improves combo growth, cap, and decay window.',
      baseCost: BigInt.from(8000),
      costMultiplier: 1.68,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: kineticSynergyId,
      name: 'Kinetic Synergy',
      description:
          'Each level adds +1% of your idle N/s to manual click power.',
      baseCost: BigInt.from(40000),
      costMultiplier: 1.75,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: 'click_resonant_touch',
      name: 'Resonant Touch',
      description: 'Adds +150 click power each level.',
      baseCost: BigInt.from(75000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(150),
    ),
    Upgrade(
      id: overclockId,
      name: 'Overclock',
      description:
          'Each level boosts overclock power and duration, and lowers trigger streak.',
      baseCost: BigInt.from(125000),
      costMultiplier: 1.82,
      effectType: clickCategory,
      effectValue: 0,
    ),
    Upgrade(
      id: 'click_quantum_fingertip',
      name: 'Quantum Fingertip',
      description: 'Adds +1,000 click power each level.',
      baseCost: BigInt.from(1000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(1000),
    ),
    Upgrade(
      id: 'click_singularity_press',
      name: 'Singularity Press',
      description: 'Adds +7,500 click power each level.',
      baseCost: BigInt.from(15000000),
      costMultiplier: 1.15,
      effectType: clickCategory,
      effectValue: BigInt.from(7500),
    ),
    Upgrade(
      id: autoClickerId,
      name: 'Auto-Clicker',
      description: 'Clicks for you automatically.',
      baseCost: BigInt.from(150),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 1.0,
    ),
    Upgrade(
      id: quantumMultiplierId,
      name: 'Quantum Multiplier',
      description: 'Greatly increases idle generation.',
      baseCost: BigInt.from(1500),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 10.0,
    ),
    Upgrade(
      id: 'idle_fractal_engine',
      name: 'Fractal Engine',
      description: 'Adds +100 numbers per second each level.',
      baseCost: BigInt.from(15000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 100.0,
    ),
    Upgrade(
      id: 'idle_singularity_core',
      name: 'Singularity Core',
      description: 'Adds +1,000 numbers per second each level.',
      baseCost: BigInt.from(150000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 1000.0,
    ),
    Upgrade(
      id: 'idle_tesseract_array',
      name: 'Tesseract Array',
      description: 'Adds +10,000 numbers per second each level.',
      baseCost: BigInt.from(1500000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 10000.0,
    ),
    Upgrade(
      id: 'idle_entropy_harvester',
      name: 'Entropy Harvester',
      description: 'Adds +100,000 numbers per second each level.',
      baseCost: BigInt.from(15000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 100000.0,
    ),
    Upgrade(
      id: 'idle_void_resonance',
      name: 'Void Resonance',
      description: 'Adds +1,000,000 numbers per second each level.',
      baseCost: BigInt.from(150000000),
      costMultiplier: 1.16,
      effectType: idleCategory,
      effectValue: 1000000.0,
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
  int get surgeProtocolNetWorthCarryBps => _nexusLevel('surge_protocol') * 50;

  /// Multiplier applied to the prestige delta (Enhanced Extraction).
  double get prestigeDeltaMultiplier {
    final level = _nexusLevel('enhanced_extraction');
    return 1.0 + level * 0.10;
  }

  /// Permanent flat idle rate bonus that survives prestige resets.
  double get permanentIdleBonus => _nexusLevel('idle_foundation') * 1.0;

  /// Multiplier on offline gains (Quick Resume).
  double get offlineGainMultiplier {
    final level = _nexusLevel('quick_resume');
    return 1.0 + level * 0.10;
  }

  /// Flat addition to the momentum cap (Kinetic Surge).
  double get momentumCapBonus => _nexusLevel('kinetic_surge') * 0.1;

  /// Additional idle rate multiplier from Resonance Core: 1.05 ^ level.
  double get resonanceMultiplier {
    final level = _nexusLevel('resonance_core');
    return math.pow(1.05, level).toDouble();
  }

  /// Multiplier on prestige points earned (Echo Protocol).
  double get prestigePointsMultiplier {
    final level = _nexusLevel('echo_protocol');
    return 1.0 + level * 0.10;
  }

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
    if (nodeId == 'neural_genesis' &&
        !_neuralTutorialSeen &&
        _tutorialStep == TutorialStep.done) {
      number += BigInt.from(100_000_000);
      _tutorialStep = TutorialStep.neuralUnlocked;
    }
    if (nodeId == 'opt_protocol' &&
        _tutorialStep == TutorialStep.nexusResearchOptProtocol) {
      _tutorialStep = TutorialStep.nexusGoal;
    }
    notifyListeners();
    _saveState();
  }

  /// ── end NEXUS ──────────────────────────────────────────────────────────

  // ── Neural Network ─────────────────────────────────────────────────────

  bool upgradeNeuronGradient(String neuronId) {
    final neuron = neuralNetwork.findNeuron(neuronId);
    if (neuron == null || neuron.isGradientMaxed) return false;
    final cost = neuron.gradientUpgradeCost;
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
    final cost = neuron.activationChangeCost(fn);
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
    if (!neuralNetwork.canNeuronBranch(neuronId)) return false;
    final cost = neuralNetwork.addLayerCost(neuralNetwork.layers.length);
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
        if (!NeuralNetwork.isEligibleParentIndex(layer.index, i)) continue;
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

  /// Clicks made while `triggerProbabilityStrike` is the active step.
  int _tutorialStrikeClicks = 0;

  /// After this many clicks the tutorial forces a strike.
  ///
  /// The step is gated on a 5% roll, so the expected wait is ~20 clicks but
  /// the tail is unbounded — and the step renders no SKIP-bearing dim, so an
  /// unlucky player could sit there indefinitely.
  static const int tutorialStrikePityClicks = 25;

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

  bool get _tutorialForcesStrike {
    if (_tutorialStep != TutorialStep.triggerProbabilityStrike) return false;
    return _tutorialStrikeClicks >= tutorialStrikePityClicks;
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
    return nextPrestigeReward * prestigePointsMultiplier;
  }

  // Testing utility: add prestige currency directly
  void addPrestigePointsForTesting(int amount) {
    prestigeCurrency = prestigeCurrency + amount;
    notifyListeners();
  }

  /// Resolve a persisted step by name, falling back to the start of the
  /// tutorial for anything unrecognised (older save, renamed enum value).
  static TutorialStep _tutorialStepFromName(String? name) {
    if (name == null || name.isEmpty) return TutorialStep.welcome;
    for (final step in TutorialStep.values) {
      if (step.name == name) return step;
    }
    return TutorialStep.welcome;
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

      _tutorialCompleted = (data['tutorialCompleted'] as bool?) ?? false;
      if (_tutorialCompleted) {
        _tutorialStep = TutorialStep.done;
      } else {
        // Resume exactly where the player left off. The step used to be the
        // one piece of tutorial state never saved, so any app kill restarted
        // the main tutorial from `welcome` — and permanently lost the nexus
        // and neural tutorials, since both fire on one-time events.
        _tutorialStep = _tutorialStepFromName(data['tutorialStep'] as String?);
      }
      _nexusTutorialSeen = (data['nexusTutorialSeen'] as bool?) ?? false;
      _neuralTutorialSeen = (data['neuralTutorialSeen'] as bool?) ?? false;
      _upgradeTutorialSeen = (data['upgradeTutorialSeen'] as bool?) ?? false;

      _nexusStabilized = (data['nexusStabilized'] as bool?) ?? false;

      final nnJson = data['neuralNetwork'] as String?;
      if (nnJson != null) {
        try {
          neuralNetwork = NeuralNetwork.fromJsonString(nnJson);
        } catch (_) {
          neuralNetwork = NeuralNetwork.initial();
        }
      }

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

      if (totalIdleRate > 0) {
        final offlineGains = totalIdleRate * diff * offlineGainMultiplier;
        offlineGainsThisSession = BigInt.from(offlineGains.floor());
        number += offlineGainsThisSession;
        _updateHighestNumber();
        _idleAccumulator += offlineGains - offlineGains.floor();
      }

      if (neuralNetworkUnlocked && neuralNetwork.loss > _neuralMinLoss) {
        final s = neuralNetworkStrength;
        if (s > 0) {
          final oldAccuracy = neuralNetwork.accuracy;
          final newLoss =
              neuralNetwork.loss * math.exp(-_neuralDecayK * s * diff);
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
          int added = _idleAccumulator.floor();
          number += BigInt.from(added);
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
              neuralNetwork.loss * math.exp(-_neuralDecayK * s * _neuralDt);

          // Temporarily disable stochastic jitter so accuracy progression is
          // strictly monotonic from live training updates.
          neuralNetwork.loss = next.clamp(_neuralMinLoss, 1.0);
          if (neuralNetwork.loss < neuralNetwork.lowestLossEver) {
            neuralNetwork.lowestLossEver = neuralNetwork.loss;
          }
          hasStateChange = true;
        }
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
  static const double _neuralBoostScale = 30.0;
  static const double _neuralSoftCapPerPrestige = 5.0;

  bool get isOverclockActive => _overclockActive;
  double get momentumMultiplier => _momentumMultiplier;
  double get momentumProgress => _momentumProgress;
  bool get hasMomentumUpgrade => _isUpgradeActive(momentumId);

  int get _cascadeResonatorLevel =>
      _upgradeById(cascadeResonatorId)?.level ?? 0;

  double get totalIdleRate {
    // Require at least one actual idle generator upgrade before any idle
    // production can happen. This prevents post-prestige passive gain when
    // upgrade levels are reset to zero.
    if (autoClickRate <= 0.0) return 0.0;

    double idleRate = (autoClickRate + permanentIdleBonus) *
        prestigeMultiplier *
        resonanceMultiplier *
        neuralLossMultiplier;
    if (_overclockActive) {
      idleRate *= _overclockIdleMultiplier;
    }
    final cascadeLvl = _cascadeResonatorLevel;
    if (cascadeLvl > 0) {
      idleRate *= math.pow(2.0, cascadeLvl);
    }
    return idleRate;
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
  double _strengthCache = 0.0;

  /// [NeuralNetwork.computeStrength], cached against [neuralTopologyKey].
  /// Strength depends only on the shape, but the ticker needs it 10x/s.
  double get neuralNetworkStrength {
    if (!identical(_strengthCacheNetwork, neuralNetwork) ||
        _strengthCacheRevision != _neuralRevision) {
      _strengthCache = neuralNetwork.computeStrength();
      _strengthCacheNetwork = neuralNetwork;
      _strengthCacheRevision = _neuralRevision;
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
    return _neuralDecayK * neuralNetworkStrength;
  }

  int upgradeMilestoneMultiplierForLevel(int level) {
    if (level <= 0) return 1;

    int reachedMilestones = 0;
    for (final threshold in upgradeMilestoneThresholds) {
      if (level >= threshold) {
        reachedMilestones++;
      }
    }
    return 1 << reachedMilestones;
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
        final bonus = (prestigeMultiplier * upgrade.level * 500).floor();
        clickPower += BigInt.from(bonus);
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
    return 0.05; // Fixed 5% chance
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
    _lastManualClickTime = now;

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

    if (_tutorialStep == TutorialStep.triggerProbabilityStrike) {
      _tutorialStrikeClicks++;
    }
    final bool probabilityStrikeTriggered =
        _isUpgradeActive(probabilityStrikeId) &&
            (_rng.nextDouble() < _probabilityStrikeChance ||
                _tutorialForcesStrike);

    final baseClickGain =
        clickPower.toDouble() * prestigeMultiplier * neuralLossMultiplier;
    // kineticBonus inherits neuralLossMultiplier via totalIdleRate, so we
    // don't multiply it again here.
    final kineticBonus = totalIdleRate * _kineticSynergyShare;

    double gain = (baseClickGain + kineticBonus) * _momentumMultiplier;
    if (probabilityStrikeTriggered) {
      gain *= _probabilityStrikeMultiplier;
    }
    if (_neuralSparkBoostMultiplier != 1.0) {
      gain *= _neuralSparkBoostMultiplier;
    }

    final previousHighest = highestNumber;
    final gained = BigInt.from(gain.floor());
    number += gained;
    _updateHighestNumber();
    _advanceTutorialOnNumberReached();
    if (probabilityStrikeTriggered &&
        _tutorialStep == TutorialStep.triggerProbabilityStrike) {
      _tutorialStrikeClicks = 0;
      _tutorialStep = TutorialStep.navUpgradesForMomentum;
    }
    if (_tutorialStep == TutorialStep.demonstrateMomentum && _momentumProgress >= 1.0) {
      _tutorialStep = TutorialStep.navUpgradesForSpecial;
    }
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
    notifyListeners();

    _neuralSparkBoostTimer = Timer(duration, () {
      _neuralSparkBoostMultiplier = 1.0;
      notifyListeners();
    });
  }

  void _activateOverclock() {
    _overclockTimer?.cancel();
    final durationSeconds = _overclockDurationSeconds;
    _overclockActive = true;
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
    return 30 + lvl * 15;
  }

  int get temporalCollapseCooldownSeconds {
    final lvl = _temporalCollapseLevel;
    return math.max(80, 180 - lvl * 20);
  }

  bool get canActivateTemporalCollapse =>
      _temporalCollapseLevel > 0 &&
      !_temporalCollapseActive &&
      !_temporalCollapseCoolingDown;

  void activateTemporalCollapse() {
    if (!canActivateTemporalCollapse) return;

    final level = _temporalCollapseLevel;
    // Instant burst: level × 60 seconds of current idle production
    final burst = BigInt.from((totalIdleRate * 60 * level).floor());
    number += burst;
    _updateHighestNumber();

    // Temporarily double prestige multiplier for the duration
    prestigeMultiplier *= 2.0;
    _temporalCollapseActive = true;
    _recalculateDerivedStatsFromUpgrades();
    notifyListeners();

    _temporalCollapseActiveTimer?.cancel();
    _temporalCollapseActiveTimer =
        Timer(Duration(seconds: temporalCollapseDurationSeconds), () {
      prestigeMultiplier /= 2.0;
      _temporalCollapseActive = false;
      _temporalCollapseCoolingDown = true;
      _recalculateDerivedStatsFromUpgrades();
      notifyListeners();

      _temporalCollapseCooldownTimerRef?.cancel();
      _temporalCollapseCooldownTimerRef =
          Timer(Duration(seconds: temporalCollapseCooldownSeconds), () {
        _temporalCollapseCoolingDown = false;
        notifyListeners();
      });
    });
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

  ({BigInt cost, int amount}) getPurchaseInfo(Upgrade upgrade) {
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
        return (cost: BigInt.zero, amount: 0);
      }
      toBuy = math.min(toBuy, remainingLevels);
    }

    int bought = 0;
    BigInt totalCost = BigInt.zero;
    BigInt remainingNumber = number;

    double currentMultiplier = _costMultiplierAtLevel(upgrade);

    final costFactor = upgradeCostReductionFactor;
    while (bought < toBuy) {
      BigInt cost = BigInt.from(
          upgrade.baseCost.toDouble() * currentMultiplier * costFactor);
      if (remainingNumber >= cost) {
        remainingNumber -= cost;
        totalCost += cost;
        bought++;
        currentMultiplier *= upgrade.costMultiplier;
      } else {
        if (buyAmount == -1) {
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

    final isMaxMode = buyAmount == -1;
    int finalAmount = isMaxMode ? bought : toBuy;
    if (isMaxMode && finalAmount == 0) {
      final singleCost = BigInt.from(
          upgrade.baseCost.toDouble() * currentMultiplier * costFactor);
      return (cost: singleCost, amount: 0);
    }
    return (cost: totalCost, amount: finalAmount);
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
    if (id == cascadeResonatorId) return 5;
    if (id == temporalCollapseId) return 8;
    return 0;
  }

  void buyUpgrade(String id) {
    final upgrade = upgrades.firstWhere((u) => u.id == id);
    if (upgrade.isMaxed) return;
    if (prestigeCount < minPrestigeForUpgrade(id)) return;

    final info = getPurchaseInfo(upgrade);

    if (info.amount == 0) return;

    if (number >= info.cost) {
      number -= info.cost;
      upgrade.level += info.amount;
      _recalculateDerivedStatsFromUpgrades();
      _advanceTutorialOnPurchase(id);
      notifyListeners();
      _saveState();
    }
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

    for (var u in upgrades) {
      u.level = 0;
    }
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

    _completeTutorialOnPrestige();
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
    neuralNetwork = NeuralNetwork.initial();
    if (!preserveTutorial) {
      _tutorialCompleted = false;
      _tutorialStep = TutorialStep.welcome;
      _tutorialNeedsCloudSync = false;
      _nexusTutorialSeen = false;
      _neuralTutorialSeen = false;
      _upgradeTutorialSeen = false;
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

    // Carry forward neural loss from the cloud — keep whichever loss is
    // lower (more progress) so a stale upload can never wipe a better
    // training run on a different device.
    if (progress.neuralLoss < neuralNetwork.loss) {
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
      upgradeTutorialSeen: _upgradeTutorialSeen,
      nexusStabilized: _nexusStabilized,
      neuralNetworkJson: neuralNetwork.toJsonString(),
      testEnvironmentEnabled: _testEnvironmentEnabled,
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

  void onTutorialTapToContinue() {
    if (_tutorialStep == TutorialStep.welcome) {
      _tutorialStep = TutorialStep.clickToFifty;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.learnPrestige) {
      _tutorialStep = TutorialStep.navPrestige;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.learnPrestigeDetails) {
      _tutorialStep = TutorialStep.prestigeMultiplierHint;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.prestigeMultiplierHint) {
      _tutorialStep = TutorialStep.prestigeGainHint;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.prestigeGainHint) {
      _tutorialStep = TutorialStep.goodLuck;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.goodLuck) {
      unawaited(completeTutorialAndReset());
    } else if (_tutorialStep == TutorialStep.nexusIntro) {
      _tutorialStep = TutorialStep.nexusUpgrades;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.nexusUpgrades) {
      _tutorialStep = TutorialStep.nexusResearchOptProtocol;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.nexusGoal) {
      _completeNexusTutorial();
    } else if (_tutorialStep == TutorialStep.neuralUnlocked) {
      _tutorialStep = TutorialStep.navNeural;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.neuralIntro) {
      _tutorialStep = TutorialStep.neuralTapNeuron;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.neuralViewAccuracy) {
      _tutorialStep = TutorialStep.neuralAccuracyLimit;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.neuralAccuracyLimit) {
      _completeNeuralTutorial();
    } else if (_tutorialStep == TutorialStep.upgradeIntro) {
      _tutorialStep = TutorialStep.probabilityStrikeIntro;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.probabilityStrikeIntro) {
      selectedUpgradeCategory = clickCategory;
      _tutorialStep = TutorialStep.buyProbabilityStrike;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.buyProbabilityStrike) {
      _tutorialStep = TutorialStep.navGeneratorsForStrike;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navGeneratorsForStrike) {
      _tutorialStep = TutorialStep.triggerProbabilityStrike;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.triggerProbabilityStrike) {
      _tutorialStep = TutorialStep.momentumIntro;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.momentumIntro) {
      selectedUpgradeCategory = clickCategory;
      _tutorialStep = TutorialStep.buyMomentum;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.buyMomentum) {
      _tutorialStep = TutorialStep.demonstrateMomentum;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.demonstrateMomentum) {
      _tutorialStep = TutorialStep.navUpgradesForSpecial;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navUpgradesForSpecial) {
      selectedUpgradeCategory = clickCategory;
      _tutorialStep = TutorialStep.kineticSynergyIntro;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.kineticSynergyIntro) {
      _tutorialStep = TutorialStep.overclockIntro;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.overclockIntro) {
      _tutorialStep = TutorialStep.upgradesDone;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.upgradesDone) {
      _completeUpgradeTutorial();
      notifyListeners();
    }
  }

  bool _isNexusTutorialStep(TutorialStep step) {
    return step == TutorialStep.nexusIntro ||
        step == TutorialStep.nexusUpgrades ||
        step == TutorialStep.nexusResearchOptProtocol ||
        step == TutorialStep.nexusGoal;
  }

  bool _isNeuralTutorialStep(TutorialStep step) {
    return step == TutorialStep.neuralUnlocked ||
        step == TutorialStep.navNeural ||
        step == TutorialStep.neuralIntro ||
        step == TutorialStep.neuralTapNeuron ||
        step == TutorialStep.neuralUpgradeGradient ||
        step == TutorialStep.neuralChangeActivation ||
        step == TutorialStep.neuralBranchNeuron ||
        step == TutorialStep.neuralViewAccuracy ||
        step == TutorialStep.neuralAccuracyLimit;
  }

  bool _isUpgradeTutorialStep(TutorialStep step) {
    return step == TutorialStep.upgradeIntro ||
        step == TutorialStep.probabilityStrikeIntro ||
        step == TutorialStep.buyProbabilityStrike ||
        step == TutorialStep.navGeneratorsForStrike ||
        step == TutorialStep.triggerProbabilityStrike ||
        step == TutorialStep.navUpgradesForMomentum ||
        step == TutorialStep.momentumIntro ||
        step == TutorialStep.buyMomentum ||
        step == TutorialStep.navGeneratorsForMomentum ||
        step == TutorialStep.demonstrateMomentum ||
        step == TutorialStep.navUpgradesForSpecial ||
        step == TutorialStep.kineticSynergyIntro ||
        step == TutorialStep.overclockIntro ||
        step == TutorialStep.upgradesDone;
  }

  /// Budget handed to the player so the upgrade deep-dive is affordable.
  static final BigInt upgradeTutorialGrant = BigInt.from(100000000);

  void _startUpgradeTutorial() {
    // Only show the upgrade tutorial once during the main tutorial.
    if (_upgradeTutorialSeen) {
      _tutorialStep = TutorialStep.learnPrestige;
      return;
    }

    // Snapshot what the player actually had, so finishing (or skipping) the
    // sub-tutorial restores it rather than zeroing everything. The old
    // teardown set number = 0 and every upgrade level = 0 unconditionally,
    // which destroyed real progress — and it was the SKIP path too.
    _upgradeTutorialNumberSnapshot = number;
    _upgradeTutorialLevelSnapshot = {
      for (final u in upgrades) u.id: u.level,
    };

    number = number + upgradeTutorialGrant;
    _tutorialStep = TutorialStep.upgradeIntro;
  }

  void _completeUpgradeTutorial() {
    // Restore the pre-tutorial snapshot: the grant and anything bought with
    // it goes away, but progress the player earned themselves survives.
    final numberSnapshot = _upgradeTutorialNumberSnapshot;
    final levelSnapshot = _upgradeTutorialLevelSnapshot;
    if (numberSnapshot != null) {
      number = numberSnapshot;
    }
    if (levelSnapshot != null) {
      for (final u in upgrades) {
        final restored = levelSnapshot[u.id];
        if (restored != null) {
          u.level = u.maxLevel == -1
              ? restored
              : restored.clamp(0, u.maxLevel);
        }
      }
    }
    _upgradeTutorialNumberSnapshot = null;
    _upgradeTutorialLevelSnapshot = null;
    // Set only now that the sub-tutorial has actually finished. Setting it at
    // the start meant an app kill mid-deep-dive short-circuited straight to
    // learnPrestige on relaunch, and the grant was never clawed back.
    _upgradeTutorialSeen = true;
    _recalculateDerivedStatsFromUpgrades();
    _tutorialStep = TutorialStep.learnPrestige;
  }

  void _completeNexusTutorial() {
    _nexusTutorialSeen = true;
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

  void skipTutorial() {
    if (_isNexusTutorialStep(_tutorialStep)) {
      _completeNexusTutorial();
      return;
    }
    if (_isNeuralTutorialStep(_tutorialStep)) {
      _completeNeuralTutorial();
      return;
    }
    if (_isUpgradeTutorialStep(_tutorialStep)) {
      // Restore the snapshot, then leave the tutorial entirely. This used to
      // drop the player at learnPrestige, so SKIP needed up to four presses
      // to actually escape.
      _completeUpgradeTutorial();
      _tutorialCompleted = true;
      _tutorialStep = TutorialStep.done;
      _tutorialNeedsCloudSync = true;
      notifyListeners();
      _scheduleStateSave();
      unawaited(syncTutorialCompletedToProfileIfNeeded());
      return;
    }
    _tutorialCompleted = true;
    _tutorialStep = TutorialStep.done;
    _tutorialNeedsCloudSync = true;
    notifyListeners();
    _scheduleStateSave();
    unawaited(syncTutorialCompletedToProfileIfNeeded());
  }

  void onMainTabChanged(int index) {
    if (_tutorialStep == TutorialStep.navUpgrades && index == 1) {
      _tutorialStep = TutorialStep.selectIdle;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navGenerators && index == 0) {
      _tutorialStep = TutorialStep.watchIdle;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navUpgradesForClick &&
        index == 1) {
      selectedUpgradeCategory = clickCategory;
      _tutorialStep = TutorialStep.buyClickPower;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navPrestige && index == 2) {
      _tutorialStep = TutorialStep.learnPrestigeDetails;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navNeural && index == 3) {
      _tutorialStep = TutorialStep.neuralIntro;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navGeneratorsForStrike &&
        index == 0) {
      _tutorialStep = TutorialStep.triggerProbabilityStrike;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navUpgradesForMomentum &&
        index == 1) {
      selectedUpgradeCategory = clickCategory;
      _tutorialStep = TutorialStep.momentumIntro;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navGeneratorsForMomentum &&
        index == 0) {
      _tutorialStep = TutorialStep.demonstrateMomentum;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.navUpgradesForSpecial &&
        index == 1) {
      selectedUpgradeCategory = clickCategory;
      _tutorialStep = TutorialStep.kineticSynergyIntro;
      notifyListeners();
    }
    // No `else` for other tabs on purpose: the overlay reads
    // TutorialStepSpec.requiredTab and shows only SKIP when the player is
    // somewhere the current step doesn't apply, rather than pointing a
    // spotlight at a nav item while a different screen is on show.
    //
    // (A `goodLuck && index == 0` branch used to live here that assigned the
    // step to itself — dead code.)
  }

  void _advanceTutorialOnPurchase(String upgradeId) {
    if (_tutorialStep == TutorialStep.buyAutoClicker &&
        upgradeId == autoClickerId) {
      _tutorialStep = TutorialStep.navGenerators;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.buyClickPower &&
        upgradeId == clickPowerId) {
      _startUpgradeTutorial();
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.buyProbabilityStrike &&
        upgradeId == probabilityStrikeId) {
      _tutorialStep = TutorialStep.navGeneratorsForStrike;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.buyMomentum &&
        upgradeId == momentumId) {
      _tutorialStep = TutorialStep.navGeneratorsForMomentum;
      notifyListeners();
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
      _tutorialStep = TutorialStep.navUpgrades;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.watchIdle &&
        number >= tutorialIdleWatchTarget) {
      _tutorialStep = TutorialStep.navUpgradesForClick;
      notifyListeners();
    }
  }

  Future<void> completeTutorialAndReset() async {
    _tutorialCompleted = true;
    _tutorialStep = TutorialStep.done;
    _tutorialNeedsCloudSync = true;
    notifyListeners();
    _onTutorialResetCallback?.call();
    await hardReset(preserveTutorial: true);
    unawaited(syncTutorialCompletedToProfileIfNeeded());
  }

  void _completeTutorialOnPrestige() {
    // Prestige no longer ends the tutorial — kept as no-op for safety.
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
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
}
