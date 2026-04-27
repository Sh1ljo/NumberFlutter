import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import '../../../utils/number_formatter.dart';

class NeuralUnlockScreen extends StatefulWidget {
  const NeuralUnlockScreen({super.key});

  @override
  State<NeuralUnlockScreen> createState() => _NeuralUnlockScreenState();
}

class _NeuralUnlockScreenState extends State<NeuralUnlockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<GameState>(
      builder: (context, state, _) {
        final canUnlock = state.number >= BigInt.from(1000000);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated pulsing locked neuron
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final scale = Tween<double>(begin: 1.0, end: 1.2)
                        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut))
                        .value;
                    final opacity = Tween<double>(begin: 0.3, end: 0.8)
                        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut))
                        .value;

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.primary,
                            width: 2.0 * scale,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: opacity,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primary.withValues(alpha: opacity),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  'NEURAL NETWORK',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unlock the power of neural networks to evolve your number generation.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: canUnlock ? cs.primary : cs.outlineVariant,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(2),
                    color: cs.surfaceContainerLow.withValues(alpha: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNLOCK COST',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 2.0,
                              color: cs.outline,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            NumberFormatter.format(BigInt.from(1000000)),
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                      if (canUnlock)
                        Text(
                          '✓ Ready',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        )
                      else
                        Text(
                          '${NumberFormatter.format(BigInt.from(1000000) - state.number)} more',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.outlineVariant,
                            letterSpacing: 1.0,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canUnlock
                        ? () {
                            context
                                .read<GameState>()
                                .unlockNeuralNetwork();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      disabledBackgroundColor: cs.surfaceContainerHigh,
                      foregroundColor: cs.onPrimary,
                      disabledForegroundColor:
                          cs.outline.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: Text(
                      canUnlock ? 'UNLOCK NETWORK' : 'KEEP BUILDING',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
