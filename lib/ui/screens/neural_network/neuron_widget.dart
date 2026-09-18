import 'package:flutter/material.dart';
import '../../../models/neural_network.dart';

class NeuronWidget extends StatelessWidget {
  final NeuralNeuron neuron;
  final VoidCallback onTap;

  /// Shared breathing animation, driven by the canvas and already eased.
  /// Every neuron used to own its own repeating controller, which meant up to
  /// 22 of them running concurrently for one visual effect.
  final Animation<double> pulse;

  static final Tween<double> _scaleTween = Tween<double>(begin: 1.0, end: 1.15);
  static final Tween<double> _opacityTween = Tween<double>(begin: 0.2, end: 0.6);

  // When true, the neuron is eligible for branching and should be highlighted.
  final bool highlight;

  const NeuronWidget({
    super.key,
    required this.neuron,
    required this.onTap,
    required this.pulse,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final level = neuron.gradientLevel;

    // Outer ring opacity increases with gradient level
    final ringBaseOpacity = 0.20 + level * 0.08;
    final innerAlpha =
        level == 0 ? 0.45 : (0.55 + level * 0.09).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (_, __) {
            final t = pulse.value;
            final scale = _scaleTween.transform(t);
            final opacity = _opacityTween.transform(t);
            // The rings are single strokes, so baking the animated opacity
            // into the border colour looks identical to an Opacity widget
            // without forcing an offscreen layer per ring per frame.
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer animated ring
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _fade(
                          cs.primary,
                          (opacity * (ringBaseOpacity / 0.2)).clamp(0.0, 1.0),
                        ),
                        width: 1.0 + level * 0.2,
                      ),
                    ),
                  ),
                ),
                // Secondary ring for higher gradient levels
                if (level >= 3)
                  Transform.scale(
                    scale: scale * 0.8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _fade(
                            cs.primary,
                            (opacity * 0.5 * ((level - 2) / 3)).clamp(0.0, 1.0),
                          ),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                // Inner solid dot
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: level == 0
                        ? cs.outlineVariant.withValues(alpha: innerAlpha)
                        : cs.primary.withValues(alpha: innerAlpha),
                  ),
                ),
                // Highlight overlay for branchable neurons
                if (highlight)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Subtle accent that respects the current theme.
                      boxShadow: [
                        BoxShadow(
                          color: cs.secondary.withValues(alpha: 0.25),
                          spreadRadius: 2,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Color _fade(Color c, double opacity) =>
      c.withValues(alpha: c.a * opacity);
}
