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
  static const String _keyPermanentClickMultiplier = 'permanentClickMultiplier';
  static const String _keyPermanentIdleMultiplier = 'permanentIdleMultiplier';
  static const String _keyPermanentClickPurchases = 'permanentClickPurchases';
  static const String _keyPermanentIdlePurchases = 'permanentIdlePurchases';
  static const String _keyUpgradeLevels = 'upgradeLevels';
  static const String _keyHighestNumber = 'highestNumber';

  Future<void> saveGame({
    required BigInt number,
    required BigInt clickPower,
    required double autoClickRate,
    required double prestigeCurrency,
    required double prestigeMultiplier,
    required int prestigeCount,
    required int permanentClickPurchases,
    required int permanentIdlePurchases,
    required Map<String, int> upgradeLevels,
    required BigInt highestNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNumber, number.toString());
    await prefs.setString(_keyClickPower, clickPower.toString());
    await prefs.setString(_keyAutoClickRate, autoClickRate.toString());
    await prefs.setString(_keyPrestigeCurrency, prestigeCurrency.toString());
    await prefs.setString(
        _keyPrestigeMultiplier, prestigeMultiplier.toString());
    await prefs.setInt(_keyPrestigeCount, prestigeCount);
    await prefs.setInt(_keyPermanentClickPurchases, permanentClickPurchases);
    await prefs.setInt(_keyPermanentIdlePurchases, permanentIdlePurchases);
    await prefs.setString(_keyUpgradeLevels, jsonEncode(upgradeLevels));
    await prefs.setString(_keyHighestNumber, highestNumber.toString());
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

    final pClick = prefs.getInt(_keyPermanentClickPurchases);
    final pIdle = prefs.getInt(_keyPermanentIdlePurchases);
    final upgradeLevelsRaw = prefs.getString(_keyUpgradeLevels);
    final Map<String, dynamic> decodedUpgradeLevels = upgradeLevelsRaw == null
        ? {}
        : (jsonDecode(upgradeLevelsRaw) as Map<String, dynamic>);
    final upgradeLevels = decodedUpgradeLevels.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    BigInt? legacyPermanentClick;
    BigInt? legacyPermanentIdle;
    if (pClick == null) {
      final s = prefs.getString(_keyPermanentClickMultiplier) ?? '1';
      legacyPermanentClick = BigInt.tryParse(s) ?? BigInt.one;
    }
    if (pIdle == null) {
      final s = prefs.getString(_keyPermanentIdleMultiplier) ?? '1';
      legacyPermanentIdle = BigInt.tryParse(s) ?? BigInt.one;
    }

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
      'permanentClickPurchases': pClick,
      'permanentIdlePurchases': pIdle,
      'legacyPermanentClick': legacyPermanentClick,
      'legacyPermanentIdle': legacyPermanentIdle,
      'upgradeLevels': upgradeLevels,
      'highestNumber':
          BigInt.tryParse(highestNumberStr) ?? BigInt.tryParse(numberStr) ?? BigInt.zero,
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
