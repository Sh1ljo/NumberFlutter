import 'package:flutter/material.dart';

/// A brief tap-bonus target that spawns at a random point in the tap area.
/// Pulses gently while its depletion ring counts down; catching it before it
/// fades calls [onCaught], letting it expire calls [onExpire]. Purely a UI
/// concern — [MainGameScreen] owns spawn scheduling and positioning, and the
/// caught reward itself lives in [GameState.activateNeuralSparkBoost].
class NeuralSpark extends StatefulWidget {
  const NeuralSpark({
    super.key,
    required this.lifetime,
    required this.onCaught,
    required this.onExpire,
  });

  final Duration lifetime;
  final VoidCallback onCaught;
  final VoidCallback onExpire;

  static const double diameter = 52.0;
  static const Color glowColor = Color(0xFF8FE3FF);

  @override
  State<NeuralSpark> createState() => _NeuralSparkState();
}

class _NeuralSparkState extends State<NeuralSpark>
    with TickerProviderStateMixin {
  late final AnimationController _lifetimeController;
  late final AnimationController _pulseController;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _lifetimeController = AnimationController(
      vsync: this,
      duration: widget.lifetime,
    )..forward();
    _lifetimeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_resolved) {
        _resolved = true;
        widget.onExpire();
      }
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  void _handleTap() {
    if (_resolved) return;
    _resolved = true;
    widget.onCaught();
  }

  @override
  void dispose() {
    _lifetimeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = NeuralSpark.diameter;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox(
        width: size + 20,
        height: size + 20,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_lifetimeController, _pulseController]),
            builder: (context, child) {
              final remaining = 1.0 - _lifetimeController.value;
              final pulse = 1.0 + (_pulseController.value * 0.12);
              return Opacity(
                opacity: (remaining * 3).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: pulse,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: size,
                        height: size,
                        child: CircularProgressIndicator(
                          value: remaining,
                          strokeWidth: 2.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            NeuralSpark.glowColor,
                          ),
                        ),
                      ),
                      Container(
                        width: size * 0.5,
                        height: size * 0.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              NeuralSpark.glowColor.withValues(alpha: 0.0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: NeuralSpark.glowColor.withValues(alpha: 0.6),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
