import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _releaseHapticFired = false;

  /// Sphere angle when the button was pressed; the spin-up continues from it.
  double _spinBase = 0.0;

  static const Duration _idlePeriod = Duration(seconds: 8);
  static const Duration _stabilizeDuration = Duration(milliseconds: 6500);

  /// Fraction of [_stabilizeDuration] spent spinning up before the burst.
  /// [NexusDispersePainter] assumes the same boundary.
  static const double _releaseT = 0.45;

  /// Spin speed at release relative to the idle speed is `1 + _spinBoost`.
  static const double _spinBoost = 20.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _idlePeriod)..repeat();
    _stabilizeCtrl = AnimationController(
      vsync: this,
      duration: _stabilizeDuration,
    );
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    _stabilizeCtrl.addListener(_onStabilizeTick);
  }

  void _onStabilizeTick() {
    if (!_releaseHapticFired && _stabilizeCtrl.value >= _releaseT) {
      _releaseHapticFired = true;
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _stabilizeCtrl.removeListener(_onStabilizeTick);
    _ctrl.dispose();
    _stabilizeCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  // ── Spin-up curves, all functions of p = t / _releaseT in [0, 1] ─────────

  double get _idleSpeed => 2 * math.pi / (_idlePeriod.inMilliseconds / 1000);
  double get _spinUpSeconds =>
      _stabilizeDuration.inMilliseconds / 1000 * _releaseT;

  /// Angular speed grows as `idle * (1 + boost·p²)`; this is its integral, so
  /// the sphere accelerates smoothly from exactly where it was resting.
  double _spinAngle(double p) =>
      _spinBase +
      _idleSpeed * _spinUpSeconds * (p + _spinBoost * p * p * p / 3);

  /// Radians the sphere covers in ~18ms at progress p; spaces the motion blur.
  double _trailSpread(double p) =>
      _idleSpeed * (1 + _spinBoost * p * p) * 0.018;

  /// The sphere draws in as it charges, with a throb that quickens.
  double _sphereScale(double p) =>
      1.0 -
      0.18 * p * p +
      0.035 * p * math.sin(2 * math.pi * (3 * p + 9 * p * p));

  /// Shake amplitude in logical pixels: a rumble that builds during spin-up,
  /// then a hard kick at release that dies out long before the stabilized
  /// view fades in at t = 0.80.
  double _shakeAmplitude(double t) {
    if (t < _releaseT) {
      final p = t / _releaseT;
      return 4.0 * p * p;
    }
    final since = t - _releaseT;
    if (since > 0.17) return 0.0;
    return 14.0 * math.exp(-since / 0.04);
  }

  void _stabilizeNexus() {
    HapticFeedback.mediumImpact();
    _spinBase = _ctrl.value * math.pi * 2;
    _ctrl.stop();
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

              final Widget scene;
              if (t < _releaseT) {
                // Spin-up: the sphere accelerates, compresses and charges.
                final p = t / _releaseT;
                scene = Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: DotSpherePainter(
                        angle: _spinAngle(p),
                        primaryColor: cs.primary,
                        scale: _sphereScale(p),
                        trailSpread: _trailSpread(p),
                        glow: p * p,
                        ringStrength: ((p - 0.15) / 0.5).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                );
              } else {
                // Release: shockwave, then disperse into the ambient drift.
                final contentOpacity = ((t - 0.80) / 0.20).clamp(0.0, 1.0);
                scene = Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: NexusDispersePainter(
                        stabilizeT: t,
                        sphereAngle: _spinAngle(1.0),
                        sphereScale: _sphereScale(1.0),
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
              }

              // Pseudo-noise from incommensurate sines reads as a rattle
              // rather than a wobble.
              final amp = _shakeAmplitude(t);
              final s = t * _stabilizeDuration.inMilliseconds / 1000;
              final shakeX = amp *
                  (math.sin(s * 83) + 0.5 * math.sin(s * 127 + 1.3)) /
                  1.5;
              final shakeY = amp *
                  (math.cos(s * 71 + 0.7) + 0.5 * math.sin(s * 151)) /
                  1.5;
              final shakeRot =
                  t >= _releaseT ? amp * 0.002 * math.sin(s * 97) : 0.0;

              final flash = t >= _releaseT
                  ? (1.0 - (t - _releaseT) / 0.05).clamp(0.0, 1.0) * 0.85
                  : 0.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(shakeX, shakeY),
                    child: Transform.rotate(angle: shakeRot, child: scene),
                  ),
                  if (flash > 0)
                    IgnorePointer(
                      child: ColoredBox(
                        color: Color.lerp(cs.primary, Colors.white, 0.6)!
                            .withValues(alpha: flash),
                      ),
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
                  // Spins forever while this tab is open; isolate it so each
                  // frame doesn't repaint the text and button around it.
                  RepaintBoundary(
                    child: SizedBox(
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
                    widget.prestigeCount < 3
                        ? 'To stabilize the Nexus, reach Prestige 3.'
                        : 'The Nexus awaits stabilization.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.outlineVariant,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.prestigeCount >= 3) ...[
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
