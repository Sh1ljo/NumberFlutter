import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/guide_data.dart';
import '../../logic/game_state.dart';

/// Reference for every system in the game, opened from MORE.
///
/// Entries unlock with the systems they describe. Locked ones stay listed,
/// so the Guide doubles as a map of what is still ahead.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GuideScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Unlocks only move on prestige, a Nexus/network milestone or a tip, so
    // keying the rebuild on those keeps this off the 10x/s ticker.
    context.select<GameState, (int, bool, bool, int)>((gs) => (
          gs.prestigeCount,
          gs.nexusStabilized,
          gs.neuralNetworkUnlocked,
          gs.upgrades.fold<int>(0, (n, u) => n + (u.level > 0 ? 1 : 0)),
        ));
    final gs = context.read<GameState>();
    final all = [for (final s in GuideData.sections) ...s.entries];
    final unlocked = all.where((e) => e.isUnlocked(gs)).length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GUIDE',
                        style: theme.textTheme.displayLarge
                            ?.copyWith(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      '$unlocked / ${all.length} DISCOVERED',
                      style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          color: cs.primary,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: all.isEmpty ? 0 : unlocked / all.length,
                        minHeight: 4,
                        backgroundColor: cs.surfaceContainerHigh,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final section in GuideData.sections) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    section.name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 2,
                      color: cs.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.separated(
                  itemCount: section.entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final entry = section.entries[i];
                    return _GuideTile(
                      entry: entry,
                      unlocked: entry.isUnlocked(gs),
                    );
                  },
                ),
              ),
            ],
            SliverToBoxAdapter(
              child:
                  SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.entry, required this.unlocked});

  final GuideEntry entry;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final concealed = entry.secret && !unlocked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: unlocked ? 0.7 : 0.35),
        border: Border(
          left: BorderSide(
            color: unlocked ? cs.primary : cs.outlineVariant,
            width: 2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              unlocked ? Icons.menu_book_outlined : Icons.lock_outline,
              size: 18,
              color: unlocked ? cs.primary : cs.outlineVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concealed ? '???' : entry.title.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: unlocked ? cs.onSurface : cs.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked ? entry.body : entry.lockedHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: unlocked ? cs.onSurfaceVariant : cs.outline,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
