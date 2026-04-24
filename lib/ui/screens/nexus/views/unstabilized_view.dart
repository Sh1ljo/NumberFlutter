import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../logic/game_state.dart';
import '../widgets/dot_sphere_painter.dart';
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
              final spinMultiplier = 1.0 + (t * t * t) * 8.0;
              final sphereExpand =
                  1.0 + (t < 0.7 ? t * 1.2 : (0.7 - (t - 0.7)) * 1.2);
              final sphereOpacity =
                  ((-((t - 0.5) * 2.0).clamp(-1.0, 1.0)) + 1.0).clamp(0.0, 1.0)
                      as double;
              final contentOpacity =
                  (t > 0.5 ? (t - 0.5) * 2.0 : 0.0).clamp(0.0, 1.0);

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
                          painter: DotSpherePainter(
                            angle: _ctrl.value *
                                3.14159265359 *
                                2 *
                                spinMultiplier,
                            primaryColor: cs.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
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
