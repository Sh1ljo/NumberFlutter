import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../logic/game_state.dart';
import '../../../../utils/number_formatter.dart';

class PrestigeShopPopup extends StatefulWidget {
  final int initialShopBuyAmount;
  final void Function(int) onShopBuyAmountChanged;

  const PrestigeShopPopup({
    super.key,
    required this.initialShopBuyAmount,
    required this.onShopBuyAmountChanged,
  });

  @override
  State<PrestigeShopPopup> createState() => _PrestigeShopPopupState();
}

class _PrestigeShopPopupState extends State<PrestigeShopPopup> {
  late int _shopBuyAmount;

  @override
  void initState() {
    super.initState();
    _shopBuyAmount = widget.initialShopBuyAmount;
  }

  String _getButtonLabel(int amount) {
    switch (amount) {
      case 1:
        return '1x';
      case 10:
        return '10x';
      case 100:
        return '100x';
      case -1:
        return 'MAX';
      default:
        return '${amount}x';
    }
  }

  void _selectAmount(int amount) {
    setState(() => _shopBuyAmount = amount);
    widget.onShopBuyAmountChanged(amount);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);

    final clickCost = NumberFormatter.formatDouble(gameState.totalShopPrestigeCost(
      forClick: true,
      bulkAmount: _shopBuyAmount,
    ));
    final idleCost = NumberFormatter.formatDouble(gameState.totalShopPrestigeCost(
      forClick: false,
      bulkAmount: _shopBuyAmount,
    ));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'PRESTIGE SHOP',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Points: ${NumberFormatter.formatDouble(gameState.prestigeCurrency)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Prestige mult (from resets): ×${NumberFormatter.formatPrestigeMultiplier(gameState.prestigeMultiplier)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Click permanent: ×${NumberFormatter.formatPrestigeMultiplier(gameState.permanentClickMultiplier)} · Idle permanent: ×${NumberFormatter.formatPrestigeMultiplier(gameState.permanentIdleMultiplier)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Shop tiers use incremental bonuses (like prestige). Cost in prestige points rises slowly with rank.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'BUY AMOUNT',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.5,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1X')),
                ButtonSegment(value: 10, label: Text('10X')),
                ButtonSegment(value: 100, label: Text('100X')),
                ButtonSegment(value: -1, label: Text('MAX')),
              ],
              selected: {_shopBuyAmount},
              showSelectedIcon: false,
              onSelectionChanged: (Set<int> sel) {
                if (sel.isNotEmpty) _selectAmount(sel.first);
              },
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: theme.colorScheme.onPrimary,
                selectedBackgroundColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CLICK PERMANENT MULTIPLIER',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  gameState.buyPermanentClickMultiplierAmount(_shopBuyAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: Text(
                  'Upgrade click (${_getButtonLabel(_shopBuyAmount)} — $clickCost pts)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'IDLE PERMANENT MULTIPLIER',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  gameState.buyPermanentIdleMultiplierAmount(_shopBuyAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: Text(
                  'Upgrade idle (${_getButtonLabel(_shopBuyAmount)} — $idleCost pts)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CLOSE',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
