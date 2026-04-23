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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNumber, number.toString());
    await prefs.setString(_keyClickPower, clickPower.toString());
    await prefs.setString(_keyAutoClickRate, autoClickRate.toString());
    await prefs.setString(_keyPrestigeCurrency, prestigeCurrency.toString());
    await prefs.setString(
        _keyPrestigeMultiplier, prestigeMultiplier.toString());
    await prefs.setInt(_keyPrestigeCount, prestigeCount);
    await prefs.setString(_keyUpgradeLevels, jsonEncode(upgradeLevels));
    await prefs.setString(_keyHighestNumber, highestNumber.toString());
    await prefs.setString(_keyNexusLevels, jsonEncode(nexusLevels));
    await prefs.setBool(_keyTutorialCompleted, tutorialCompleted);
    await prefs.setInt(_keyLastPlayed, DateTime.now().millisecondsSinceEpoch);
  }

  Future<Map<String, dynamic>> loadGame() async {
    final prefs = await SharedPreferences.getInstance();

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
      'lastPlayed': lastPlayedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastPlayedMs)
          : null,
    };
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
