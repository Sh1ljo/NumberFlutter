import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../logic/game_state.dart';
import '../../logic/supabase_service.dart';
import '../../models/upgrade.dart';
import '../../utils/number_formatter.dart';
import '../widgets/profile_editor_dialog.dart';
import 'player_stats_screen.dart';

class UpgradesScreen extends StatefulWidget {
  final Map<String, GlobalKey>? upgradeRowKeys;
  final GlobalKey? idleCategoryKey;

  const UpgradesScreen({super.key, this.upgradeRowKeys, this.idleCategoryKey});

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  bool _profileActionBusy = false;
  final ScrollController _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _openStatsScreen() async {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PlayerStatsScreen()));
  }

  Future<void> _openLeaderboardScreen() async {
    // TODO: Implement leaderboard screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leaderboard coming soon!')),
    );
  }

  Future<void> _openProfileEditor() async {
    if (_profileActionBusy) return;
    final supabase = SupabaseService.instance;
    if (!supabase.isConfigured || !supabase.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Profile editing needs Supabase configured in assets/.env.'),
        ),
      );
      return;
    }

    setState(() {
      _profileActionBusy = true;
    });

    try {
      await ProfileEditorDialog.show(context);
    } finally {
      if (mounted) {
        setState(() {
          _profileActionBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only what shapes the list is selected here. The ticker notifies ~10x/s;
    // the number text and each row listen for their own slice below, so this
    // screen no longer rebuilds wholesale on every tick.
    final selectedCategory =
        context.select<GameState, String>((gs) => gs.selectedUpgradeCategory);
    final buyAmount = context.select<GameState, int>((gs) => gs.buyAmount);
    final prestigeCount =
        context.select<GameState, int>((gs) => gs.prestigeCount);
    final gameState = context.read<GameState>();
    final theme = Theme.of(context);
    // MainLayout folds the nav bar's height into this inset.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        // The list runs to the nav bar and pads its own tail instead.
        bottom: false,
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
                  Expanded(
                    child: Selector<GameState, BigInt>(
                      selector: (_, gs) => gs.number,
                      builder: (context, number, _) => Text(
                        NumberFormatter.format(number),
                        style:
                            theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Leaderboard',
                        onPressed: _openLeaderboardScreen,
                        icon: const Icon(Icons.emoji_events_outlined),
                      ),
                      IconButton(
                        tooltip: 'Profile',
                        onPressed: _openProfileEditor,
                        icon: const Icon(Icons.account_circle_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPGRADES',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 40),
                  ),
                ],
              ),
            ),

            // Upgrade Category Toggle
            Padding(
              key: widget.idleCategoryKey,
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
                selected: {selectedCategory},
                showSelectedIcon: false,
                onSelectionChanged: (Set<String> newSelection) {
                  context
                      .read<GameState>()
                      .setSelectedUpgradeCategory(newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  foregroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                  selectedForegroundColor: Colors.black,
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  selectedBackgroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  visualDensity:
                      const VisualDensity(horizontal: -2.0, vertical: -2.0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle:
                      theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
                ).copyWith(
                  iconColor: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return theme.colorScheme.primary.withValues(alpha: 0.7);
                  }),
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
                  ButtonSegment(value: -2, label: Text('NEXT')),
                  ButtonSegment(value: -1, label: Text('MAX')),
                ],
                selected: {buyAmount},
                showSelectedIcon: false,
                onSelectionChanged: (Set<int> newSelection) {
                  context.read<GameState>().setBuyAmount(newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  selectedBackgroundColor: theme.colorScheme.primary,
                  visualDensity:
                      const VisualDensity(horizontal: -2.0, vertical: -2.0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  textStyle:
                      theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 4),

            Builder(builder: (context) {
              final filteredUpgrades = gameState.upgrades
                  .where((upgrade) => upgrade.effectType == selectedCategory)
                  .where((upgrade) =>
                      prestigeCount >=
                      gameState.minPrestigeForUpgrade(upgrade.id))
                  .toList();

              return Expanded(
                child: RawScrollbar(
                  controller: _listController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 4,
                  radius: const Radius.circular(2),
                  thumbColor: theme.colorScheme.primary,
                  trackColor: theme.colorScheme.surfaceContainerLow,
                  trackBorderColor: Colors.transparent,
                  padding: EdgeInsets.fromLTRB(0, 6, 6, bottomInset + 6),
                  child: ListView.builder(
                    controller: _listController,
                    // Eagerly build all items so GlobalKeys are always valid
                    // even before the user scrolls (needed for tutorial highlights).
                    cacheExtent: 10000,
                    padding: EdgeInsets.fromLTRB(24, 6, 24, bottomInset + 8),
                    itemCount: filteredUpgrades.length,
                    itemBuilder: (context, index) {
                      final upgrade = filteredUpgrades[index];
                      final row = _UpgradeRow(upgrade: upgrade);
                      final gk = widget.upgradeRowKeys?[upgrade.id];
                      if (gk != null) {
                        return KeyedSubtree(key: gk, child: row);
                      }
                      return row;
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

double _calculateAffordabilityProgress(BigInt amount, BigInt target) {
  if (target <= BigInt.zero) return 1.0;
  if (amount <= BigInt.zero) return 0.0;
  if (amount >= target) return 1.0;

  final commonShift =
      math.max(0, math.max(amount.bitLength, target.bitLength) - 53);
  final scaledAmount = (amount >> commonShift).toDouble();
  final scaledTarget = (target >> commonShift).toDouble();
  if (scaledTarget <= 0) return 0.0;
  return (scaledAmount / scaledTarget).clamp(0.0, 1.0);
}

/// Everything a row renders apart from the affordability bar.
typedef _UpgradeRowData = ({
  int level,
  bool isMaxed,
  ({BigInt cost, int amount}) info,
  bool canAfford,
  int milestoneMultiplier,
});

/// One upgrade row, listening only to its own purchase info. Rows used to be
/// rebuilt (and their costs recomputed) wholesale on every ticker notify.
class _UpgradeRow extends StatelessWidget {
  final Upgrade upgrade;

  const _UpgradeRow({required this.upgrade});

  @override
  Widget build(BuildContext context) {
    final data = context.select<GameState, _UpgradeRowData>((gs) {
      final info = gs.getPurchaseInfo(upgrade);
      return (
        level: upgrade.level,
        isMaxed: upgrade.isMaxed,
        info: info,
        canAfford: info.amount > 0 && gs.number >= info.cost,
        milestoneMultiplier: gs.upgradeMilestoneMultiplier(upgrade),
      );
    });
    return _UpgradeItem(
      upgrade: upgrade,
      canAfford: data.canAfford,
      info: data.info,
      milestoneMultiplier: data.milestoneMultiplier,
    );
  }
}

class _UpgradeItem extends StatelessWidget {
  final Upgrade upgrade;
  final bool canAfford;
  final ({BigInt cost, int amount}) info;
  final int milestoneMultiplier;

  const _UpgradeItem({
    required this.upgrade,
    required this.canAfford,
    required this.info,
    required this.milestoneMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMaxed = upgrade.isMaxed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      // "No-line rule" handled by surface transition
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.surfaceContainerLow, width: 2)),
      ),
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  upgrade.name,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
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
          const SizedBox(height: 6),
          Text(
            upgrade.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LEVEL', style: theme.textTheme.labelSmall),
                  Row(
                    children: [
                      Text(
                        upgrade.level.toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      if (milestoneMultiplier > 1) ...[
                        const SizedBox(width: 6),
                        Text(
                          'x$milestoneMultiplier',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ],
                  ),
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
          ),
          if (!isMaxed && !canAfford) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              // The only part of a row that moves with every tick, so it
              // listens to the number on its own.
              child: Selector<GameState, double>(
                selector: (_, gs) =>
                    _calculateAffordabilityProgress(gs.number, info.cost),
                builder: (context, progress, _) => LinearProgressIndicator(
                  value: progress,
                  minHeight: 1.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
