import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/achievement_data.dart';
import '../../logic/game_state.dart';
import '../../models/achievement.dart';
import '../widgets/one_shot_highlight.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, this.highlightIds = const {}});

  final Set<String> highlightIds;

  static Future<void> open(
    BuildContext context, {
    Set<String> highlightIds = const {},
  }) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AchievementsScreen(highlightIds: highlightIds),
        ),
      );

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final Map<String, GlobalKey> _highlightKeys = {
    for (final id in widget.highlightIds) id: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.highlightIds.isEmpty) return;
      final context = _highlightKeys[widget.highlightIds.first]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.4,
        );
      }
    });
  }

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
          // Keep the achievement tiles cached so a notice can scroll directly
          // to and highlight an entry lower in the list on first frame.
          cacheExtent: 10000,
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
          itemBuilder: (context, i) {
            final def = defs[i];
            final tile = _AchievementTile(
              def: def,
              unlocked: unlockedIds.contains(def.id),
              highlighted: widget.highlightIds.contains(def.id),
            );
            final key = _highlightKeys[def.id];
            return key == null ? tile : KeyedSubtree(key: key, child: tile);
          },
        ),
      ),
    ];
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.def,
    required this.unlocked,
    required this.highlighted,
  });

  final AchievementDef def;
  final bool unlocked;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final concealed = def.hidden && !unlocked;
    return OneShotHighlight(
      highlight: highlighted,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              cs.surfaceContainerLow.withValues(alpha: unlocked ? 0.7 : 0.35),
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
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
            if (unlocked)
              Text(
                '+1%',
                style: theme.textTheme.labelSmall?.copyWith(color: cs.primary),
              ),
          ],
        ),
      ),
    );
  }
}
