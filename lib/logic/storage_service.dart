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
  static const String _keyHapticPulseEnabled = 'hapticPulseEnabled';
  static const String _keyVibrationIntensity = 'vibrationIntensity';

  Future<void> saveGame({
    required BigInt number,
    required BigInt clickPower,
    required double autoClickRate,
    required double prestigeCurrency,
    required double prestigeMultiplier,
    required int prestigeCount,
    required Map<String, int> upgradeLevels,
    required BigInt highestNumber,
    required bool hapticPulseEnabled,
    required double vibrationIntensity,
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
    await prefs.setBool(_keyHapticPulseEnabled, hapticPulseEnabled);
    await prefs.setDouble(
      _keyVibrationIntensity,
      vibrationIntensity.clamp(0.0, 1.0),
    );
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
    final hapticPulseEnabled = prefs.getBool(_keyHapticPulseEnabled);
    final vibrationIntensity = prefs.getDouble(_keyVibrationIntensity);

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
      'hapticPulseEnabled': hapticPulseEnabled,
      'vibrationIntensity': vibrationIntensity,
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
