import 'package:flutter/material.dart';
import '../../../../utils/number_formatter.dart';

/// Minimal prestige reward preview: accent stripe, type hierarchy, no nested frames.
class PrestigeGainCard extends StatelessWidget {
  final double pointsToEarn;
  final BigInt prestigeRequirement;
  final double multiplierAfter;

  const PrestigeGainCard({
    super.key,
    required this.pointsToEarn,
    required this.prestigeRequirement,
    required this.multiplierAfter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = theme.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.55),
        border: Border(
          left: BorderSide(color: cs.primary.withValues(alpha: 0.85), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRESTIGE REWARD AFTER INITIATING',
            style: t.labelSmall?.copyWith(
              letterSpacing: 2.4,
              color: cs.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            NumberFormatter.formatDouble(pointsToEarn),
            style: t.headlineMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w400,
              height: 1.05,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'prestige points',
            style: t.bodySmall?.copyWith(
              color: cs.outline,
              letterSpacing: 0.3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Required number for next prestige',
                  style: t.bodySmall?.copyWith(
                    color: cs.outline,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                NumberFormatter.format(prestigeRequirement),
                style: t.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Prestige multiplier after reset',
                  style: t.bodySmall?.copyWith(
                    color: cs.outline,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '×${NumberFormatter.formatPrestigeMultiplier(multiplierAfter)}',
                style: t.titleMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
