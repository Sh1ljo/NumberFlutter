import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../../logic/game_state.dart';
import '../widgets/dot_sphere_painter.dart';
import '../widgets/nexus_disperse_painter.dart';
import 'stabilized_view.dart';

class UnstabilizedView extends StatefulWidget {
  final int prestigeCount;

  const UnstabilizedView({required this.prestigeCount});

  @override
  State<UnstabilizedView> createState() => _UnstabilizedViewState();
}

class _UnstabilizedViewState extends State<UnstabilizedView>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _stabilizeCtrl;
  late final AnimationController _ambientCtrl;
  bool _isStabilizing = false;
  double _disperseStartAngle = 0.0;
  bool _disperseAngleCaptured = false;

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
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    _stabilizeCtrl.addListener(_captureDisperse);
  }

  void _captureDisperse() {
    if (!_disperseAngleCaptured && _stabilizeCtrl.value >= 0.45) {
      final t = _stabilizeCtrl.value;
      final p = (t / 0.45).clamp(0.0, 1.0);
      final spinMultiplier = 1.0 + p * p * 6.0;
      _disperseStartAngle = _ctrl.value * math.pi * 2 * spinMultiplier;
      _disperseAngleCaptured = true;
    }
  }

  @override
  void dispose() {
    _stabilizeCtrl.removeListener(_captureDisperse);
    _ctrl.dispose();
    _stabilizeCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  void _stabilizeNexus() {
    setState(() => _isStabilizing = true);
    _ambientCtrl.repeat();
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
            animation: Listenable.merge([_stabilizeCtrl, _ambientCtrl]),
            builder: (_, __) {
              final t = _stabilizeCtrl.value;

              // Spin-up phase: sphere accelerates before disperse
              if (t < 0.45) {
                final p = t / 0.45;
                final spinMultiplier = 1.0 + p * p * 6.0;
                return Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: DotSpherePainter(
                        angle: _ctrl.value * math.pi * 2 * spinMultiplier,
                        primaryColor: cs.primary,
                      ),
                    ),
                  ),
                );
              }

              // Disperse + ambient drift phase
              final contentOpacity = ((t - 0.80) / 0.20).clamp(0.0, 1.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: NexusDispersePainter(
                      stabilizeT: t,
                      sphereAngle: _disperseStartAngle,
                      ambientT: _ambientCtrl.value * math.pi * 2,
                      primary: cs.primary,
                      outline: cs.outline,
                    ),
                  ),
                  if (contentOpacity > 0)
                    Opacity(
                      opacity: contentOpacity,
                      child: const StabilizedView(),
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
                        painter: DotSpherePainter(
                          angle: _ctrl.value * 3.14159265359 * 2,
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
