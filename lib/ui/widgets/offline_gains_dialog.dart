import 'package:flutter/material.dart';
import '../../utils/number_formatter.dart';

class OfflineGainsDialog extends StatelessWidget {
  final BigInt gains;
  final double accuracyGain;
  final VoidCallback onAcknowledge;

  const OfflineGainsDialog({
    super.key,
    required this.gains,
    this.accuracyGain = 0.0,
    required this.onAcknowledge,
  });

  static Future<void> show(
    BuildContext context,
    BigInt gains, {
    double accuracyGain = 0.0,
    required VoidCallback onAcknowledge,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => OfflineGainsDialog(
        gains: gains,
        accuracyGain: accuracyGain,
        onAcknowledge: onAcknowledge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.hub, color: theme.colorScheme.primary, size: 48),
            const SizedBox(height: 24),
            Text(
              'SYSTEM OFFLINE',
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 4.0),
            ),
            const SizedBox(height: 16),
            Text(
              'While you were away, your generators accumulated:',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outlineVariant),
            ),
            const SizedBox(height: 32),
            Text(
              '+${NumberFormatter.format(gains)}',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            if (accuracyGain > 0) ...[
              const SizedBox(height: 24),
              Text(
                'Neural network training continued:',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+${(accuracyGain * 100).toStringAsFixed(2)}% accuracy',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.greenAccent,
                ),
              ),
            ],
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  onAcknowledge();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                child: Text(
                  'ACKNOWLEDGE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
