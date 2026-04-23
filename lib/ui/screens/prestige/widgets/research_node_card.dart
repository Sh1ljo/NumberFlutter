import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../logic/game_state.dart';
import '../../../../models/research_node.dart';

class ResearchNodeCard extends StatelessWidget {
  final ResearchNode node;
  final List<ResearchNode> allNodes;

  const ResearchNodeCard({
    super.key,
    required this.node,
    required this.allNodes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gameState = context.watch<GameState>();

    final prereqsMet = node.prereqsMet(allNodes);
    final canAfford =
        prereqsMet && gameState.prestigeCurrency >= node.costForNextLevel;
    final isMaxed = node.isMaxed;

    Color borderColor;
    if (isMaxed) {
      borderColor = cs.primary;
    } else if (!prereqsMet) {
      borderColor = cs.outlineVariant;
    } else if (canAfford) {
      borderColor = cs.primary;
    } else {
      borderColor = cs.outline;
    }

    final double cardOpacity = (!prereqsMet && !isMaxed) ? 0.45 : 1.0;

    return Opacity(
      opacity: cardOpacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: 0.55),
          border: Border(
            left: BorderSide(color: borderColor, width: 2),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: icon + name + level badge
            Row(
              children: [
                Icon(node.icon, size: 16, color: cs.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (isMaxed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.primary, width: 1),
                    ),
                    child: Text(
                      'MAXED',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        letterSpacing: 1.5,
                        fontSize: 9,
                      ),
                    ),
                  )
                else
                  Text(
                    'LVL ${node.level} / ${node.maxLevel}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                      letterSpacing: 0.8,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              node.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 10),

            // Row 2: cost / prereq info + purchase button
            if (!isMaxed)
              Row(
                children: [
                  if (!prereqsMet) ...[
                    Icon(Icons.lock_outline,
                        size: 13, color: cs.outlineVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Requires: ${node.prereqDescription(allNodes)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.outlineVariant,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.diamond_outlined,
                        size: 13, color: cs.outline),
                    const SizedBox(width: 6),
                    Text(
                      '${node.costForNextLevel.toStringAsFixed(node.costsScale ? 0 : 0)} PP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: canAfford ? cs.onSurface : cs.outline,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: canAfford
                            ? () =>
                                context.read<GameState>().purchaseResearch(node.id)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford
                              ? cs.primary
                              : cs.surfaceContainerHigh,
                          disabledBackgroundColor: cs.surfaceContainerHigh,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2)),
                          elevation: 0,
                        ),
                        child: Text(
                          canAfford ? 'RESEARCH' : 'INSUFFICIENT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: canAfford ? cs.onPrimary : cs.outlineVariant,
                            letterSpacing: 1.5,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

            // Affordability progress bar (prereqs met but can't afford)
            if (!isMaxed && prereqsMet && !canAfford)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (gameState.prestigeCurrency /
                            node.costForNextLevel)
                        .clamp(0.0, 1.0),
                    minHeight: 1.5,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.08),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(cs.outline),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
