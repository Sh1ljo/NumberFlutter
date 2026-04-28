import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';

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
        final resonance =
            state.researchNodes.where((n) => n.id == 'resonance_core').firstOrNull;
        final echo =
            state.researchNodes.where((n) => n.id == 'echo_protocol').firstOrNull;
        final genesis =
            state.researchNodes.where((n) => n.id == 'neural_genesis').firstOrNull;

        final resonanceLevel = resonance?.level ?? 0;
        final echoLevel = echo?.level ?? 0;
        final resonanceMet = resonanceLevel >= 5;
        final echoMet = echoLevel >= 5;
        final genesisAvailable =
            genesis != null && genesis.prereqsMet(state.researchNodes);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final scale = Tween<double>(begin: 1.0, end: 1.2)
                        .animate(CurvedAnimation(
                            parent: _pulseCtrl, curve: Curves.easeInOut))
                        .value;
                    final opacity = Tween<double>(begin: 0.3, end: 0.8)
                        .animate(CurvedAnimation(
                            parent: _pulseCtrl, curve: Curves.easeInOut))
                        .value;

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.primary,
                            width: 1.5 * scale,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: opacity,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.primary,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
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
                  'Locked. Awaken this system from the NEXUS.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: genesisAvailable ? cs.primary : cs.outlineVariant,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(2),
                    color: cs.surfaceContainerLow.withValues(alpha: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXUS REQUIREMENT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.0,
                          color: cs.outline,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PrereqRow(
                        label: 'Resonance Core',
                        current: resonanceLevel,
                        target: 5,
                        met: resonanceMet,
                      ),
                      const SizedBox(height: 6),
                      _PrereqRow(
                        label: 'Echo Protocol',
                        current: echoLevel,
                        target: 5,
                        met: echoMet,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        genesisAvailable
                            ? 'Purchase NEURAL GENESIS in the Nexus to begin.'
                            : 'Both prerequisites must reach Lv 5 to reveal Neural Genesis.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: genesisAvailable ? cs.primary : cs.outlineVariant,
                        ),
                      ),
                    ],
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

class _PrereqRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final bool met;

  const _PrereqRow({
    required this.label,
    required this.current,
    required this.target,
    required this.met,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = met ? cs.primary : cs.outlineVariant;

    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
        Text(
          'Lv $current / $target',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
