import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../logic/game_state.dart';
import '../../../../models/research_node.dart';
import 'node_detail_sheet.dart';

class TechNode extends StatelessWidget {
  final ResearchNode node;
  final List<ResearchNode> allNodes;

  const TechNode({required this.node, required this.allNodes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gameState = context.watch<GameState>();

    final prereqsMet = node.prereqsMet(allNodes);
    final canAfford =
        prereqsMet && gameState.prestigeCurrency >= node.costForNextLevel;
    final isMaxed = node.isMaxed;

    final Color borderColor;
    final Color iconColor;
    final Color bgColor;

    if (isMaxed) {
      borderColor = cs.primary;
      iconColor = cs.primary;
      bgColor = cs.primary.withValues(alpha: 0.10);
    } else if (!prereqsMet) {
      borderColor = cs.outlineVariant.withValues(alpha: 0.35);
      iconColor = cs.outlineVariant.withValues(alpha: 0.55);
      bgColor = cs.surfaceContainerLow.withValues(alpha: 0.5);
    } else if (canAfford) {
      borderColor = cs.primary;
      iconColor = cs.onSurface;
      bgColor = cs.surfaceContainerLow;
    } else {
      borderColor = cs.outline;
      iconColor = cs.outline;
      bgColor = cs.surfaceContainerLow;
    }

    return GestureDetector(
      onTap: () => _showDetail(context, gameState),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor,
            width: (isMaxed || canAfford) ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(node.icon, size: 20, color: iconColor),
            const SizedBox(height: 5),
            Text(
              isMaxed ? 'MAX' : 'L${node.level}',
              style: TextStyle(
                color: isMaxed ? cs.primary : cs.outlineVariant,
                fontSize: 8,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
                fontFamily: theme.textTheme.labelSmall?.fontFamily,
              ),
            ),
            if (!isMaxed && prereqsMet) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: 34,
                height: 2,
                child: ClipRRect(
                  child: LinearProgressIndicator(
                    value: (gameState.prestigeCurrency / node.costForNextLevel)
                        .clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      canAfford ? cs.primary : cs.outline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, GameState gameState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: gameState,
        child: NodeDetailSheet(node: node, allNodes: allNodes),
      ),
    );
  }
}
