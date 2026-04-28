import 'package:flutter/material.dart';
import '../../../models/neural_network.dart';

class NeuronWidget extends StatefulWidget {
  final NeuralNeuron neuron;
  final VoidCallback onTap;
  // When true, the neuron is eligible for branching and should be highlighted.
  final bool highlight;

  const NeuronWidget({
    super.key,
    required this.neuron,
    required this.onTap,
    this.highlight = false,
  });

  @override
  State<NeuronWidget> createState() => _NeuronWidgetState();
}

class _NeuronWidgetState extends State<NeuronWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final level = widget.neuron.gradientLevel;

    // Outer ring opacity increases with gradient level
    final ringBaseOpacity = 0.20 + level * 0.08;
    final innerAlpha =
        level == 0 ? 0.45 : (0.55 + level * 0.09).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer animated ring
                Transform.scale(
                  scale: _scale.value,
                  child: Opacity(
                    opacity: (_opacity.value * (ringBaseOpacity / 0.2))
                        .clamp(0.0, 1.0),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.primary,
                          width: 1.0 + level * 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                // Secondary ring for higher gradient levels
                if (level >= 3)
                  Transform.scale(
                    scale: _scale.value * 0.8,
                    child: Opacity(
                      opacity: (_opacity.value * 0.5 * ((level - 2) / 3))
                          .clamp(0.0, 1.0),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.primary,
                            width: 0.8,
                          ),
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
                if (widget.highlight)
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
}
