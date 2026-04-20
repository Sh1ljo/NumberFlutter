import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import '../../../utils/number_formatter.dart';
import 'prestige_constants.dart';
import 'widgets/prestige_gain_card.dart';
import 'widgets/prestige_overlay.dart';
import 'widgets/prestige_shop_popup.dart';
import 'widgets/prestige_stat_block.dart';

class PrestigeScreen extends StatefulWidget {
  const PrestigeScreen({super.key});

  @override
  State<PrestigeScreen> createState() => _PrestigeScreenState();
}

class _PrestigeScreenState extends State<PrestigeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAnimating = false;
  bool _prestigeCalled = false;
  double _pendingPrestigePoints = 0.0;

  // Prestige shop quantity selection: 1, 10, 100, -1 (MAX)
  int _shopBuyAmount = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );

    // Trigger prestige() exactly once when the flash peaks
    _controller.addListener(() {
      if (!_prestigeCalled &&
          _controller.value >= kPrestigeFirePoint &&
          mounted) {
        _prestigeCalled = true;
        context.read<GameState>().prestige();
      }
    });

    // Full cleanup when the reveal fade-out finishes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.read<GameState>().setPrestigeAnimating(false);
        setState(() {
          _isAnimating = false;
          _pendingPrestigePoints = 0.0;
        });
        _prestigeCalled = false;
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initiatePrestige() {
    if (_isAnimating) return;
    final pts = context.read<GameState>().prestigePointsOnPrestige;
    setState(() {
      _isAnimating = true;
      _pendingPrestigePoints = pts;
    });
    context.read<GameState>().setPrestigeAnimating(true);
    _controller.forward();
  }

  Future<void> _confirmAndPrestige() async {
    final theme = Theme.of(context);
    final gameState = context.read<GameState>();
    final pointsToEarn = gameState.prestigePointsOnPrestige;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'INITIATE PRESTIGE?',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(letterSpacing: 2.0),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Numbers, Upgrades, and idle generators will reset. '
                  'You earn prestige points and a small prestige multiplier '
                  'bonus that grows with each reset.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                PrestigeGainCard(
                  pointsToEarn: pointsToEarn,
                  prestigeRequirement: gameState.prestigeRequirement,
                  multiplierAfter: gameState.prestigeMultiplierAfterNext,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: theme.colorScheme.outlineVariant),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'CANCEL',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 2.0,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'CONFIRM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 2.0,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) _initiatePrestige();
  }

  /// Shows the prestige shop as a modal popup
  Future<void> _showPrestigeShop() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => PrestigeShopPopup(
        initialShopBuyAmount: _shopBuyAmount,
        onShopBuyAmountChanged: (amount) {
          setState(() => _shopBuyAmount = amount);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);
    final requirement = gameState.prestigeRequirement;
    final canPrestige = gameState.number >= requirement;
    final pointsToEarn = gameState.prestigePointsOnPrestige;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Main UI ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.toll, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          NumberFormatter.format(gameState.number),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 24),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                    height: 2,
                    color: theme.colorScheme.surfaceContainerLow),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRESTIGE',
                        style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 48),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Reset progress for permanent multipliers and prestige currency.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: PrestigeStatBlock(
                              icon: Icons.stars,
                              label: 'PRESTIGE POINTS',
                              value: NumberFormatter.formatDouble(
                                  gameState.prestigeCurrency),
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PrestigeStatBlock(
                              icon: Icons.bolt,
                              label: 'PRESTIGE MULTIPLIER',
                              value:
                                  '×${NumberFormatter.formatPrestigeMultiplier(gameState.prestigeMultiplier)}',
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                    height: 2,
                    color: theme.colorScheme.surfaceContainerLow),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      8,
                      24,
                      20 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PrestigeGainCard(
                          pointsToEarn: pointsToEarn,
                          prestigeRequirement: requirement,
                          multiplierAfter:
                              gameState.prestigeMultiplierAfterNext,
                        ),
                        const SizedBox(height: 20),
                        if (canPrestige)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isAnimating
                                  ? null
                                  : _confirmAndPrestige,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 20),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: theme.colorScheme.onPrimary),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'INITIATE PRESTIGE',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          color: theme.colorScheme.onPrimary,
                                          letterSpacing: 2.0,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            'REQUIREMENT NOT MET (Reach ${NumberFormatter.format(requirement)})',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showPrestigeShop,
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('PRESTIGE SHOP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme
                                  .colorScheme.secondaryContainer,
                              foregroundColor: theme
                                  .colorScheme.onSecondaryContainer,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Prestige animation overlay ─────────────────────────────────────
          if (_isAnimating)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => PrestigeOverlay(
                progress: _controller.value,
                theme: theme,
                pointsEarned: _pendingPrestigePoints,
              ),
            ),
        ],
      ),
    );
  }
}
