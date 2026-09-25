import 'package:flutter/material.dart';

import '../../../logic/trial/trial_calendar.dart';
import '../../../logic/trial/trial_rules.dart';
import '../../../logic/trial/trial_run.dart';
import '../../../utils/big_number.dart';
import '../../../utils/number_formatter.dart';

/// The Trial's own accent. The main game is monochrome; the warm amber makes
/// it obvious at a glance which mode you're in.
abstract class TrialPalette {
  static const Color accent = Color(0xFFFFB547);
  static const Color accentDim = Color(0x33FFB547);
  static const Color surface = Color(0xFF17130D);
}

String formatTrialNumber(double value, {bool fixed = false}) {
  if (!value.isFinite || value <= 0) return '0';
  if (value < 1000) return value.floor().toString();
  return NumberFormatter.format(wholeBigInt(value), fixedDecimals: fixed);
}

String formatTrialRate(double value) => NumberFormatter.formatGain(value);

class TrialTierBadge extends StatelessWidget {
  const TrialTierBadge({super.key, required this.tier, this.compact = false});

  final TrialTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: tier.color.withValues(alpha: 0.6)),
      ),
      child: Text(
        tier.name.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: tier.color,
          fontSize: compact ? 8.5 : 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class TrialModifierChip extends StatelessWidget {
  const TrialModifierChip({super.key, required this.modifier, this.onTap});

  final TrialModifier modifier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTwist = modifier.kind == TrialModifierKind.twist;
    return Material(
      color: TrialPalette.accentDim,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border:
                Border.all(color: TrialPalette.accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modifier.icon, size: 15, color: TrialPalette.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isTwist ? 'TWIST' : 'RULE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 7.5,
                        letterSpacing: 1.4,
                        color: TrialPalette.accent.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      modifier.title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet explaining this week's rules (and, inside the Trial, the
/// perks taken so far).
Future<void> showTrialRulesSheet(
  BuildContext context, {
  required TrialWeek week,
  required List<TrialModifier> modifiers,
  Map<TrialPerk, int> perks = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            children: [
              Text('WEEK ${week.isoWeekNumber} RULES',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Same for every player. New rules every Monday.',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 16),
              for (final m in modifiers) ...[
                _RuleRow(
                  icon: m.icon,
                  label: m.kind == TrialModifierKind.twist ? 'TWIST' : 'RULE',
                  title: m.title,
                  body: m.description,
                ),
                const SizedBox(height: 14),
              ],
              _RuleRow(
                icon: Icons.schedule,
                label: 'ALWAYS',
                title: 'Away earnings',
                body: 'While you are out of the Trial it keeps earning at 50% '
                    'of its normal rate, for up to 8 hours. Check in a few '
                    'times a day to keep it going.',
              ),
              if (perks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('YOUR PERKS', style: theme.textTheme.labelSmall),
                const SizedBox(height: 10),
                for (final e in perks.entries) ...[
                  _RuleRow(
                    icon: e.key.icon,
                    label: e.value > 1 ? '×${e.value}' : 'PERK',
                    title: e.key.title,
                    body: e.key.description,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TrialPalette.accentDim,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 20, color: TrialPalette.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 8.5,
                  color: TrialPalette.accent,
                ),
              ),
              Text(title,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Draft picker. Returns the chosen perk, or null if dismissed (the
/// Draft stays pending and can be opened again).
Future<TrialPerk?> showTrialDraftSheet(
  BuildContext context, {
  required int draftNumber,
  required List<TrialPerk> choices,
  required Map<TrialPerk, int> owned,
  required int pendingAfterThis,
}) {
  return showModalBottomSheet<TrialPerk>(
    context: context,
    backgroundColor: TrialPalette.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.style, color: TrialPalette.accent),
                  const SizedBox(width: 10),
                  Text('DRAFT $draftNumber',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: TrialPalette.accent)),
                  const Spacer(),
                  if (pendingAfterThis > 0)
                    Text('+$pendingAfterThis more waiting',
                        style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pick one perk. It lasts for the rest of this week. '
                'Every player gets these same choices.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              for (final perk in choices) ...[
                _PerkCard(
                  perk: perk,
                  ownedCount: owned[perk] ?? 0,
                  onTap: () => Navigator.of(ctx).pop(perk),
                ),
                const SizedBox(height: 10),
              ],
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('DECIDE LATER'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PerkCard extends StatelessWidget {
  const _PerkCard({
    required this.perk,
    required this.ownedCount,
    required this.onTap,
  });

  final TrialPerk perk;
  final int ownedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: TrialPalette.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(perk.icon, color: TrialPalette.accent, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(perk.title,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(perk.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (ownedCount > 0)
                Text('OWNED ×$ownedCount',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 8.5)),
            ],
          ),
        ),
      ),
    );
  }
}
