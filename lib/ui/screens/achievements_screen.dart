import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/achievement_data.dart';
import '../../logic/game_state.dart';
import '../../models/achievement.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final unlocked =
        context.select<GameState, int>((gs) => gs.unlockedAchievements.length);
    final unlockedIds = context.read<GameState>().unlockedAchievements;
    final total = Achievements.all.length;
    final bonusPct =
        (unlocked * Achievements.bonusPerAchievement * 100).round();

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
                    Text('ACHIEVEMENTS',
                        style: theme.textTheme.displayLarge
                            ?.copyWith(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      '$unlocked / $total UNLOCKED · +$bonusPct% ALL PRODUCTION',
                      style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          color: cs.primary,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : unlocked / total,
                        minHeight: 4,
                        backgroundColor: cs.surfaceContainerHigh,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final category in AchievementCategory.values)
              ..._categorySlivers(context, category, unlockedIds),
            SliverToBoxAdapter(
              child:
                  SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _categorySlivers(
    BuildContext context,
    AchievementCategory category,
    Set<String> unlockedIds,
  ) {
    final defs = Achievements.all.where((a) => a.category == category).toList();
    if (defs.isEmpty) return const [];
    final theme = Theme.of(context);
    final done = defs.where((a) => unlockedIds.contains(a.id)).length;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            '${category.label} · $done/${defs.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverList.separated(
          itemCount: defs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) => _AchievementTile(
            def: defs[i],
            unlocked: unlockedIds.contains(defs[i].id),
          ),
        ),
      ),
    ];
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.def, required this.unlocked});

  final AchievementDef def;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final concealed = def.hidden && !unlocked;
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
        children: [
          Icon(
            unlocked ? Icons.emoji_events : Icons.lock_outline,
            size: 20,
            color: unlocked ? cs.primary : cs.outlineVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concealed ? '???' : def.title.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: unlocked ? cs.onSurface : cs.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  concealed ? 'A secret. Keep playing.' : def.description,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                ),
              ],
            ),
          ),
          if (unlocked)
            Text('+1%',
                style: theme.textTheme.labelSmall?.copyWith(color: cs.primary)),
        ],
      ),
    );
  }
}
