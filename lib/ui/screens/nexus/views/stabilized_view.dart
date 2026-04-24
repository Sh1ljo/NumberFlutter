import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../logic/game_state.dart';
import '../widgets/ambient_background.dart';
import '../widgets/tech_tree.dart';

class StabilizedView extends StatelessWidget {
  const StabilizedView();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pp = gameState.prestigeCurrency;
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
              TechTree(nodes: gameState.researchNodes),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}
