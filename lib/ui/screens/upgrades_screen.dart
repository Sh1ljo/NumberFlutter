import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../models/upgrade.dart';
import '../../utils/number_formatter.dart';

class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key});

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  String _selectedCategory = GameState.clickCategory;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Icon(Icons.toll, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    NumberFormatter.format(gameState.number),
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                ],
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),

            // Title
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPGRADES',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 48),
                  ),
                ],
              ),
            ),

            // Upgrade Category Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: GameState.clickCategory,
                    label: Text('CLICK'),
                    icon: Icon(Icons.touch_app),
                  ),
                  ButtonSegment(
                    value: GameState.idleCategory,
                    label: Text('IDLE'),
                    icon: Icon(Icons.bolt),
                  ),
                ],
                selected: {_selectedCategory},
                showSelectedIcon: false,
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedCategory = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  selectedBackgroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Buy Amount Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1X')),
                  ButtonSegment(value: 10, label: Text('10X')),
                  ButtonSegment(value: 100, label: Text('100X')),
                  ButtonSegment(value: -1, label: Text('MAX')),
                ],
                selected: {gameState.buyAmount},
                showSelectedIcon: false,
                onSelectionChanged: (Set<int> newSelection) {
                  context.read<GameState>().setBuyAmount(newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  selectedBackgroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Builder(builder: (context) {
              final filteredUpgrades = gameState.upgrades
                  .where((upgrade) => upgrade.effectType == _selectedCategory)
                  .toList();

              return Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 10.0),
                  itemCount: filteredUpgrades.length,
                  itemBuilder: (context, index) {
                    final upgrade = filteredUpgrades[index];
                    final info = gameState.getPurchaseInfo(upgrade);
                    final canAfford =
                        info.amount > 0 && gameState.number >= info.cost;
                    return _UpgradeItem(
                        upgrade: upgrade, canAfford: canAfford, info: info);
                  },
                ),
              );
            }),

            // Padding for the bottom nav bar
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _UpgradeItem extends StatelessWidget {
  final Upgrade upgrade;
  final bool canAfford;
  final ({BigInt cost, int amount}) info;

  const _UpgradeItem({
    required this.upgrade,
    required this.canAfford,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMaxed = upgrade.isMaxed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      // "No-line rule" handled by surface transition
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.surfaceContainerLow, width: 2)),
      ),
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  upgrade.name,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(width: 8),
              if (isMaxed)
                OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                    side: BorderSide(color: theme.colorScheme.secondary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(
                    'PURCHASED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else if (canAfford)
                ElevatedButton(
                  onPressed: () {
                    context.read<GameState>().buyUpgrade(upgrade.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(
                    info.amount > 1 ? 'PURCHASE +${info.amount}' : 'PURCHASE',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                )
              else
                OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(
                    'INSUFFICIENT',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            upgrade.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LEVEL', style: theme.textTheme.labelSmall),
                  Text(upgrade.level.toString(),
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18, color: theme.colorScheme.secondary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('COST', style: theme.textTheme.labelSmall),
                  Text(NumberFormatter.format(info.cost),
                      style:
                          theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
