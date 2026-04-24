import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../models/research_node.dart';

class ConnectionsPainter extends CustomPainter {
  final List<List<String>> connections;
  final Map<String, Offset> positions;
  final List<ResearchNode> nodes;
  final double halfSize;
  final Color activeColor;
  final Color inactiveColor;

  const ConnectionsPainter({
    required this.connections,
    required this.positions,
    required this.nodes,
    required this.halfSize,
    required this.activeColor,
    required this.inactiveColor,
  });

  bool _isActive(String toId) {
    final node = nodes.where((n) => n.id == toId).firstOrNull;
    return node?.prereqsMet(nodes) ?? false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      final from = positions[conn[0]];
      final to = positions[conn[1]];
      if (from == null || to == null) continue;

      final active = _isActive(conn[1]);

      final dx = to.dx - from.dx;
      final dy = to.dy - from.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = dx / len;
      final ny = dy / len;

      final start = Offset(from.dx + nx * halfSize, from.dy + ny * halfSize);
      final end = Offset(to.dx - nx * halfSize, to.dy - ny * halfSize);

      final paint = Paint()
        ..color = active ? activeColor : inactiveColor
        ..strokeWidth = active ? 1.5 : 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(start, end, paint);

      canvas.drawCircle(
        end,
        2.0,
        Paint()
          ..color = active ? activeColor : inactiveColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(ConnectionsPainter old) => true;
}
