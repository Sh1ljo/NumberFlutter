import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import '../../../models/research_node.dart';
import 'widgets/research_node_card.dart';

class NexusScreen extends StatelessWidget {
  const NexusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nodes = gameState.researchNodes;

    final tier1 = nodes.where((n) => n.tier == 1).toList();
    final tier2 = nodes.where((n) => n.tier == 2).toList();
    final tier3 = nodes.where((n) => n.tier == 3).toList();

    final pp = gameState.prestigeCurrency;
    final ppDisplay = pp < 10
        ? pp.toStringAsFixed(2)
        : pp.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + PP balance
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
                      '$ppDisplay PP',
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
            'Spend prestige points on permanent research upgrades.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.outline,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Tier I
          _TierSection(
            label: 'TIER  I',
            nodes: tier1,
            allNodes: nodes,
          ),

          _TierConnector(theme: theme),

          // Tier II
          _TierSection(
            label: 'TIER  II',
            nodes: tier2,
            allNodes: nodes,
          ),

          _TierConnector(theme: theme),

          // Tier III
          _TierSection(
            label: 'TIER  III',
            nodes: tier3,
            allNodes: nodes,
          ),
        ],
      ),
    );
  }
}

class _TierSection extends StatelessWidget {
  final String label;
  final List<ResearchNode> nodes;
  final List<ResearchNode> allNodes;

  const _TierSection({
    required this.label,
    required this.nodes,
    required this.allNodes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.outline,
                letterSpacing: 2.5,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                color: cs.surfaceContainerLow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...nodes.map(
          (node) => ResearchNodeCard(node: node, allNodes: allNodes),
        ),
      ],
    );
  }
}

class _TierConnector extends StatelessWidget {
  final ThemeData theme;

  const _TierConnector({required this.theme});

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 1,
            height: 20,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
