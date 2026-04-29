import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/upgrade.dart';
import '../models/research_node.dart';
import '../models/player_progress.dart';
import '../data/nexus_data.dart';
import '../models/neural_network.dart';
import 'storage_service.dart';
import 'sync_service.dart';
import 'supabase_service.dart';
import 'tutorial_step.dart';

class GameState extends ChangeNotifier {
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
  BigInt clickPower = BigInt.from(10000);
  Object _prestigeCurrency = 10000.0;
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
  int prestigeCount = 500;

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
  bool _cloudSyncInProgress = false;
  String? _lastCloudSyncError;

  bool isPrestigeAnimating = false;
  bool get cloudSyncInProgress => _cloudSyncInProgress;
  String? get lastCloudSyncError => _lastCloudSyncError;

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
  VoidCallback? _onTutorialResetCallback;

  TutorialStep get tutorialStep => _tutorialStep;
  bool get tutorialCompleted => _tutorialCompleted;
  bool get isTutorialActive => _tutorialStep != TutorialStep.done;
  bool get nexusTutorialSeen => _nexusTutorialSeen;
  bool get neuralTutorialSeen => _neuralTutorialSeen;

  void registerTutorialResetCallback(VoidCallback cb) {
    _onTutorialResetCallback = cb;
  }

  void setPrestigeAnimating(bool value) {
    isPrestigeAnimating = value;
    notifyListeners();
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
  static const Duration _saveDebounceDuration = Duration(milliseconds: 350);

  // Upgrades
  List<Upgrade> upgrades = [
    Upgrade(
      id: clickPowerId,
      name: 'Click Power',
      description: 'Increases value per click.',
      baseCost: BigInt.from(100),
      costMultiplier: 1.45,
      effectType: clickCategory,
      effectValue: BigInt.from(50),
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
      id: autoClickerId,
      name: 'Auto-Clicker',
      description: 'Clicks for you automatically.',
      baseCost: BigInt.from(50),
      costMultiplier: 1.15,
      effectType: idleCategory,
      effectValue: 1.0,
    ),
    Upgrade(
      id: quantumMultiplierId,
      name: 'Quantum Multiplier',
      description: 'Greatly increases idle generation.',
      baseCost: BigInt.from(1500),
      costMultiplier: 1.85,
      effectType: idleCategory,
      effectValue: 10.0,
    ),
    Upgrade(
      id: 'idle_fractal_engine',
      name: 'Fractal Engine',
      description: 'Adds +100 numbers per second each level.',
      baseCost: BigInt.from(7500),
      costMultiplier: 1.55,
      effectType: idleCategory,
      effectValue: 100.0,
    ),
    Upgrade(
      id: 'idle_singularity_core',
      name: 'Singularity Core',
      description: 'Adds +1,000 numbers per second each level.',
      baseCost: BigInt.from(65000),
      costMultiplier: 1.58,
      effectType: idleCategory,
      effectValue: 1000.0,
    ),
    Upgrade(
      id: 'idle_tesseract_array',
      name: 'Tesseract Array',
      description: 'Adds +10,000 numbers per second each level.',
      baseCost: BigInt.from(750000),
      costMultiplier: 1.62,
      effectType: idleCategory,
      effectValue: 10000.0,
    ),
    Upgrade(
      id: 'idle_entropy_harvester',
      name: 'Entropy Harvester',
      description: 'Adds +100,000 numbers per second each level.',
      baseCost: BigInt.from(9000000),
      costMultiplier: 1.66,
      effectType: idleCategory,
      effectValue: 100000.0,
    ),
    Upgrade(
      id: 'idle_void_resonance',
      name: 'Void Resonance',
      description: 'Adds +1,000,000 numbers per second each level.',
      baseCost: BigInt.from(120000000),
      costMultiplier: 1.7,
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

  GameState() {
    _init();
  }

  /// ── NEXUS research getters ─────────────────────────────────────────────

  int _nexusLevel(String id) =>
      researchNodes.where((n) => n.id == id).firstOrNull?.level ?? 0;

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
      _tutorialStep = TutorialStep.neuralUnlocked;
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

    notifyListeners();
    _scheduleStateSave();
    return true;
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

  /// Number required to perform the next prestige.
  BigInt get prestigeRequirement => prestigeRequirementAtCount(prestigeCount);

  /// Fixed reward for the next prestige activation.
  double get nextPrestigeReward => prestigeRewardAtCount(prestigeCount);

  /// Requirement for the prestige at [count] completed prestiges.
  /// Starts at 10,000 and increases exponentially each prestige.
  static BigInt prestigeRequirementAtCount(int count) {
    const baseRequirement = 10000.0;
    const growthPerPrestige = 2.5;
    final scaled = baseRequirement * math.pow(growthPerPrestige, count);
    return BigInt.from(scaled.floor());
  }

  /// Fixed prestige point reward for the next prestige (independent of current number).
  /// First prestige gives 1.0 point, then grows exponentially.
  static double prestigeRewardAtCount(int count) {
    const baseReward = 3.0;
    const growthPerPrestige = 1.35;
    return baseReward * math.pow(growthPerPrestige, count);
  }

  /// Calculates fixed prestige points from [currentNumber] for the next prestige.
  double calculatePrestigePoints(BigInt currentNumber) {
    final requirement = prestigeRequirement;
    if (currentNumber < requirement) return 0.0;
    return nextPrestigeReward * prestigePointsMultiplier;
  }

  // Testing utility: add prestige currency directly
  void addPrestigePointsForTesting(int amount) {
    prestigeCurrency = (prestigeCurrency as double) + amount;
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      final data = await _storageService.loadGame();
      number = data['number'] as BigInt;

      final savedClickPower = data['clickPower'] as BigInt;
      clickPower =
          savedClickPower < BigInt.from(50) ? BigInt.from(50) : savedClickPower;

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
      }
      _nexusTutorialSeen = (data['nexusTutorialSeen'] as bool?) ?? false;
      _neuralTutorialSeen = (data['neuralTutorialSeen'] as bool?) ?? false;

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
    } finally {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    }
  }

  void _calculateOfflineProgress(DateTime? lastPlayed) {
    if (lastPlayed != null) {
      final diff = DateTime.now().difference(lastPlayed).inSeconds;
      if (diff > 0) {
        if (totalIdleRate > 0) {
          final offlineGains = totalIdleRate * diff * offlineGainMultiplier;
          offlineGainsThisSession = BigInt.from(offlineGains.floor());
          number += offlineGainsThisSession;
          _updateHighestNumber();
          _idleAccumulator += offlineGains - offlineGains.floor();
        }

        if (neuralNetworkUnlocked && neuralNetwork.loss > _neuralMinLoss) {
          final s = neuralNetwork.computeStrength();
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
  }

  void clearOfflineGains() {
    offlineGainsThisSession = BigInt.zero;
    offlineAccuracyGain = 0.0;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      bool hasStateChange = _updateMomentumDecay();

      if (autoClickRate > 0) {
        final effectiveRate = totalIdleRate;
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
        final s = neuralNetwork.computeStrength();
        if (s > 0) {
          final next = neuralNetwork.loss * math.exp(-_neuralDecayK * s * _neuralDt);

          // Add training noise: ~5% of ticks get a small upward jitter
          // to simulate mini-batch noise in real SGD. This creates realistic
          // fluctuation while keeping the overall trend downward.
          final noiseChance = _rng.nextDouble();
          double noisedLoss = next;
          if (noiseChance < 0.05) {
            // Add a small random increase (up to 2% of current loss)
            final noiseAmount = next * (0.005 + _rng.nextDouble() * 0.015);
            noisedLoss = next + noiseAmount;
          }

          neuralNetwork.loss = noisedLoss.clamp(_neuralMinLoss, 1.0);
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
  // First-pass values; revisit by playtest. Goal: a fully tuned network
  // (all neurons gradient 5, preferred activations) reaches loss ≈ 0.01 in
  // roughly 24h of continuous play.
  static const double _neuralDt = 0.1; // ticker period in seconds
  static const double _neuralDecayK = 0.00008;
  static const double _neuralMinLoss = 1e-6;
  static const double _neuralBoostScale = 50.0;
  static const double _neuralSoftCapPerPrestige = 5.0;

  bool get isOverclockActive => _overclockActive;
  double get momentumMultiplier => _momentumMultiplier;
  double get momentumProgress => _momentumProgress;
  bool get hasMomentumUpgrade => _isUpgradeActive(momentumId);

  int get _cascadeResonatorLevel {
    final idx = upgrades.indexWhere((u) => u.id == cascadeResonatorId);
    return idx == -1 ? 0 : upgrades[idx].level;
  }

  double get totalIdleRate {
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
    return _neuralDecayK * neuralNetwork.computeStrength();
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

  void _recalculateDerivedStatsFromUpgrades() {
    clickPower = BigInt.from(10000);
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
        clickPower += (upgrade.effectValue as BigInt) *
            BigInt.from(upgrade.level * milestoneMultiplier);
      }
    }
  }

  int _upgradeLevel(String id) {
    final idx = upgrades.indexWhere((u) => u.id == id);
    if (idx == -1) return 0;
    final upgrade = upgrades[idx];
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

  bool _isUpgradeActive(String id) {
    final idx = upgrades.indexWhere((u) => u.id == id);
    if (idx == -1) return false;
    return upgrades[idx].level > 0;
  }

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

    bool momentumChanged = false;
    if (_isUpgradeActive(momentumId)) {
      final comboBonus = (_clickStreak - 1) * _momentumPerClickBonus;
      final newMultiplier = (1.0 + comboBonus).clamp(1.0, _momentumCap);
      final newProgress = (_clickStreak / _momentumClicksToCap).clamp(0.0, 1.0);

      // Always update on click to ensure UI stays responsive
      _momentumMultiplier = newMultiplier;
      _momentumProgress = newProgress;
      momentumChanged = true;
    } else {
      if (_momentumMultiplier != 1.0 || _momentumProgress != 0.0) {
        _momentumMultiplier = 1.0;
        _momentumProgress = 0.0;
        momentumChanged = true;
      }
    }

    bool overclockChanged = false;
    if (_isUpgradeActive(overclockId) &&
        _clickStreak >= _overclockStreakRequirement &&
        !_overclockTriggeredThisChain) {
      _overclockTriggeredThisChain = true;
      _activateOverclock();
      overclockChanged = true;
    }

    final bool probabilityStrikeTriggered =
        _isUpgradeActive(probabilityStrikeId) &&
            _rng.nextDouble() < _probabilityStrikeChance;

    final baseClickGain =
        clickPower.toDouble() * prestigeMultiplier * neuralLossMultiplier;
    // kineticBonus inherits neuralLossMultiplier via totalIdleRate, so we
    // don't multiply it again here.
    final kineticBonus = totalIdleRate * _kineticSynergyShare;

    double gain = (baseClickGain + kineticBonus) * _momentumMultiplier;
    if (probabilityStrikeTriggered) {
      gain *= _probabilityStrikeMultiplier;
    }

    final previousHighest = highestNumber;
    final gained = BigInt.from(gain.floor());
    number += gained;
    _updateHighestNumber();
    _advanceTutorialOnNumberReached();
    final personalBestReached = highestNumber > previousHighest;

    // Only notify if momentum or overclock changed, number update is handled by Selector
    if (momentumChanged || overclockChanged) {
      notifyListeners();
    } else {
      // Still need to notify for number changes, but this is already optimized by Selector
      notifyListeners();
    }

    _scheduleStateSave();
    return (
      gain: gained,
      probabilityStrikeTriggered: probabilityStrikeTriggered,
      personalBestReached: personalBestReached,
    );
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

  int get _temporalCollapseLevel {
    final idx = upgrades.indexWhere((u) => u.id == temporalCollapseId);
    return idx == -1 ? 0 : upgrades[idx].level;
  }

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
    if (selectedUpgradeCategory == category) return;
    selectedUpgradeCategory = category;
    if (_tutorialStep == TutorialStep.selectIdle && category == idleCategory) {
      _tutorialStep = TutorialStep.buyAutoClicker;
    }
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

    double currentMultiplier = 1.0;
    for (int i = 0; i < upgrade.level; i++) {
      currentMultiplier *= upgrade.costMultiplier;
    }

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
        await SupabaseService.instance.archiveSession(
          userId: userId,
          sessionProgress: sessionSnapshot,
        );
      } catch (e) {
        // Log error but don't prevent prestige
        debugPrint('Failed to archive session: $e');
      }
    }

    prestigeCurrency += pointsToEarn;
    prestigeMultiplier += nextPrestigeDelta;
    prestigeCount += 1;

    number = BigInt.zero;
    clickPower = BigInt.from(10000);
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
    number = BigInt.zero;
    clickPower = BigInt.from(10000);
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
    neuralNetwork = NeuralNetwork.initial();
    if (!preserveTutorial) {
      _tutorialCompleted = false;
      _tutorialStep = TutorialStep.welcome;
      _tutorialNeedsCloudSync = false;
      _nexusTutorialSeen = false;
      _neuralTutorialSeen = false;
    }
    _recalculateDerivedStatsFromUpgrades();

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

  void _updateHighestNumber() {
    if (number > highestNumber) {
      highestNumber = number;
    }
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
      updatedAt: _lastSavedAt?.toUtc() ?? now,
    );
  }

  void _applyCloudProgress(PlayerProgress progress) {
    number = progress.number;
    clickPower = progress.clickPower < BigInt.from(50)
        ? BigInt.from(50)
        : progress.clickPower;
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

      if (result.winner == SyncWinner.remote) {
        _applyCloudProgress(result.resolved);
        _startTicker();
      } else {
        highestNumber = result.resolved.normalizedHighestNumber;
      }

      _lastCloudPushAt = DateTime.now().toUtc();
      await _persistState(skipCloudUpload: true);
      notifyListeners();
    } catch (error) {
      _lastCloudSyncError = error.toString();
      notifyListeners();
    } finally {
      _cloudSyncInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _saveState() async {
    await _persistState(skipCloudUpload: false);
  }

  Future<void> _persistState({required bool skipCloudUpload}) async {
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
      nexusTutorialSeen: _nexusTutorialSeen,
      neuralTutorialSeen: _neuralTutorialSeen,
      nexusStabilized: _nexusStabilized,
      neuralNetworkJson: neuralNetwork.toJsonString(),
    );
    _lastSavedAt = DateTime.now();

    if (skipCloudUpload ||
        !_syncService.isAvailable ||
        _syncService.currentUserId == null) {
      return;
    }

    final now = DateTime.now();
    final shouldPush = _lastCloudPushAt == null ||
        now.difference(_lastCloudPushAt!).inSeconds >= 20;
    if (shouldPush) {
      unawaited(syncWithCloud());
    }
  }

  void _scheduleStateSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounceDuration, _saveState);
  }

  // ── Tutorial methods ───────────────────────────────────────────────────

  void setTutorialCompletionFromProfile(bool completed) {
    if (completed == _tutorialCompleted) return;
    _tutorialCompleted = completed;
    if (completed) {
      _tutorialStep = TutorialStep.done;
    } else {
      _tutorialStep = TutorialStep.welcome;
    }
    notifyListeners();
  }

  Future<void> syncTutorialCompletedToProfileIfNeeded() async {
    if (!_tutorialNeedsCloudSync) return;
    final userId = _syncService.currentUserId;
    if (userId == null) return;
    _tutorialNeedsCloudSync = false;
    try {
      await SupabaseService.instance.setProfileTutorialCompleted(
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
          await SupabaseService.instance.fetchProfile(userId: userId);
      if (profile != null) {
        setTutorialCompletionFromProfile(profile.tutorialCompleted);
      }
    } catch (_) {}
  }

  void onTutorialTapToContinue() {
    if (_tutorialStep == TutorialStep.welcome) {
      _tutorialStep = TutorialStep.clickToFifty;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.exploreUpgrades) {
      _tutorialStep = TutorialStep.learnPrestige;
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
      _tutorialStep = TutorialStep.nexusGoal;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.nexusGoal) {
      _completeNexusTutorial();
    } else if (_tutorialStep == TutorialStep.neuralUnlocked) {
      _tutorialStep = TutorialStep.navNeural;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.neuralIntro) {
      _tutorialStep = TutorialStep.neuralUpgradeHint;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.neuralUpgradeHint) {
      _tutorialStep = TutorialStep.neuralBranchHint;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.neuralBranchHint) {
      _tutorialStep = TutorialStep.neuralTrainHint;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.neuralTrainHint) {
      _completeNeuralTutorial();
    }
  }

  bool _isNexusTutorialStep(TutorialStep step) {
    return step == TutorialStep.nexusIntro ||
        step == TutorialStep.nexusUpgrades ||
        step == TutorialStep.nexusGoal;
  }

  bool _isNeuralTutorialStep(TutorialStep step) {
    return step == TutorialStep.neuralUnlocked ||
        step == TutorialStep.navNeural ||
        step == TutorialStep.neuralIntro ||
        step == TutorialStep.neuralUpgradeHint ||
        step == TutorialStep.neuralBranchHint ||
        step == TutorialStep.neuralTrainHint;
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
    } else if (_tutorialStep == TutorialStep.goodLuck && index == 0) {
      // User navigated back to main screen during final tutorial
      _tutorialStep = TutorialStep.goodLuck;
      notifyListeners();
    }
  }

  void _advanceTutorialOnPurchase(String upgradeId) {
    if (_tutorialStep == TutorialStep.buyAutoClicker &&
        upgradeId == autoClickerId) {
      _tutorialStep = TutorialStep.navGenerators;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.buyClickPower &&
        upgradeId == clickPowerId) {
      _tutorialStep = TutorialStep.exploreUpgrades;
      notifyListeners();
    }
  }

  void _advanceTutorialOnNumberReached() {
    if (_tutorialStep == TutorialStep.clickToFifty &&
        number >= BigInt.from(50)) {
      _tutorialStep = TutorialStep.navUpgrades;
      notifyListeners();
    } else if (_tutorialStep == TutorialStep.watchIdle &&
        number >= BigInt.from(100)) {
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
    _ticker?.cancel();
    _overclockTimer?.cancel();
    _temporalCollapseActiveTimer?.cancel();
    _temporalCollapseCooldownTimerRef?.cancel();
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
}
