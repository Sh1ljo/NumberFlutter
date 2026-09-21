import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _keyNumber = 'number';
  static const String _keyClickPower = 'clickPower';
  static const String _keyAutoClickRate = 'autoClickRate';
  static const String _keyLastPlayed = 'lastPlayed';
  static const String _keyPrestigeCurrency = 'prestigeCurrency';
  static const String _keyGlobalMultiplier = 'globalMultiplier';
  static const String _keyPrestigeMultiplier = 'prestigeMultiplier';
  static const String _keyPrestigeCount = 'prestigeCount';
  static const String _keyUpgradeLevels = 'upgradeLevels';
  static const String _keyHighestNumber = 'highestNumber';
  static const String _keyNexusLevels = 'nexus_levels';
  static const String _keyTutorialCompleted = 'tutorialCompleted';
  static const String _keyTutorialStep = 'tutorialStep';
  static const String _keyNexusTutorialSeen = 'nexusTutorialSeen';
  static const String _keyNeuralTutorialSeen = 'neuralTutorialSeen';
  static const String _keyUpgradeTutorialSeen = 'upgradeTutorialSeen';
  static const String _keyArtifactTutorialSeen = 'artifactTutorialSeen';
  static const String _keyNexusStabilized = 'nexusStabilized';
  static const String _keyNeuralNetwork = 'neural_network';
  static const String _keyTestEnvironmentEnabled = 'testEnvironmentEnabled';
  static const String _keyLifetimeClicks = 'lifetime_clicks';
  static const String _keyAchievements = 'achievements_unlocked';
  static const String _keyArtifacts = 'artifacts';

  SharedPreferences? _prefs;

  /// Last value this service wrote per key. A save runs every 5s and after
  /// every tap burst, but most of its ~19 values rarely change, and each
  /// write is a platform call (a full file commit on Android). Unchanged
  /// values are skipped; the stored data is identical either way.
  final Map<String, Object> _lastWritten = {};

  Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> _setString(
      SharedPreferences prefs, String key, String value) async {
    if (_lastWritten[key] == value) return;
    // Remembered only once the write succeeded, so a failure is retried.
    if (await prefs.setString(key, value)) _lastWritten[key] = value;
  }

  Future<void> _setInt(
      SharedPreferences prefs, String key, int value) async {
    if (_lastWritten[key] == value) return;
    // Remembered only once the write succeeded, so a failure is retried.
    if (await prefs.setInt(key, value)) _lastWritten[key] = value;
  }

  Future<void> _setBool(
      SharedPreferences prefs, String key, bool value) async {
    if (_lastWritten[key] == value) return;
    // Remembered only once the write succeeded, so a failure is retried.
    if (await prefs.setBool(key, value)) _lastWritten[key] = value;
  }

  Future<void> saveGame({
    required BigInt number,
    required BigInt clickPower,
    required double autoClickRate,
    required double prestigeCurrency,
    required double prestigeMultiplier,
    required int prestigeCount,
    required Map<String, int> upgradeLevels,
    required BigInt highestNumber,
    required Map<String, int> nexusLevels,
    required bool tutorialCompleted,
    required String tutorialStep,
    required bool nexusTutorialSeen,
    required bool neuralTutorialSeen,
    required bool upgradeTutorialSeen,
    required bool artifactTutorialSeen,
    required bool nexusStabilized,
    String? neuralNetworkJson,
    bool testEnvironmentEnabled = false,
    int lifetimeClicks = 0,
    List<String> achievements = const [],
    String? artifactsJson,
  }) async {
    final prefs = await _instance();
    await _setString(prefs, _keyNumber, number.toString());
    await _setString(prefs, _keyClickPower, clickPower.toString());
    await _setString(prefs, _keyAutoClickRate, autoClickRate.toString());
    await _setString(
        prefs, _keyPrestigeCurrency, prestigeCurrency.toString());
    await _setString(
        prefs, _keyPrestigeMultiplier, prestigeMultiplier.toString());
    await _setInt(prefs, _keyPrestigeCount, prestigeCount);
    await _setString(prefs, _keyUpgradeLevels, jsonEncode(upgradeLevels));
    await _setString(prefs, _keyHighestNumber, highestNumber.toString());
    await _setString(prefs, _keyNexusLevels, jsonEncode(nexusLevels));
    await _setBool(prefs, _keyTutorialCompleted, tutorialCompleted);
    // Stored by NAME, never by index — an enum reorder would silently
    // reinterpret every saved step if this were an ordinal.
    await _setString(prefs, _keyTutorialStep, tutorialStep);
    await _setBool(prefs, _keyNexusTutorialSeen, nexusTutorialSeen);
    await _setBool(prefs, _keyNeuralTutorialSeen, neuralTutorialSeen);
    await _setBool(prefs, _keyUpgradeTutorialSeen, upgradeTutorialSeen);
    await _setBool(prefs, _keyArtifactTutorialSeen, artifactTutorialSeen);
    await _setBool(prefs, _keyNexusStabilized, nexusStabilized);
    await _setBool(
        prefs, _keyTestEnvironmentEnabled, testEnvironmentEnabled);
    if (neuralNetworkJson != null) {
      await _setString(prefs, _keyNeuralNetwork, neuralNetworkJson);
    }
    await _setInt(prefs, _keyLifetimeClicks, lifetimeClicks);
    await _setString(prefs, _keyAchievements, jsonEncode(achievements));
    if (artifactsJson != null) {
      await _setString(prefs, _keyArtifacts, artifactsJson);
    }
    await _setInt(
        prefs, _keyLastPlayed, DateTime.now().millisecondsSinceEpoch);
  }

  Future<Map<String, dynamic>> loadGame() async {
    final prefs = await _instance();

    final numberStr = prefs.getString(_keyNumber) ?? '0';
    final clickPowerStr = prefs.getString(_keyClickPower) ?? '1';
    final autoClickRateStr = prefs.getString(_keyAutoClickRate) ?? '0';
    final prestigeCurrencyStr = prefs.getString(_keyPrestigeCurrency) ?? '0';
    final highestNumberStr = prefs.getString(_keyHighestNumber) ?? numberStr;
    final lastPlayedMs = prefs.getInt(_keyLastPlayed);
    final prestigeMultStr = prefs.getString(_keyPrestigeMultiplier);
    final prestigeCountRaw = prefs.getInt(_keyPrestigeCount);

    BigInt? legacyGlobalMultiplier;
    if (prestigeMultStr == null) {
      final legacyGm = prefs.getString(_keyGlobalMultiplier) ?? '1';
      legacyGlobalMultiplier = BigInt.tryParse(legacyGm) ?? BigInt.one;
    }

    final upgradeLevelsRaw = prefs.getString(_keyUpgradeLevels);
    final Map<String, dynamic> decodedUpgradeLevels = upgradeLevelsRaw == null
        ? {}
        : (jsonDecode(upgradeLevelsRaw) as Map<String, dynamic>);
    final upgradeLevels = decodedUpgradeLevels.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    final nexusLevelsRaw = prefs.getString(_keyNexusLevels);
    final Map<String, dynamic> decodedNexusLevels = nexusLevelsRaw == null
        ? {}
        : (jsonDecode(nexusLevelsRaw) as Map<String, dynamic>);
    final nexusLevels = decodedNexusLevels.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    final achievementsRaw = prefs.getString(_keyAchievements);
    final achievements = achievementsRaw == null
        ? <String>[]
        : (jsonDecode(achievementsRaw) as List<dynamic>)
            .whereType<String>()
            .toList();

    final prestigeCurrencyDouble = double.tryParse(prestigeCurrencyStr);
    final prestigeCurrencyLegacy = BigInt.tryParse(prestigeCurrencyStr);

    return {
      'number': BigInt.tryParse(numberStr) ?? BigInt.zero,
      'clickPower': BigInt.tryParse(clickPowerStr) ?? BigInt.one,
      'autoClickRate': double.tryParse(autoClickRateStr) ?? 0.0,
      'prestigeCurrency':
          prestigeCurrencyDouble ?? (prestigeCurrencyLegacy?.toDouble() ?? 0.0),
      'prestigeMultiplier':
          prestigeMultStr != null ? double.tryParse(prestigeMultStr) : null,
      'prestigeCount': prestigeCountRaw,
      'legacyGlobalMultiplier': legacyGlobalMultiplier,
      'upgradeLevels': upgradeLevels,
      'highestNumber': BigInt.tryParse(highestNumberStr) ??
          BigInt.tryParse(numberStr) ??
          BigInt.zero,
      'nexusLevels': nexusLevels,
      'tutorialCompleted': prefs.getBool(_keyTutorialCompleted) ?? false,
      'tutorialStep': prefs.getString(_keyTutorialStep),
      'nexusTutorialSeen': prefs.getBool(_keyNexusTutorialSeen) ?? false,
      'neuralTutorialSeen': prefs.getBool(_keyNeuralTutorialSeen) ?? false,
      'upgradeTutorialSeen': prefs.getBool(_keyUpgradeTutorialSeen) ?? false,
      'artifactTutorialSeen': prefs.getBool(_keyArtifactTutorialSeen) ?? false,
      'nexusStabilized': prefs.getBool(_keyNexusStabilized) ?? false,
      'testEnvironmentEnabled': prefs.getBool(_keyTestEnvironmentEnabled) ?? false,
      'neuralNetwork': prefs.getString(_keyNeuralNetwork),
      'lifetimeClicks': prefs.getInt(_keyLifetimeClicks) ?? 0,
      'achievements': achievements,
      'artifacts': prefs.getString(_keyArtifacts),
      'lastPlayed': lastPlayedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastPlayedMs)
          : null,
    };
  }

  /// Every key the game save uses.
  static const List<String> _saveKeys = [
    _keyNumber,
    _keyClickPower,
    _keyAutoClickRate,
    _keyLastPlayed,
    _keyPrestigeCurrency,
    _keyGlobalMultiplier,
    _keyPrestigeMultiplier,
    _keyPrestigeCount,
    _keyUpgradeLevels,
    _keyHighestNumber,
    _keyNexusLevels,
    _keyTutorialCompleted,
    _keyTutorialStep,
    _keyNexusTutorialSeen,
    _keyNeuralTutorialSeen,
    _keyUpgradeTutorialSeen,
    _keyArtifactTutorialSeen,
    _keyNexusStabilized,
    _keyNeuralNetwork,
    _keyTestEnvironmentEnabled,
    _keyLifetimeClicks,
    _keyAchievements,
    _keyArtifacts,
  ];

  /// Copies the stored save, as-is, into one JSON blob under
  /// `corrupt_save_backup_<epoch ms>`, so an unreadable save can still be
  /// recovered by hand after the game starts fresh over it.
  Future<void> backupRawSave() async {
    final prefs = await _instance();
    final raw = <String, Object?>{
      for (final key in _saveKeys)
        if (prefs.get(key) != null) key: prefs.get(key),
    };
    if (raw.isEmpty) return;
    await prefs.setString(
      'corrupt_save_backup_${DateTime.now().millisecondsSinceEpoch}',
      jsonEncode(raw),
    );
  }

  Future<void> clearAllData() async {
    final prefs = await _instance();
    _lastWritten.clear();
    await prefs.remove(_keyNumber);
    await prefs.remove(_keyClickPower);
    await prefs.remove(_keyAutoClickRate);
    await prefs.remove(_keyLastPlayed);
    await prefs.remove(_keyPrestigeCurrency);
    await prefs.remove(_keyGlobalMultiplier);
    await prefs.remove(_keyPrestigeMultiplier);
    await prefs.remove(_keyPrestigeCount);
    await prefs.remove(_keyUpgradeLevels);
    await prefs.remove(_keyHighestNumber);
    await prefs.remove(_keyNexusLevels);
    await prefs.remove(_keyTutorialCompleted);
    await prefs.remove(_keyTutorialStep);
    await prefs.remove(_keyNexusTutorialSeen);
    await prefs.remove(_keyNeuralTutorialSeen);
    await prefs.remove(_keyUpgradeTutorialSeen);
    await prefs.remove(_keyArtifactTutorialSeen);
    await prefs.remove(_keyNexusStabilized);
    await prefs.remove(_keyNeuralNetwork);
    await prefs.remove(_keyLifetimeClicks);
    await prefs.remove(_keyAchievements);
    await prefs.remove(_keyArtifacts);
  }
}
