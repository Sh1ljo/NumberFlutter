import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/data/shop_catalog.dart';
import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/shop_inventory.dart';
import 'package:number_flutter/logic/storage_service.dart';

Future<GameState> _game() async {
  SharedPreferences.setMockInitialValues({});
  final gs = GameState();
  await gs.ready;
  return gs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shop inventory effects', () {
    test('permanent click and idle multipliers stack additively', () async {
      final gs = await _game();
      expect(gs.shopClickMultiplier, 1.0);
      expect(gs.shopIdleMultiplier, 1.0);

      expect(
        gs.debugGrantShopProduct(ShopCatalog.clickPrimer),
        ShopPurchaseResult.success,
      );
      expect(gs.shopClickMultiplier, closeTo(1.03, 1e-9));

      expect(
        gs.debugGrantShopProduct(ShopCatalog.kineticAmplifier),
        ShopPurchaseResult.success,
      );
      expect(gs.shopClickMultiplier, closeTo(1.15, 1e-9));

      expect(
        gs.debugGrantShopProduct(ShopCatalog.idlePrimer),
        ShopPurchaseResult.success,
      );
      expect(
        gs.debugGrantShopProduct(ShopCatalog.idleAmplifier),
        ShopPurchaseResult.success,
      );
      expect(gs.shopIdleMultiplier, closeTo(1.18, 1e-9));

      expect(
        gs.debugGrantShopProduct(ShopCatalog.clickPrimer),
        ShopPurchaseResult.alreadyOwned,
      );
    });

    test('chrono products raise offline cap and gains', () async {
      final gs = await _game();
      final baseCap = gs.offlineCapHours;
      final baseGain = gs.offlineGainMultiplier;

      gs.debugGrantShopProduct(ShopCatalog.chronoChip);
      expect(gs.offlineCapHours, closeTo(baseCap + 2.0, 1e-9));

      gs.debugGrantShopProduct(ShopCatalog.chronoLensPro);
      expect(gs.offlineCapHours, closeTo(baseCap + 8.0, 1e-9));
      expect(gs.offlineGainMultiplier, closeTo(baseGain * 1.15, 1e-9));
    });

    test('prestige dividend multiplies PP earned', () async {
      final gs = await _game();
      final before = gs.prestigePointsMultiplier;
      gs.debugGrantShopProduct(ShopCatalog.prestigeDividend);
      expect(gs.prestigePointsMultiplier, closeTo(before * 1.15, 1e-9));
    });

    test('surge protocol adds 200 bps carry', () async {
      final gs = await _game();
      final before = gs.surgeProtocolNetWorthCarryBps;
      gs.debugGrantShopProduct(ShopCatalog.surgeProtocol);
      expect(gs.surgeProtocolNetWorthCarryBps, before + 200);
    });

    test('neural patron discounts neural branch cost by 10%', () async {
      final gs = await _game();
      final undisc = gs.neuralBranchCost;
      expect(undisc > BigInt.zero, isTrue);
      gs.debugGrantShopProduct(ShopCatalog.neuralPatron);
      final disc = gs.neuralBranchCost;
      expect(disc < undisc, isTrue);
      expect(disc.toDouble() / undisc.toDouble(), closeTo(0.9, 0.02));
    });

    test('collapse efficiency shortens cooldown', () async {
      final gs = await _game();
      gs.upgrades
          .firstWhere((u) => u.id == GameState.temporalCollapseId)
          .level = 1;
      final before = gs.temporalCollapseCooldownSeconds;
      gs.debugGrantShopProduct(ShopCatalog.collapseEfficiency);
      expect(gs.temporalCollapseCooldownSeconds, (before * 0.8).round());
    });

    test('spark surge multiplies idle', () async {
      final gs = await _game();
      gs.upgrades.firstWhere((u) => u.id == GameState.autoClickerId).level = 5;
      gs.debugRecalculateDerivedStats();
      final base = gs.totalIdleRate;
      expect(base, greaterThan(0));

      expect(
        gs.debugGrantShopProduct(ShopCatalog.sparkSurge),
        ShopPurchaseResult.success,
      );
      expect(gs.isShopSparkSurgeActive, isTrue);
      expect(gs.totalIdleRate, closeTo(base * 1.5, base * 1e-6));
      expect(gs.shopInventory.sparkSurgeExpiresAt, isNotNull);
    });

    test('quick resume claims one hour of idle', () async {
      final gs = await _game();
      gs.upgrades.firstWhere((u) => u.id == GameState.autoClickerId).level = 10;
      gs.debugRecalculateDerivedStats();
      final idle = gs.totalIdleRate;
      final before = gs.number;
      expect(
        gs.debugGrantShopProduct(ShopCatalog.quickResume),
        ShopPurchaseResult.success,
      );
      expect(gs.number - before, BigInt.from((idle * 3600).floor()));
    });

    test('collapse ready only while cooling down with upgrade', () async {
      final gs = await _game();
      expect(
        gs.debugGrantShopProduct(ShopCatalog.collapseReady),
        ShopPurchaseResult.notAvailable,
      );

      gs.upgrades
          .firstWhere((u) => u.id == GameState.temporalCollapseId)
          .level = 1;
      gs.debugSetTemporalCollapseCoolingDown(true);
      expect(
        gs.debugGrantShopProduct(ShopCatalog.collapseReady),
        ShopPurchaseResult.success,
      );
      expect(gs.isTemporalCollapseCoolingDown, isFalse);
    });

    test('shop state persists across reload', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.ready;
      gs.debugGrantShopProduct(ShopCatalog.idleAmplifier);
      gs.debugGrantShopProduct(ShopCatalog.chronoChip);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final storage = StorageService();
      final loaded = await storage.loadGame();
      expect(loaded['shop'], isNotNull);

      final gs2 = GameState();
      await gs2.ready;
      expect(gs2.ownsShopProduct(ShopCatalog.idleAmplifier), isTrue);
      expect(gs2.ownsShopProduct(ShopCatalog.chronoChip), isTrue);
      expect(gs2.shopIdleMultiplier, closeTo(1.15, 1e-9));
      expect(
        gs2.offlineCapHours,
        closeTo(GameState.baseOfflineCapHours + 2, 1e-9),
      );
    });

    test('hard reset clears shop ownership', () async {
      final gs = await _game();
      gs.debugGrantShopProduct(ShopCatalog.kineticAmplifier);
      await gs.hardReset();
      expect(gs.ownsShopProduct(ShopCatalog.kineticAmplifier), isFalse);
      expect(gs.shopClickMultiplier, 1.0);
    });
  });
}
