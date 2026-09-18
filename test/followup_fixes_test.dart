import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/utils/number_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NumberFormatter.formatDouble', () {
    test('exact powers of 1000 get the right suffix and do not throw', () {
      expect(NumberFormatter.formatDouble(1000), '1.000K');
      expect(NumberFormatter.formatDouble(1e6), '1.000M');
      expect(NumberFormatter.formatDouble(1e9), '1.000B');
      expect(NumberFormatter.formatDouble(1e15), '1.000Qa');
      expect(NumberFormatter.formatDouble(1e18), '1.000Qi');
    });

    test('everything else formats as before', () {
      expect(NumberFormatter.formatDouble(0), '0.000');
      expect(NumberFormatter.formatDouble(999.5), '999.500');
      expect(NumberFormatter.formatDouble(1500), '1.500K');
      expect(NumberFormatter.formatDouble(999999), '999.999K');
      expect(NumberFormatter.formatDouble(2.5e7), '25.000M');
    });
  });

  group('minimise and resume', () {
    late GameState gameState;
    late DateTime now;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gameState = GameState();
      await gameState.ready;
      now = DateTime(2026, 1, 1, 12);
      gameState.clock = () => now;
      // One auto-clicker level gives a small, known idle rate.
      gameState.number = BigInt.from(1000);
      gameState.setSelectedUpgradeCategory(GameState.idleCategory);
      gameState.buyUpgrade(GameState.autoClickerId);
      expect(gameState.totalIdleRate, greaterThan(0));
    });

    tearDown(() => gameState.dispose());

    BigInt expectedGain(int seconds) => BigInt.from(
        (gameState.totalIdleRate * seconds * gameState.offlineGainMultiplier)
            .floor());

    test('time away is credited as offline progress, with the dialog', () {
      gameState.didChangeAppLifecycleState(AppLifecycleState.paused);
      final before = gameState.number;
      now = now.add(const Duration(minutes: 10));
      gameState.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(gameState.number - before, expectedGain(600));
      expect(gameState.offlineGainsThisSession, expectedGain(600));
    });

    test('a short absence is credited silently', () {
      gameState.didChangeAppLifecycleState(AppLifecycleState.paused);
      final before = gameState.number;
      now = now.add(const Duration(seconds: 30));
      gameState.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(gameState.number - before, expectedGain(30));
      expect(gameState.offlineGainsThisSession, BigInt.zero);
    });

    test('a resume without a pause credits nothing', () {
      final before = gameState.number;
      now = now.add(const Duration(minutes: 10));
      gameState.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(gameState.number, before);
    });
  });

  group('unreadable save', () {
    test('is backed up and replaced by a clean, fresh game', () async {
      SharedPreferences.setMockInitialValues({
        'number': '123456',
        'prestigeCount': 4,
        'prestigeMultiplier': '1.9',
        'upgradeLevels': '{not json',
      });
      final gameState = GameState();
      await gameState.ready;
      addTearDown(gameState.dispose);

      expect(gameState.number, BigInt.zero);
      expect(gameState.prestigeCount, 0);
      expect(gameState.prestigeCurrency, 0.0);
      expect(gameState.clickPower, BigInt.one);

      final prefs = await SharedPreferences.getInstance();
      final backupKeys =
          prefs.getKeys().where((k) => k.startsWith('corrupt_save_backup_'));
      expect(backupKeys, hasLength(1));
      final backup =
          jsonDecode(prefs.getString(backupKeys.single)!) as Map<String, dynamic>;
      expect(backup['number'], '123456');
      expect(backup['upgradeLevels'], '{not json');
    });
  });
}
