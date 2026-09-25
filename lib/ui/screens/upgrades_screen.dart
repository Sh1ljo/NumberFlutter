import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../logic/game_state.dart';
import '../../logic/backend_service.dart';
import '../../models/upgrade.dart';
import '../../models/upgrade_recommendation.dart';
import '../../utils/number_formatter.dart';
import '../widgets/profile_editor_dialog.dart';
import '../widgets/one_shot_highlight.dart';
import 'leaderboard_screen.dart';
import '../widgets/rolling_number_text.dart';
import 'player_stats_screen.dart';

class UpgradesScreen extends StatefulWidget {
  final Map<String, GlobalKey>? upgradeRowKeys;
  final GlobalKey? idleCategoryKey;

  /// Spotlight target for the advisor tip.
  final GlobalKey? advisorBannerKey;
  final Set<String> highlightedUpgradeIds;

  const UpgradesScreen({
    super.key,
    this.upgradeRowKeys,
    this.idleCategoryKey,
    this.advisorBannerKey,
    this.highlightedUpgradeIds = const {},
  });

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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()),
    );
  }

  Future<void> _openProfileEditor() async {
    if (_profileActionBusy) return;
    final backend = BackendService.instance;
    if (!backend.isConfigured || !backend.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Profile editing needs a connection to the cloud.'),
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
                      builder: (context, number, _) => RollingNumberText(
                        value: number,
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

            KeyedSubtree(
              key: widget.advisorBannerKey,
              child: const _RecommendationCard(),
            ),

            Builder(builder: (context) {
              final filteredUpgrades = gameState.upgrades
                  .where((upgrade) => upgrade.effectType == selectedCategory)
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
                      final row = _UpgradeRow(
                        upgrade: upgrade,
                        highlighted: widget.highlightedUpgradeIds
                            .contains(upgrade.id),
                      );
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
  final raw = (scaledAmount / scaledTarget).clamp(0.0, 1.0);
  // Quantize progress to 100 steps (0.01 resolution) to prevent micro-increment rebuilds
  return (raw * 100).floor() / 100.0;
}

/// Everything a row renders apart from the affordability bar.
typedef _UpgradeRowData = ({
  int level,
  bool isMaxed,
  ({BigInt cost, int amount}) info,
  bool canAfford,
  bool recommended,
  int milestoneMultiplier,
  int minPrestige,
  bool isLockedByPrestige,
});

/// One upgrade row, listening only to its own purchase info. Rows used to be
/// rebuilt (and their costs recomputed) wholesale on every ticker notify.
class _UpgradeRow extends StatelessWidget {
  final Upgrade upgrade;
  final bool highlighted;

  const _UpgradeRow({required this.upgrade, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final data = context.select<GameState, _UpgradeRowData>((gs) {
      final minPrestige = gs.minPrestigeForUpgrade(upgrade.id);
      final isLocked = gs.prestigeCount < minPrestige;
      final info = isLocked ? (cost: BigInt.zero, amount: 0) : gs.getPurchaseInfo(upgrade);
      return (
        level: upgrade.level,
        isMaxed: upgrade.isMaxed,
        info: info,
        canAfford: !isLocked && info.amount > 0 && gs.number >= info.cost,
        recommended: !isLocked && gs.recommendedUpgrade?.upgradeId == upgrade.id,
        milestoneMultiplier: gs.upgradeMilestoneMultiplier(upgrade),
        minPrestige: minPrestige,
        isLockedByPrestige: isLocked,
      );
    });
    return _UpgradeItem(
      upgrade: upgrade,
      highlighted: highlighted,
      canAfford: data.canAfford,
      recommended: data.recommended,
      info: data.info,
      milestoneMultiplier: data.milestoneMultiplier,
      minPrestige: data.minPrestige,
      isLockedByPrestige: data.isLockedByPrestige,
    );
  }
}

/// Formats an [UpgradeGainPreview] as the row's gain line, e.g.
/// "+1.25K per tap" or "+340 per sec (avg)".
({String? gain, String? detail}) _describeGain(
    UpgradeGainPreview preview, int levels) {
  final parts = <String>[
    if (preview.perClick > 0)
      '+${NumberFormatter.formatGain(preview.perClick)} per tap',
    if (preview.perSecond > 0)
      '+${NumberFormatter.formatGain(preview.perSecond)} per sec',
  ];
  String? gain;
  if (parts.isNotEmpty) {
    gain = parts.join(' · ');
    if (preview.qualifier != null) gain += ' (${preview.qualifier})';
    if (levels > 1) gain += '  for $levels levels';
  }
  return (gain: gain, detail: preview.detail);
}

/// The row's "what you actually get" line: the real gain after every
/// multiplier, for however many levels the PURCHASE button would buy.
class _UpgradeGainLine extends StatelessWidget {
  final Upgrade upgrade;
  final int levels;

  const _UpgradeGainLine({required this.upgrade, required this.levels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selecting the formatted strings, not the raw doubles, so the line
    // only rebuilds when what it shows actually changes.
    final text = context.select<GameState, ({String? gain, String? detail})>(
      (gs) => _describeGain(gs.upgradeGainPreview(upgrade, levels), levels),
    );
    if (text.gain == null && text.detail == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.gain != null)
            Row(
              children: [
                Icon(Icons.trending_up,
                    size: 14, color: theme.colorScheme.secondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text.gain!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          if (text.detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text.detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpgradeItem extends StatelessWidget {
  final Upgrade upgrade;
  final bool highlighted;
  final bool canAfford;
  final bool recommended;
  final ({BigInt cost, int amount}) info;
  final int milestoneMultiplier;
  final int minPrestige;
  final bool isLockedByPrestige;

  const _UpgradeItem({
    required this.upgrade,
    required this.highlighted,
    required this.canAfford,
    required this.recommended,
    required this.info,
    required this.milestoneMultiplier,
    required this.minPrestige,
    required this.isLockedByPrestige,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMaxed = upgrade.isMaxed;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    if (isLockedByPrestige) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 20, color: mutedColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upgrade.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlocks at Prestige $minPrestige',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: mutedColor.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                'LOCKED',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: mutedColor,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return OneShotHighlight(
      highlight: highlighted,
      child: Container(
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
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      upgrade.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    if (recommended) const _BestBadge(),
                  ],
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
          if (!isMaxed)
            _UpgradeGainLine(
              upgrade: upgrade,
              levels: info.amount > 0 ? info.amount : 1,
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
      ),
    );
  }
}

class _BestBadge extends StatelessWidget {
  const _BestBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        border: Border.all(color: theme.colorScheme.primary),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 11, color: theme.colorScheme.primary),
          const SizedBox(width: 3),
          Text(
            'BEST BUY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// The advisor's pick above the list, on one line: which upgrade, how many
/// levels, and a button to buy exactly that amount (or the wait until it is
/// affordable). Tapping the label switches to the upgrade's tab.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard();

  @override
  Widget build(BuildContext context) {
    final rec = context
        .select<GameState, UpgradeRecommendation?>((gs) => gs.recommendedUpgrade);
    if (rec == null) return const SizedBox(height: 4);

    final theme = Theme.of(context);
    final gs = context.read<GameState>();
    final upgrade = gs.upgrades.firstWhere((u) => u.id == rec.upgradeId);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => gs.setSelectedUpgradeCategory(rec.category),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: upgrade.name),
                      TextSpan(
                        text: '  ×${rec.amount}',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ]),
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Selector<GameState, bool>(
                  selector: (_, gs) => gs.number >= rec.cost,
                  builder: (context, affordable, _) => affordable
                      ? ElevatedButton(
                          onPressed: () =>
                              gs.buyUpgradeLevels(rec.upgradeId, rec.amount),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                          child: Text(
                            'BUY ${NumberFormatter.format(rec.cost)}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.onPrimary),
                          ),
                        )
                      : Text(
                          '${NumberFormatter.format(rec.cost)} · ~${NumberFormatter.formatDuration(rec.secondsToAfford)}',
                          style:
                              theme.textTheme.labelSmall?.copyWith(color: muted),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
