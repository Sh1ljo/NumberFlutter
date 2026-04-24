import 'package:flutter/material.dart';
import '../../../../models/research_node.dart';
import 'connections_painter.dart';
import 'tech_node.dart';

class TechTree extends StatelessWidget {
  final List<ResearchNode> nodes;
  const TechTree({required this.nodes});

  ResearchNode _find(String id) => nodes.firstWhere((n) => n.id == id);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (context, constraints) {
      final W = constraints.maxWidth;
      const nodeSize = 72.0;
      const rowGap = 82.0;

      final leftX = W / 6;
      final centerX = W / 2;
      final rightX = W * 5 / 6;
      final quickX = W * 0.42;
      final kineticX = W * 0.66;

      final t1Y = nodeSize / 2;
      final t2Y = nodeSize + rowGap + nodeSize / 2;
      final t3Y = nodeSize * 2 + rowGap * 2 + nodeSize / 2;

      final positions = <String, Offset>{
        'opt_protocol': Offset(leftX, t1Y),
        'surge_protocol': Offset(centerX, t1Y),
        'enhanced_extraction': Offset(rightX, t1Y),
        'idle_foundation': Offset(leftX, t2Y),
        'quick_resume': Offset(quickX, t2Y),
        'kinetic_surge': Offset(kineticX, t2Y),
        'resonance_core': Offset(leftX, t3Y),
        'echo_protocol': Offset(rightX, t3Y),
      };

      final connections = [
        ['opt_protocol', 'idle_foundation'],
        ['opt_protocol', 'quick_resume'],
        ['surge_protocol', 'kinetic_surge'],
        ['idle_foundation', 'resonance_core'],
        ['enhanced_extraction', 'echo_protocol'],
      ];

      final totalH = nodeSize * 3 + rowGap * 2;

      return SizedBox(
        width: W,
        height: totalH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ConnectionsPainter(
                  connections: connections,
                  positions: positions,
                  nodes: nodes,
                  halfSize: nodeSize / 2,
                  activeColor: cs.primary.withValues(alpha: 0.65),
                  inactiveColor: cs.outlineVariant.withValues(alpha: 0.22),
                ),
              ),
            ),
            for (final entry in positions.entries)
              Positioned(
                left: entry.value.dx - nodeSize / 2,
                top: entry.value.dy - nodeSize / 2,
                width: nodeSize,
                height: nodeSize,
                child: TechNode(node: _find(entry.key), allNodes: nodes),
              ),
          ],
        ),
      );
    });
  }
}
