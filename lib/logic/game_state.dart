import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/upgrade.dart';
import 'storage_service.dart';

class GameState extends ChangeNotifier {
  static const String clickCategory = 'click';
  static const String idleCategory = 'idle';

  static const String probabilityStrikeId = 'click_probability_strike';
  static const String momentumId = 'click_momentum';
  static const String kineticSynergyId = 'click_kinetic_synergy';
  static const String overclockId = 'click_overclock';
  static const String clickPowerId = 'click_power';
  static const String autoClickerId = 'idle_auto_clicker';
  static const String quantumMultiplierId = 'idle_quantum_multiplier';

  final StorageService _storageService = StorageService();
  final Completer<void> _readyCompleter = Completer<void>();
  final math.Random _rng = math.Random();

  Future<void> get ready => _readyCompleter.future;

  BigInt number = BigInt.zero;
  BigInt clickPower = BigInt.from(50);
  Object _prestigeCurrency = 0.0;
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

  /// Times each permanent shop track was upgraded (incremental bonuses scale with rank).
  int permanentClickPurchases = 0;
  int permanentIdlePurchases = 0;

  int buyAmount = 1; // 1, 10, 100, -1 (MAX)

  double _idleAccumulator = 0.0;
  double autoClickRate = 0.0; // Per second Rate
  DateTime? _lastManualClickTime;
  int _clickStreak = 0;
  bool _overclockTriggeredThisChain = false;
  double _momentumMultiplier = 1.0;
  double _momentumProgress = 0.0;
  bool _overclockActive = false;

  BigInt offlineGainsThisSession = BigInt.zero;

  bool isPrestigeAnimating = false;

  void setPrestigeAnimating(bool value) {
    isPrestigeAnimating = value;
    notifyListeners();
  }

  Timer? _ticker;
  Timer? _overclockTimer;

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
          'Gives a 5% chance that a manual click yields 10x its normal value.',
      baseCost: BigInt.from(2500),
      costMultiplier: 1.0,
      effectType: clickCategory,
      effectValue: 0,
      maxLevel: 1,
    ),
    Upgrade(
      id: momentumId,
      name: 'Momentum',
      description:
          'Rapid clicking builds a combo multiplier up to 2.0x, reset after 1s idle.',
      baseCost: BigInt.from(8000),
      costMultiplier: 1.0,
      effectType: clickCategory,
      effectValue: 0,
      maxLevel: 1,
    ),
    Upgrade(
      id: kineticSynergyId,
      name: 'Kinetic Synergy',
      description:
          'Adds 1% of your total idle Numbers Per Second to your manual click power.',
      baseCost: BigInt.from(40000),
      costMultiplier: 1.0,
      effectType: clickCategory,
      effectValue: 0,
      maxLevel: 1,
    ),
    Upgrade(
      id: overclockId,
      name: 'Overclock',
      description:
          'Doubles idle production for 30 seconds after 50 manual clicks in a row.',
      baseCost: BigInt.from(125000),
      costMultiplier: 1.0,
      effectType: clickCategory,
      effectValue: 0,
      maxLevel: 1,
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
      description: 'Generates 100 numbers per second.',
      baseCost: BigInt.from(7500),
      costMultiplier: 1.0,
      effectType: idleCategory,
      effectValue: 100.0,
      maxLevel: 1,
    ),
    Upgrade(
      id: 'idle_singularity_core',
      name: 'Singularity Core',
      description: 'Generates 1,000 numbers per second.',
      baseCost: BigInt.from(65000),
      costMultiplier: 1.0,
      effectType: idleCategory,
      effectValue: 1000.0,
      maxLevel: 1,
    ),
    Upgrade(
      id: 'idle_tesseract_array',
      name: 'Tesseract Array',
      description: 'Generates 10,000 numbers per second.',
      baseCost: BigInt.from(750000),
      costMultiplier: 1.0,
      effectType: idleCategory,
      effectValue: 10000.0,
      maxLevel: 1,
    ),
    Upgrade(
      id: 'idle_entropy_harvester',
      name: 'Entropy Harvester',
      description: 'Generates 100,000 numbers per second.',
      baseCost: BigInt.from(9000000),
      costMultiplier: 1.0,
      effectType: idleCategory,
      effectValue: 100000.0,
      maxLevel: 1,
    ),
    Upgrade(
      id: 'idle_void_resonance',
      name: 'Void Resonance',
      description: 'Generates 1,000,000 numbers per second.',
      baseCost: BigInt.from(120000000),
      costMultiplier: 1.0,
      effectType: idleCategory,
      effectValue: 1000000.0,
      maxLevel: 1,
    ),
  ];

  GameState() {
    _init();
  }

  /// Increment added on the prestige with index [prestigeIndex] (0 = first prestige).
  static double prestigeDeltaAtIndex(int prestigeIndex) {
    const base = 0.028;
    const perStep = 0.011;
    return base + prestigeIndex * perStep;
  }

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
      prestigeMultiplier + prestigeDeltaAtIndex(prestigeCount);

  /// Number required to perform the next prestige.
  BigInt get prestigeRequirement => prestigeRequirementAtCount(prestigeCount);

  /// Fixed reward for the next prestige activation.
  double get nextPrestigeReward => prestigeRewardAtCount(prestigeCount);

  /// Prestige-shop permanent mult (click): starts ~1.0, grows in small steps per purchase.
  double get permanentClickMultiplier =>
      multiplierFromPermanentPurchases(permanentClickPurchases);

  /// Prestige-shop permanent mult (idle).
  double get permanentIdleMultiplier =>
      multiplierFromPermanentPurchases(permanentIdlePurchases);

  /// Bonus per permanent-shop tier (like prestige deltas, a bit smaller).
  static double permanentShopDeltaAtIndex(int index) {
    const base = 0.014;
    const perStep = 0.006;
    return base + index * perStep;
  }

  static double multiplierFromPermanentPurchases(int purchases) {
    double m = 1.0;
    for (int i = 0; i < purchases; i++) {
      m += permanentShopDeltaAtIndex(i);
    }
    return m;
  }

  /// Prestige points for the next single upgrade on this track.
  static double shopPrestigeCostAtRank(int rank) {
    return 1.0 + (rank / 14.0);
  }

  /// Requirement for the prestige at [count] completed prestiges.
  /// Starts at 10,000 and increases exponentially each prestige.
  static BigInt prestigeRequirementAtCount(int count) {
    const baseRequirement = 10000.0;
    const growthPerPrestige = 1.32;
    final scaled = baseRequirement * math.pow(growthPerPrestige, count);
    return BigInt.from(scaled.floor());
  }

  /// Fixed prestige point reward for the next prestige (independent of current number).
  /// First prestige gives 1.0 point, then grows exponentially.
  static double prestigeRewardAtCount(int count) {
    const baseReward = 1.0;
    const growthPerPrestige = 1.18;
    return baseReward * math.pow(growthPerPrestige, count);
  }

  /// Calculates fixed prestige points from [currentNumber] for the next prestige.
  double calculatePrestigePoints(BigInt currentNumber) {
    final requirement = prestigeRequirement;
    if (currentNumber < requirement) return 0.0;
    return nextPrestigeReward;
  }

  /// Total prestige cost for buying [bulkAmount] steps (1/10/100) or -1 for MAX affordable.
  double totalShopPrestigeCost({
    required bool forClick,
    required int bulkAmount,
  }) {
    int rank = forClick ? permanentClickPurchases : permanentIdlePurchases;
    if (bulkAmount == -1) {
      double sum = 0.0;
      double wallet = prestigeCurrency;
      int r = rank;
      while (wallet > 0.0) {
        final c = shopPrestigeCostAtRank(r);
        if (wallet < c) break;
        wallet -= c;
        sum += c;
        r++;
      }
      return sum;
    }
    double sum = 0.0;
    for (int i = 0; i < bulkAmount; i++) {
      sum += shopPrestigeCostAtRank(rank + i);
    }
    return sum;
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

      final pcp = data['permanentClickPurchases'] as int?;
      final pip = data['permanentIdlePurchases'] as int?;
      final upgradeLevels =
          (data['upgradeLevels'] as Map<String, int>?) ?? <String, int>{};
      if (pcp != null) {
        permanentClickPurchases = pcp.clamp(0, 999999);
      } else {
        final old = data['legacyPermanentClick'] as BigInt?;
        permanentClickPurchases =
            old != null ? (old - BigInt.one).toInt().clamp(0, 999999) : 0;
      }
      if (pip != null) {
        permanentIdlePurchases = pip.clamp(0, 999999);
      } else {
        final old = data['legacyPermanentIdle'] as BigInt?;
        permanentIdlePurchases =
            old != null ? (old - BigInt.one).toInt().clamp(0, 999999) : 0;
      }

      if (pcp == null || pip == null) {
        await _saveState();
      }

      for (final upgrade in upgrades) {
        final savedLevel = upgradeLevels[upgrade.id] ?? 0;
        final normalizedLevel = upgrade.maxLevel == -1
            ? savedLevel
            : savedLevel.clamp(0, upgrade.maxLevel);
        upgrade.level = normalizedLevel;
      }

      final lastPlayed = data['lastPlayed'] as DateTime?;
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
    if (lastPlayed != null && autoClickRate > 0) {
      final diff = DateTime.now().difference(lastPlayed).inSeconds;
      if (diff > 0) {
        final idleMult = prestigeMultiplier * permanentIdleMultiplier;
        final offlineGains = autoClickRate * idleMult * diff;
        offlineGainsThisSession = BigInt.from(offlineGains.floor());
        number += offlineGainsThisSession;
        _idleAccumulator += offlineGains - offlineGains.floor();
      }
    }
  }

  void clearOfflineGains() {
    offlineGainsThisSession = BigInt.zero;
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
          _idleAccumulator -= added;
          hasStateChange = true;

          // Periodically save
          if (timer.tick % 50 == 0) {
            _saveState();
          }
        }
      }

      if (hasStateChange) {
        notifyListeners();
      }
    });
  }

  bool get isOverclockActive => _overclockActive;
  double get momentumMultiplier => _momentumMultiplier;
  double get momentumProgress => _momentumProgress;
  bool get hasMomentumUpgrade => _isUpgradeActive(momentumId);

  double get totalIdleRate {
    double idleRate =
        autoClickRate * prestigeMultiplier * permanentIdleMultiplier;
    if (_overclockActive) {
      idleRate *= 2.0;
    }
    return idleRate;
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
    final baseProgress = (_clickStreak / 50.0).clamp(0.0, 1.0);
    final fullMomentumMultiplier =
        (1.0 + ((_clickStreak - 1) * 0.02)).clamp(1.0, 2.0);

    if (elapsedMs >= 1000) {
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

    final decayFactor = 1.0 - (elapsedMs / 1000.0);
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

  ({BigInt gain, bool probabilityStrikeTriggered}) click() {
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
      final comboBonus = (_clickStreak - 1) * 0.02;
      _momentumMultiplier = (1.0 + comboBonus).clamp(1.0, 2.0);
      _momentumProgress = (_clickStreak / 50.0).clamp(0.0, 1.0);
    } else {
      _momentumMultiplier = 1.0;
      _momentumProgress = 0.0;
    }

    if (_isUpgradeActive(overclockId) &&
        _clickStreak >= 50 &&
        !_overclockTriggeredThisChain) {
      _overclockTriggeredThisChain = true;
      _activateOverclock();
    }

    final bool probabilityStrikeTriggered =
        _isUpgradeActive(probabilityStrikeId) && _rng.nextDouble() < 0.05;

    final baseClickGain =
        clickPower.toDouble() * prestigeMultiplier * permanentClickMultiplier;
    final kineticBonus =
        _isUpgradeActive(kineticSynergyId) ? totalIdleRate * 0.01 : 0.0;

    double gain = (baseClickGain + kineticBonus) * _momentumMultiplier;
    if (probabilityStrikeTriggered) {
      gain *= 10.0;
    }

    final gained = BigInt.from(gain.floor());
    number += gained;
    notifyListeners();
    _saveState();
    return (
      gain: gained,
      probabilityStrikeTriggered: probabilityStrikeTriggered
    );
  }

  void _activateOverclock() {
    _overclockTimer?.cancel();
    _overclockActive = true;
    notifyListeners();

    _overclockTimer = Timer(const Duration(seconds: 30), () {
      _overclockActive = false;
      notifyListeners();
    });
  }

  void setBuyAmount(int amount) {
    buyAmount = amount;
    notifyListeners();
  }

  ({BigInt cost, int amount}) getPurchaseInfo(Upgrade upgrade) {
    int toBuy = buyAmount == -1 ? 999999 : buyAmount;
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

    while (bought < toBuy) {
      BigInt cost =
          BigInt.from(upgrade.baseCost.toDouble() * currentMultiplier);
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
            cost = BigInt.from(upgrade.baseCost.toDouble() * currentMultiplier);
            totalCost += cost;
            bought++;
            currentMultiplier *= upgrade.costMultiplier;
          }
          break;
        }
      }
    }

    int finalAmount = buyAmount == -1 ? bought : toBuy;
    if (buyAmount == -1 && finalAmount == 0) {
      // Even if max is 0, let's return the cost of 1 to show what they need next
      return (cost: upgrade.currentCost, amount: 0);
    }
    return (cost: totalCost, amount: finalAmount);
  }

  void buyUpgrade(String id) {
    final upgrade = upgrades.firstWhere((u) => u.id == id);
    if (upgrade.isMaxed) return;

    final info = getPurchaseInfo(upgrade);

    if (info.amount == 0) return;

    if (number >= info.cost) {
      number -= info.cost;
      upgrade.level += info.amount;

      if (upgrade.effectType == idleCategory) {
        autoClickRate += (upgrade.effectValue as double) * info.amount;
      } else if (upgrade.effectType == clickCategory &&
          upgrade.effectValue is BigInt) {
        clickPower +=
            (upgrade.effectValue as BigInt) * BigInt.from(info.amount);
      }

      notifyListeners();
      _saveState();
    }
  }

  void prestige() {
    final pointsToEarn = calculatePrestigePoints(number);
    if (pointsToEarn <= 0.0) return;
    prestigeCurrency += pointsToEarn;

    prestigeMultiplier += prestigeDeltaAtIndex(prestigeCount);
    prestigeCount += 1;

    number = BigInt.zero;
    clickPower = BigInt.from(50);
    autoClickRate = 0.0;
    _idleAccumulator = 0.0;
    _lastManualClickTime = null;
    _clickStreak = 0;
    _overclockTriggeredThisChain = false;
    _momentumMultiplier = 1.0;
    _momentumProgress = 0.0;
    _overclockActive = false;
    _overclockTimer?.cancel();

    for (var u in upgrades) {
      u.level = 0;
    }

    _startTicker();
    notifyListeners();
    _saveState();
  }

  /// Incremental shop upgrades; cost scales with rank. [amount] -1 = MAX affordable.
  void buyPermanentClickMultiplierAmount(int amount) {
    _buyPermanentMultiplierAmount(amount, forClick: true);
  }

  void buyPermanentIdleMultiplierAmount(int amount) {
    _buyPermanentMultiplierAmount(amount, forClick: false);
  }

  void _buyPermanentMultiplierAmount(int amount, {required bool forClick}) {
    if (amount == 0) return;

    int bought = 0;
    const safetyCap = 250000;

    while (true) {
      if (amount != -1 && bought >= amount) break;
      if (bought >= safetyCap) break;

      final rank = forClick ? permanentClickPurchases : permanentIdlePurchases;
      final stepCost = shopPrestigeCostAtRank(rank);
      if (prestigeCurrency < stepCost) break;

      prestigeCurrency -= stepCost;
      if (forClick) {
        permanentClickPurchases++;
      } else {
        permanentIdlePurchases++;
      }
      bought++;
    }

    if (bought > 0) {
      _startTicker();
      notifyListeners();
      _saveState();
    }
  }

  /// Calculates how many prestige points would be earned on prestige
  double get prestigePointsOnPrestige => nextPrestigeReward;

  Future<void> hardReset() async {
    number = BigInt.zero;
    clickPower = BigInt.from(50);
    autoClickRate = 0.0;
    _idleAccumulator = 0.0;
    _lastManualClickTime = null;
    _clickStreak = 0;
    _overclockTriggeredThisChain = false;
    _momentumMultiplier = 1.0;
    _momentumProgress = 0.0;
    _overclockActive = false;
    _overclockTimer?.cancel();
    offlineGainsThisSession = BigInt.zero;
    prestigeCurrency = 0.0;
    prestigeMultiplier = 1.0;
    prestigeCount = 0;
    permanentClickPurchases = 0;
    permanentIdlePurchases = 0;
    buyAmount = 1;

    for (var u in upgrades) {
      u.level = 0;
    }

    await _storageService.clearAllData();
    await _saveState();

    notifyListeners();
  }

  Future<void> _saveState() async {
    await _storageService.saveGame(
      number: number,
      clickPower: clickPower,
      autoClickRate: autoClickRate,
      prestigeCurrency: prestigeCurrency,
      prestigeMultiplier: prestigeMultiplier,
      prestigeCount: prestigeCount,
      permanentClickPurchases: permanentClickPurchases,
      permanentIdlePurchases: permanentIdlePurchases,
      upgradeLevels: {
        for (final upgrade in upgrades) upgrade.id: upgrade.level,
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _overclockTimer?.cancel();
    super.dispose();
  }
}
