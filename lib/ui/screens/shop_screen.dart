import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/shop_catalog.dart';
import '../../logic/game_state.dart';
import '../../logic/shop_inventory.dart';
import '../../models/shop_product.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            32,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SHOP',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 48),
              ),
              const SizedBox(height: 12),
              Text(
                'Affordable boosts and permanent upgrades. '
                'Purchases apply instantly (billing comes later).',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.outline,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),
              _SectionHeader(
                title: 'QUICK BOOSTS',
                subtitle: '€0.20 – €0.50 · temporary help',
                theme: theme,
              ),
              const SizedBox(height: 12),
              for (final product in ShopCatalog.quickBoosts) ...[
                _ShopProductTile(product: product, theme: theme),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'STARTER PERMANENTS',
                subtitle: '€0.50 – €1.00 · simple, mild forever bonuses',
                theme: theme,
              ),
              const SizedBox(height: 12),
              for (final product in ShopCatalog.starterPermanents) ...[
                _ShopProductTile(product: product, theme: theme),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'CORE PERMANENTS',
                subtitle: '€1 – €5 · stronger forever upgrades',
                theme: theme,
              ),
              const SizedBox(height: 12),
              for (final product in ShopCatalog.corePermanents) ...[
                _ShopProductTile(
                  product: product,
                  theme: theme,
                  isFeatured: product.id == ShopCatalog.kineticAmplifier ||
                      product.id == ShopCatalog.idleAmplifier,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final ThemeData theme;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 2.0,
            color: cs.outline,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.outline.withValues(alpha: 0.75),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _ShopProductTile extends StatelessWidget {
  final ShopProduct product;
  final ThemeData theme;
  final bool isFeatured;

  const _ShopProductTile({
    required this.product,
    required this.theme,
    this.isFeatured = false,
  });

  IconData get _icon {
    switch (product.effect) {
      case ShopEffect.sparkSurge:
        return Icons.flash_on;
      case ShopEffect.overclockCharge:
        return Icons.speed;
      case ShopEffect.collapseReady:
        return Icons.restart_alt;
      case ShopEffect.quickResume:
        return Icons.hourglass_bottom;
      case ShopEffect.clickPrimer:
        return Icons.touch_app;
      case ShopEffect.idlePrimer:
        return Icons.trending_up;
      case ShopEffect.chronoChip:
        return Icons.schedule;
      case ShopEffect.sparkMagnet:
        return Icons.auto_awesome;
      case ShopEffect.kineticAmplifier:
        return Icons.pan_tool_alt;
      case ShopEffect.idleAmplifier:
        return Icons.bolt;
      case ShopEffect.chronoLensPro:
        return Icons.timelapse;
      case ShopEffect.collapseEfficiency:
        return Icons.timer_off;
      case ShopEffect.surgeProtocol:
        return Icons.swap_vert;
      case ShopEffect.neuralPatron:
        return Icons.hub;
      case ShopEffect.prestigeDividend:
        return Icons.star;
    }
  }

  String _statusLabel(GameState gs) {
    if (product.isPermanent && gs.ownsShopProduct(product.id)) {
      return 'Owned';
    }
    if (product.effect == ShopEffect.sparkSurge && gs.isShopSparkSurgeActive) {
      final left = gs.shopSparkSurgeRemaining();
      if (left != null) {
        final mins = left.inMinutes;
        final secs = left.inSeconds % 60;
        return 'Active ${mins}:${secs.toString().padLeft(2, '0')}';
      }
      return 'Active';
    }
    return product.isPermanent ? 'Forever' : 'Timed';
  }

  String _feedbackMessage(ShopPurchaseResult result) {
    switch (result) {
      case ShopPurchaseResult.success:
        return product.isPermanent
            ? '${product.name} unlocked'
            : '${product.name} applied';
      case ShopPurchaseResult.alreadyOwned:
        return 'Already owned';
      case ShopPurchaseResult.notAvailable:
        return 'Collapse is not on cooldown';
      case ShopPurchaseResult.noIdleToClaim:
        return 'Need idle income first';
      case ShopPurchaseResult.unknownProduct:
        return 'Unknown product';
    }
  }

  Future<void> _onBuy(BuildContext context) async {
    final gs = context.read<GameState>();
    final result = await gs.purchaseShopProduct(product.id);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_feedbackMessage(result)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final owned = context.select<GameState, bool>(
      (gs) => product.isPermanent && gs.ownsShopProduct(product.id),
    );
    final availability = context.select<GameState, ShopPurchaseResult>(
      (gs) => gs.shopPurchaseAvailability(product.id),
    );
    final status = context.select<GameState, String>(_statusLabel);
    final canBuy = availability == ShopPurchaseResult.success;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canBuy ? () => _onBuy(context) : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isFeatured
                ? cs.primary.withValues(alpha: 0.08)
                : cs.surfaceContainerLow.withValues(alpha: 0.55),
            border: Border.all(
              color: owned
                  ? cs.primary.withValues(alpha: 0.45)
                  : isFeatured
                      ? cs.primary.withValues(alpha: 0.65)
                      : cs.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isFeatured || owned ? cs.primary : cs.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Icon(
                  _icon,
                  size: 22,
                  color: isFeatured || owned ? cs.primary : cs.onSurface,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    owned ? 'OWNED' : product.priceLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: owned || isFeatured ? cs.primary : cs.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                        fontSize: 8,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
