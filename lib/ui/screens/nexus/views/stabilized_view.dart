import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../logic/game_state.dart';
import '../widgets/ambient_background.dart';
import '../widgets/tech_tree.dart';

class StabilizedView extends StatelessWidget {
  const StabilizedView();

  @override
  Widget build(BuildContext context) {
    // Selected rather than watched: the ticker notifies ~10x/s and this view
    // only depends on prestige currency and the tree's levels.
    final pp = context.select<GameState, double>((gs) => gs.prestigeCurrency);
    final gameState = context.read<GameState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ppStr = pp < 10 ? pp.toStringAsFixed(2) : pp.toStringAsFixed(1);

    return Stack(
      fit: StackFit.expand,
      children: [
        const AmbientBackground(),
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'NEXUS',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 48),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.diamond_outlined,
                            size: 13, color: cs.outline),
                        const SizedBox(width: 6),
                        Text(
                          '$ppStr PP',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurface,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Research permanent upgrades. Tap a node to view details.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.outline,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              // Levels are mutated in place, so compare them by value to
              // repaint the connection lines when a purchase unlocks one.
              Selector<GameState, List<int>>(
                selector: (_, gs) => [
                  for (final node in gs.researchNodes) node.level,
                ],
                shouldRebuild: (prev, next) => !listEquals(prev, next),
                builder: (context, _, __) =>
                    TechTree(nodes: gameState.researchNodes),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}
