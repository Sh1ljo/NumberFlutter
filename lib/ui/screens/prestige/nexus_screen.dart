import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import '../../../models/research_node.dart';

class NexusScreen extends StatelessWidget {
  const NexusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prestigeCount =
        context.select<GameState, int>((g) => g.prestigeCount);
    final nexusStabilized =
        context.select<GameState, bool>((g) => g.nexusStabilized);

    // If already stabilized, show the stabilized view
    if (nexusStabilized) {
      return const _StabilizedView();
    }

    return prestigeCount == 0
        ? const _UnstabilizedView(prestigeCount: 0)
        : _UnstabilizedView(prestigeCount: prestigeCount);
  }
}

// ─────────────────────────────────── UNSTABILIZED ────────────────────────────

class _UnstabilizedView extends StatefulWidget {
  final int prestigeCount;

  const _UnstabilizedView({required this.prestigeCount});

  @override
  State<_UnstabilizedView> createState() => _UnstabilizedViewState();
}

class _UnstabilizedViewState extends State<_UnstabilizedView>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _stabilizeCtrl;
  bool _isStabilizing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _stabilizeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _stabilizeCtrl.dispose();
    super.dispose();
  }

  void _stabilizeNexus() {
    setState(() => _isStabilizing = true);
    _stabilizeCtrl.forward().then((_) {
      if (mounted) {
        context.read<GameState>().stabilizeNexus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (_isStabilizing)
          AnimatedBuilder(
            animation: _stabilizeCtrl,
            builder: (_, __) {
              final t = _stabilizeCtrl.value;
              // Smoothly increment spin speed (cubic curve)
              final spinMultiplier = 1.0 + (t * t * t) * 8.0;
              // Faster dot spreading for wow effect
              final sphereExpand = 1.0 + (t < 0.7 ? t * 1.2 : (0.7 - (t - 0.7)) * 1.2);
              // Keep sphere at full opacity longer, then fade
              final sphereOpacity = (math.max(0.0, 1.0 - (t - 0.5) * 2.0).clamp(0.0, 1.0) as double);
              // Fade in content after halfway point
              final contentOpacity = (t > 0.5 ? (t - 0.5) * 2.0 : 0.0).clamp(0.0, 1.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Opacity(
                      opacity: sphereOpacity,
                      child: SizedBox(
                        width: 180 * sphereExpand,
                        height: 180 * sphereExpand,
                        child: CustomPaint(
                          painter: _DotSpherePainter(
                            angle: _ctrl.value * math.pi * 2 * spinMultiplier,
                            primaryColor: cs.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: contentOpacity,
                    child: const _StabilizedView(),
                  ),
                ],
              );
            },
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => CustomPaint(
                        painter: _DotSpherePainter(
                          angle: _ctrl.value * math.pi * 2,
                          primaryColor: cs.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'NEXUS NOT YET STABILIZED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                      letterSpacing: 3.0,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.prestigeCount == 0
                        ? 'To stabilize the Nexus, reach Prestige 1.'
                        : 'The Nexus awaits stabilization.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.outlineVariant,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.prestigeCount > 0) ...[
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _stabilizeNexus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      child: Text(
                        'STABILIZE NEXUS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onPrimary,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DotSpherePainter extends CustomPainter {
  final double angle;
  final Color primaryColor;
  static const int _n = 100;

  const _DotSpherePainter({required this.angle, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.82;
    // Golden angle in radians ≈ 2.39996
    const goldenAngle = 2.399963229728653;

    final dots = <(double, double, double)>[];

    for (int i = 0; i < _n; i++) {
      final t = i / (_n - 1);
      final inclination = math.acos(1 - 2 * t);
      final azimuth = goldenAngle * i;

      // Unit sphere coords
      final sx = math.sin(inclination) * math.cos(azimuth);
      final sy = math.sin(inclination) * math.sin(azimuth);
      final sz = math.cos(inclination);

      // Subtle oscillation per dot
      final osc = 1.0 + 0.045 * math.sin(angle * 3.2 + i * 0.31);

      // Rotate sphere around Y axis
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final rx = sx * cosA + sz * sinA;
      final rz = -sx * sinA + sz * cosA;

      final screenX = cx + rx * r * osc;
      final screenY = cy + sy * r * osc;
      final depth = (rz + 1) / 2; // 0 = back, 1 = front

      dots.add((screenX, screenY, depth));
    }

    // Sort back-to-front so closer dots render on top
    dots.sort((a, b) => a.$3.compareTo(b.$3));

    for (final (dx, dy, depth) in dots) {
      final dotR = 1.0 + depth * 2.6;
      final alpha = 0.08 + depth * 0.72;
      canvas.drawCircle(
        Offset(dx, dy),
        dotR,
        Paint()
          ..color = primaryColor.withValues(alpha: alpha * 0.75)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_DotSpherePainter old) =>
      old.angle != angle || old.primaryColor != primaryColor;
}

// ─────────────────────────────── STABILIZED (TECH TREE) ──────────────────────

class _StabilizedView extends StatelessWidget {
  const _StabilizedView();

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
        const _NexusAmbientBackground(),
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
              _NexusTechTree(nodes: gameState.researchNodes),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _NexusAmbientBackground extends StatefulWidget {
  const _NexusAmbientBackground();

  @override
  State<_NexusAmbientBackground> createState() =>
      _NexusAmbientBackgroundState();
}

class _NexusAmbientBackgroundState extends State<_NexusAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _NexusAmbientPainter(
                progress: _controller.value,
                primary: theme.colorScheme.primary,
                surface: theme.colorScheme.surface,
                outline: theme.colorScheme.outline,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _NexusAmbientPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color surface;
  final Color outline;

  const _NexusAmbientPainter({
    required this.progress,
    required this.primary,
    required this.surface,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final t = progress * math.pi * 2;

    // Soft base so the motion stays subtle and readable under UI.
    final baseRect = Offset.zero & size;
    final base = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.15,
        colors: [
          surface.withValues(alpha: 0.10),
          surface.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(baseRect);
    canvas.drawRect(baseRect, base);

    // Large drifting glow blobs (very soft).
    const glowSeeds = <(double x, double y, double r, double phase)>[
      (0.18, 0.22, 0.22, 0.3),
      (0.82, 0.30, 0.25, 1.1),
      (0.42, 0.74, 0.30, 2.2),
      (0.68, 0.60, 0.18, 2.9),
    ];
    for (final seed in glowSeeds) {
      final cx = w * seed.$1 + math.sin(t * 0.45 + seed.$4) * 24;
      final cy = h * seed.$2 + math.cos(t * 0.37 + seed.$4 * 1.2) * 18;
      final radius = math.min(w, h) * seed.$3;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawCircle(Offset(cx, cy), radius, glow);
    }

    // Random-feeling drifting particles (deterministic seeds for stable motion).
    const particleCount = 36;
    for (int i = 0; i < particleCount; i++) {
      final baseX = ((i * 73) % 100) / 100.0;
      final baseY = ((i * 37 + 17) % 100) / 100.0;
      final phase = i * 0.61;
      final speed = 0.35 + (i % 7) * 0.08;

      final x = w * ((baseX + 0.04 * math.sin(t * speed + phase) + 1.0) % 1.0);
      final y = h *
          ((baseY + 0.05 * math.cos(t * (speed * 0.85) + phase * 1.2) + 1.0) %
              1.0);

      final pulse = 0.5 + 0.5 * math.sin(t * (0.9 + (i % 5) * 0.12) + phase);
      final r = 0.9 + pulse * 1.9;
      final alpha = 0.10 + pulse * 0.22;

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = primary.withValues(alpha: alpha),
      );

      if (i % 4 == 0) {
        canvas.drawCircle(
          Offset(x, y),
          r + 3.0 + pulse * 4.0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = outline.withValues(alpha: 0.07 + pulse * 0.04),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NexusAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.surface != surface ||
        oldDelegate.outline != outline;
  }
}

// ───────────────────────────────────── TECH TREE ─────────────────────────────

class _NexusTechTree extends StatelessWidget {
  final List<ResearchNode> nodes;
  const _NexusTechTree({required this.nodes});

  ResearchNode _find(String id) => nodes.firstWhere((n) => n.id == id);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (context, constraints) {
      final W = constraints.maxWidth;
      const nodeSize = 72.0;
      const rowGap = 82.0;

      // Column x-centers
      final leftX = W / 6;
      final centerX = W / 2;
      final rightX = W * 5 / 6;
      final quickX = W * 0.42;
      final kineticX = W * 0.66;

      // Row y-centers
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

      // [from, to]
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
            // Connection lines drawn behind nodes
            Positioned.fill(
              child: CustomPaint(
                painter: _ConnectionsPainter(
                  connections: connections,
                  positions: positions,
                  nodes: nodes,
                  halfSize: nodeSize / 2,
                  activeColor: cs.primary.withValues(alpha: 0.65),
                  inactiveColor: cs.outlineVariant.withValues(alpha: 0.22),
                ),
              ),
            ),
            // Node widgets
            for (final entry in positions.entries)
              Positioned(
                left: entry.value.dx - nodeSize / 2,
                top: entry.value.dy - nodeSize / 2,
                width: nodeSize,
                height: nodeSize,
                child: _TechNode(node: _find(entry.key), allNodes: nodes),
              ),
          ],
        ),
      );
    });
  }
}

// ────────────────────────────────── CONNECTION PAINTER ───────────────────────

class _ConnectionsPainter extends CustomPainter {
  final List<List<String>> connections;
  final Map<String, Offset> positions;
  final List<ResearchNode> nodes;
  final double halfSize;
  final Color activeColor;
  final Color inactiveColor;

  const _ConnectionsPainter({
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

      // Draw from edge of source node to edge of dest node
      final start = Offset(from.dx + nx * halfSize, from.dy + ny * halfSize);
      final end = Offset(to.dx - nx * halfSize, to.dy - ny * halfSize);

      final paint = Paint()
        ..color = active ? activeColor : inactiveColor
        ..strokeWidth = active ? 1.5 : 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(start, end, paint);

      // Small dot at destination end
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
  bool shouldRepaint(_ConnectionsPainter old) => true;
}

// ──────────────────────────────────── TECH NODE ──────────────────────────────

class _TechNode extends StatelessWidget {
  final ResearchNode node;
  final List<ResearchNode> allNodes;

  const _TechNode({required this.node, required this.allNodes});

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
        child: _NodeDetailSheet(node: node, allNodes: allNodes),
      ),
    );
  }
}

// ──────────────────────────────── NODE DETAIL SHEET ──────────────────────────

class _NodeDetailSheet extends StatelessWidget {
  final ResearchNode node;
  final List<ResearchNode> allNodes;

  const _NodeDetailSheet({required this.node, required this.allNodes});

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
          // Header: icon + name + close
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

          // Tier level progress bar
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

          // Prerequisite lock notice
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

          // Cost + buy button (prereqs met, not maxed)
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
