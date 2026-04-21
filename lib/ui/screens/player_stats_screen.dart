import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../utils/number_formatter.dart';

class PlayerStatsScreen extends StatelessWidget {
  const PlayerStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameState = context.watch<GameState>();
    final allUpgrades = gameState.upgrades;
    final purchasedUpgrades =
        allUpgrades.where((upgrade) => upgrade.level > 0).length;
    final totalUpgradeLevels = allUpgrades.fold<int>(
      0,
      (sum, upgrade) => sum + upgrade.level,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Icon(Icons.toll, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      NumberFormatter.format(gameState.number),
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close stats',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  22,
                  24,
                  100 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  Text(
                    'PLAYER STATS',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 44),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Full runtime telemetry for your current profile.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StatsCard(
                    title: 'OVERVIEW',
                    children: [
                      _StatRow(
                        label: 'Current Number',
                        value: NumberFormatter.format(gameState.number),
                      ),
                      _StatRow(
                        label: 'Highest Number Reached',
                        value: NumberFormatter.format(gameState.highestNumber),
                      ),
                      _StatRow(
                        label: 'Offline Gains (This Session)',
                        value: NumberFormatter.format(
                            gameState.offlineGainsThisSession),
                      ),
                      _StatRow(
                        label: 'Total Prestiges',
                        value: gameState.prestigeCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StatsCard(
                    title: 'PRODUCTION',
                    children: [
                      _StatRow(
                        label: 'Click Power',
                        value: NumberFormatter.format(gameState.clickPower),
                      ),
                      _StatRow(
                        label: 'Auto-Click Rate (Base)',
                        value:
                            '${NumberFormatter.formatDouble(gameState.autoClickRate)} / sec',
                      ),
                      _StatRow(
                        label: 'Idle Output (Effective)',
                        value:
                            '${NumberFormatter.formatDouble(gameState.totalIdleRate)} / sec',
                      ),
                      _StatRow(
                        label: 'Momentum',
                        value: gameState.hasMomentumUpgrade
                            ? 'x${gameState.momentumMultiplier.toStringAsFixed(2)} (${(gameState.momentumProgress * 100).toStringAsFixed(0)}%)'
                            : 'Inactive',
                      ),
                      _StatRow(
                        label: 'Overclock',
                        value: gameState.isOverclockActive ? 'Active' : 'Idle',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StatsCard(
                    title: 'PRESTIGE',
                    children: [
                      _StatRow(
                        label: 'Prestige Multiplier',
                        value:
                            'x${gameState.prestigeMultiplier.toStringAsFixed(3)}',
                      ),
                      _StatRow(
                        label: 'Multiplier After Next Prestige',
                        value:
                            'x${gameState.prestigeMultiplierAfterNext.toStringAsFixed(3)}',
                      ),
                      _StatRow(
                        label: 'Prestige Currency',
                        value: NumberFormatter.formatDouble(
                          gameState.prestigeCurrency,
                        ),
                      ),
                      _StatRow(
                        label: 'Requirement For Next Prestige',
                        value: NumberFormatter.format(
                            gameState.prestigeRequirement),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StatsCard(
                    title: 'UPGRADES',
                    children: [
                      _StatRow(
                        label: 'Upgrades Purchased',
                        value:
                            '$purchasedUpgrades / ${allUpgrades.length} categories',
                      ),
                      _StatRow(
                        label: 'Total Upgrade Levels',
                        value: totalUpgradeLevels.toString(),
                      ),
                      const SizedBox(height: 8),
                      ...allUpgrades.map(
                        (upgrade) => _StatRow(
                          label: upgrade.name,
                          value: 'Lv ${upgrade.level}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatsCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.52),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.88),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2.2,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
