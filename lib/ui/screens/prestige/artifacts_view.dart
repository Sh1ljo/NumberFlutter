import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/artifact_data.dart';
import '../../../logic/game_state.dart';
import '../../../models/artifact.dart';

/// Rebuild key: everything the artifacts tab renders.
typedef _ArtifactsKey = (double, int, int, String);

_ArtifactsKey _selectArtifacts(GameState gs) {
  final levels = gs.artifactState.levels.entries
      .map((e) => '${e.key}:${e.value}')
      .join(',');
  return (
    gs.prestigeCurrency,
    gs.prestigeCount,
    gs.pendingArtifactChoices,
    levels
  );
}

class ArtifactsView extends StatelessWidget {
  const ArtifactsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Selector<GameState, _ArtifactsKey>(
      selector: (_, gs) => _selectArtifacts(gs),
      builder: (context, key, _) {
        final gs = context.read<GameState>();
        final (pp, prestigeCount, pending, _) = key;
        final owned = Artifacts.all
            .where((a) => gs.artifactState.levelOf(a.id) > 0)
            .toList();
        final nextMilestone = ArtifactState.nextMilestoneAfter(prestigeCount);
        final lockedMilestones =
            ArtifactState.milestones.where((m) => m > prestigeCount).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Text('ARTIFACTS',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
              'Relics earned at prestige milestones. Empower them with PP — '
              'there is no level cap.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.outline, height: 1.45),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'PRESTIGE POINTS',
              value: pp.toStringAsFixed(1),
            ),
            _InfoRow(
              label: 'NEXT MILESTONE',
              value: nextMilestone == null
                  ? 'ALL CLAIMED'
                  : 'PRESTIGE $nextMilestone',
            ),
            const SizedBox(height: 20),
            if (pending > 0) ...[
              _SectionLabel(
                  text: pending == 1
                      ? 'CHOOSE AN ARTIFACT'
                      : 'CHOOSE AN ARTIFACT · $pending WAITING'),
              const SizedBox(height: 10),
              const ArtifactOfferList(),
              const SizedBox(height: 24),
            ],
            _SectionLabel(text: 'OWNED · ${owned.length}'),
            const SizedBox(height: 10),
            if (owned.isEmpty)
              Text(
                'Reach Prestige ${ArtifactState.milestones.first} to claim your first artifact.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            for (final def in owned)
              _OwnedArtifactCard(
                def: def,
                level: gs.artifactState.levelOf(def.id),
                pp: pp,
              ),
            if (lockedMilestones.isNotEmpty) ...[
              const SizedBox(height: 16),
              const _SectionLabel(text: 'LOCKED SLOTS'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in lockedMilestones)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: cs.outline),
                          const SizedBox(width: 6),
                          Text('P$m',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: cs.outline)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The three cards of the current offer. Shared by the tab and the sheet
/// that pops after a milestone prestige.
class ArtifactOfferList extends StatelessWidget {
  const ArtifactOfferList({super.key, this.onChosen});

  final VoidCallback? onChosen;

  @override
  Widget build(BuildContext context) {
    final gs = context.read<GameState>();
    final offer = gs.currentArtifactOffer ?? const <String>[];
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        for (final id in offer)
          if (Artifacts.byId(id) case final def?)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ArtifactCardFrame(
                accent: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(def.name.toUpperCase(),
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(def.tagline,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.outline)),
                          const SizedBox(height: 6),
                          Text(def.describe(1),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        if (gs.chooseArtifact(id)) onChosen?.call();
                      },
                      style: _buttonStyle(cs, enabled: true),
                      child: const Text('CLAIM', style: _buttonText),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _OwnedArtifactCard extends StatelessWidget {
  const _OwnedArtifactCard({
    required this.def,
    required this.level,
    required this.pp,
  });

  final ArtifactDef def;
  final int level;
  final double pp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cost = ArtifactState.empowerCost(level);
    final canAfford = pp >= cost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ArtifactCardFrame(
        accent: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(def.name.toUpperCase(),
                      style: theme.textTheme.titleMedium),
                ),
                Text('LV $level',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(def.describe(level), style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text('Next: ${def.describe(level + 1)}',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: canAfford
                    ? () => context.read<GameState>().empowerArtifact(def.id)
                    : null,
                style: _buttonStyle(cs, enabled: canAfford),
                child: Text('EMPOWER — ${cost.toStringAsFixed(1)} PP',
                    style: _buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pops the offer for the next unclaimed milestone. Returns when the player
/// claims one or dismisses the sheet (the offer then waits in the tab).
class ArtifactChoiceSheet {
  static Future<void> show(BuildContext context) {
    final gs = context.read<GameState>();
    final milestone = ArtifactState.milestones[gs
        .artifactState.claimedMilestones
        .clamp(0, ArtifactState.milestones.length - 1)];
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return ChangeNotifierProvider<GameState>.value(
          value: gs,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, 24 + MediaQuery.of(ctx).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRESTIGE $milestone MILESTONE',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(letterSpacing: 2, color: cs.outline)),
                const SizedBox(height: 4),
                Text('CHOOSE AN ARTIFACT', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Artifacts you pass on can show up again at a later milestone.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 16),
                ArtifactOfferList(onChosen: () => Navigator.of(ctx).pop()),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('DECIDE LATER'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArtifactCardFrame extends StatelessWidget {
  const _ArtifactCardFrame({required this.child, required this.accent});

  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.52),
        border: Border(
          left: BorderSide(
              color: accent ? cs.primary : cs.outlineVariant, width: 2),
        ),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 2,
        color: theme.colorScheme.outline,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 2, color: theme.colorScheme.outline)),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

const TextStyle _buttonText =
    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 11);

ButtonStyle _buttonStyle(ColorScheme cs, {required bool enabled}) =>
    OutlinedButton.styleFrom(
      foregroundColor: cs.primary,
      disabledForegroundColor: cs.outline.withValues(alpha: 0.5),
      side: BorderSide(color: enabled ? cs.primary : cs.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
