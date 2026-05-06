import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';

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
                'Boost your progression with special offers.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.outline,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),

              // Permanent Upgrades Section
              Text(
                'PERMANENT UPGRADES',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2.0,
                  color: cs.outline,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 12),
              _ShopItem(
                name: '2x Cash Boost Forever',
                description: 'Double all cash gains permanently',
                price: '\$4.99',
                icon: Icons.attach_money,
                theme: theme,
                isPermanent: true,
              ),
              const SizedBox(height: 12),
              _ShopItem(
                name: 'Double Idle Rate Forever',
                description: '2x idle generation rate permanently',
                price: '\$4.99',
                icon: Icons.bolt,
                theme: theme,
                isPermanent: true,
              ),
              const SizedBox(height: 12),
              _ShopItem(
                name: 'Ad-Free Experience',
                description: 'Remove all advertisements forever',
                price: '\$4.99',
                icon: Icons.remove_circle_outline,
                theme: theme,
                isPermanent: true,
              ),
              const SizedBox(height: 12),
              _ShopItem(
                name: 'Prestige Doubler',
                description: 'Double your prestige multiplier growth',
                price: '\$3.99',
                icon: Icons.star,
                theme: theme,
                isPermanent: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopItem extends StatelessWidget {
  final String name;
  final String description;
  final String price;
  final IconData icon;
  final ThemeData theme;
  final bool isFeatured;
  final bool isPermanent;

  const _ShopItem({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    required this.theme,
    this.isFeatured = false,
    this.isPermanent = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isFeatured
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerLow.withValues(alpha: 0.55),
        border: Border.all(
          color: isFeatured
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
                color: isFeatured ? cs.primary : cs.outlineVariant,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isFeatured ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
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
                price,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isFeatured ? cs.primary : cs.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (isPermanent)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Forever',
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
    );
  }
}
