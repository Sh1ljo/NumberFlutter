import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../logic/game_state.dart';
import '../../../../models/research_node.dart';

class NodeDetailSheet extends StatelessWidget {
  final ResearchNode node;
  final List<ResearchNode> allNodes;

  const NodeDetailSheet({required this.node, required this.allNodes});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final prereqsMet = node.prereqsMet(allNodes);
    final canAfford =
        prereqsMet && gameState.prestigeCurrency >= node.costForNextLevel;
    final isMaxed = node.isMaxed;
    final pp = gameState.prestigeCurrency;
    final ppStr = pp < 10 ? pp.toStringAsFixed(2) : pp.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isMaxed ? cs.primary : cs.outline,
                    width: 1,
                  ),
                  color: cs.surfaceContainerLow,
                ),
                child: Icon(
                  node.icon,
                  size: 18,
                  color: isMaxed ? cs.primary : cs.onSurface,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMaxed
                          ? 'MAXED OUT'
                          : 'LEVEL  ${node.level} / ${node.maxLevel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isMaxed ? cs.primary : cs.outline,
                        letterSpacing: 1.2,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, size: 18, color: cs.outline),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            node.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.8),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 18),

          // Progress bar
          if (!isMaxed) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TIER PROGRESS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                    letterSpacing: 1.5,
                    fontSize: 8,
                  ),
                ),
                Text(
                  '${node.level} / ${node.maxLevel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              child: LinearProgressIndicator(
                value: node.level / node.maxLevel,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  cs.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Prerequisite lock
          if (!prereqsMet) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
                color: cs.surfaceContainerLow.withValues(alpha: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 13, color: cs.outlineVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Requires: ${node.prereqDescription(allNodes)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.outlineVariant,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Cost & button
          if (!isMaxed && prereqsMet) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COST',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                        letterSpacing: 1.5,
                        fontSize: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.diamond_outlined,
                          size: 13,
                          color: canAfford ? cs.primary : cs.outline,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${node.costForNextLevel.toStringAsFixed(0)} PP',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: canAfford ? cs.onSurface : cs.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Balance: $ppStr PP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.outlineVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: canAfford
                        ? () {
                            context.read<GameState>().purchaseResearch(node.id);
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canAfford ? cs.primary : cs.surfaceContainerHigh,
                      disabledBackgroundColor: cs.surfaceContainerHigh,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                      elevation: 0,
                    ),
                    child: Text(
                      canAfford ? 'RESEARCH' : 'INSUFFICIENT',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: canAfford ? cs.onPrimary : cs.outlineVariant,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!canAfford) ...[
              const SizedBox(height: 10),
              ClipRRect(
                child: LinearProgressIndicator(
                  value: (gameState.prestigeCurrency / node.costForNextLevel)
                      .clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(cs.outline),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
