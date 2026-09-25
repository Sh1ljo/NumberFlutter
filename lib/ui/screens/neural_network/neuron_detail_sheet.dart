import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import '../../../logic/tutorial_step.dart';
import '../../../models/neural_network.dart';
import '../../../utils/number_formatter.dart';

class NeuronDetailSheet extends StatefulWidget {
  final NeuralNeuron neuron;

  const NeuronDetailSheet({super.key, required this.neuron});

  static Future<void> show(BuildContext context, NeuralNeuron neuron) async {
    final gameState = context.read<GameState>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NeuronDetailSheet(neuron: neuron),
    );
    // Awaiting the route covers every dismissal path, so the tutorial can
    // re-target the main screen only once this sheet is really gone.
    gameState.onNeuronSheetDismissed();
  }

  @override
  State<NeuronDetailSheet> createState() => _NeuronDetailSheetState();
}

class _NeuronDetailSheetState extends State<NeuronDetailSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  /// The pulse only drives tutorial highlights, so it only ticks while one
  /// is on screen instead of requesting frames for the sheet's whole life.
  void _syncPulse(bool needed) {
    if (needed && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!needed && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  /// Everything the sheet renders that can change while it is open. The
  /// ticker notifies ~10x/s, but the sheet only needs to rebuild when the
  /// network, the tutorial step, or one of its affordability checks flips.
  (Object, TutorialStep, int) _rebuildKey(GameState state) {
    final neuron = state.neuralNetwork.findNeuron(widget.neuron.id);
    int affordMask = 0;
    if (neuron != null) {
      final number = state.number;
      if (number >= state.neuronGradientCost(neuron)) affordMask |= 1;
      if (number >= state.neuralBranchCost) affordMask |= 2;
      for (int i = 0; i < activationFunctions.length; i++) {
        if (number >= state.neuronActivationCost(neuron, activationFunctions[i])) {
          affordMask |= 4 << i;
        }
      }
    }
    return (state.neuralTopologyKey, state.tutorialStep, affordMask);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _buildSectionHighlight({
    required bool active,
    required Widget child,
    required ColorScheme cs,
  }) {
    if (!active) return child;
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_pulseCtrl.value);
        return Container(
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.04 + t * 0.06),
            border: Border(
              left: BorderSide(
                color: cs.primary.withValues(alpha: 0.4 + t * 0.6),
                width: 3,
              ),
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _statusPill({
    required ThemeData theme,
    required ColorScheme cs,
    required String text,
    required bool accent,
  }) {
    final color = accent ? cs.primary : cs.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(2),
        color: accent
            ? cs.primary.withValues(alpha: 0.06)
            : cs.surfaceContainerLow.withValues(alpha: 0.5),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildArchitectureBody({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme cs,
    required NeuralNeuron neuron,
    required NeuronBranchBlock? blockReason,
    required bool canAffordBranch,
    required BigInt branchCost,
    required int activeLayerIdx,
    required int? nextDeepGate,
  }) {
    if (blockReason == NeuronBranchBlock.alreadyBranched) {
      return _statusPill(
        theme: theme,
        cs: cs,
        text: 'BRANCHED ✓',
        accent: true,
      );
    }
    if (blockReason == NeuronBranchBlock.terminal ||
        blockReason == NeuronBranchBlock.networkComplete) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusPill(
            theme: theme,
            cs: cs,
            text: blockReason == NeuronBranchBlock.networkComplete
                ? 'NETWORK COMPLETE'
                : 'TERMINAL NEURON',
            accent: false,
          ),
          const SizedBox(height: 8),
          Text(
            blockReason == NeuronBranchBlock.networkComplete
                ? 'The network is fully expanded — no more layers can be added.'
                : 'This neuron sits at a position that does not branch in the pyramid.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ],
      );
    }
    if (blockReason == NeuronBranchBlock.depthLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusPill(
            theme: theme,
            cs: cs,
            text: 'DEEP LAYER LOCKED',
            accent: false,
          ),
          const SizedBox(height: 8),
          Text(
            nextDeepGate == null
                ? 'The next deep layer is not available yet.'
                : 'The next deep layer unlocks at Prestige $nextDeepGate.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ],
      );
    }
    if (blockReason == NeuronBranchBlock.previousLayerIncomplete) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusPill(
            theme: theme,
            cs: cs,
            text: 'LAYER LOCKED',
            accent: false,
          ),
          const SizedBox(height: 8),
          Text(
            'Finish branching layer $activeLayerIdx before this layer can be expanded.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ],
      );
    }

    // Eligible to branch.
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Branch this neuron to expand the network.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(height: 2),
              Text(
                'Cost: ${NumberFormatter.format(branchCost)}',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: canAffordBranch
              ? () {
                  final ok = context.read<GameState>().branchNeuron(neuron.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not enough currency.'),
                        ),
                      );
                    }
                  }
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            disabledForegroundColor: cs.outline.withValues(alpha: 0.5),
            side: BorderSide(
              color: canAffordBranch ? cs.primary : cs.outlineVariant,
              width: 1,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text(
            'BRANCH',
            style: TextStyle(
                fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 11),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Selector<GameState, (Object, TutorialStep, int)>(
      selector: (_, state) => _rebuildKey(state),
      builder: (context, _, __) {
        final state = context.read<GameState>();
        final currentNeuron = state.neuralNetwork.findNeuron(widget.neuron.id);
        if (currentNeuron == null) {
          // Popping during build asserts; do it once the frame is done.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        }

        final gradientCap = state.neuralNetwork.gradientCap;
        final gradientMaxed =
            state.neuralNetwork.isGradientMaxed(currentNeuron);
        final gradientCost = state.neuronGradientCost(currentNeuron);
        final canAffordGradient =
            !gradientMaxed && state.number >= gradientCost;

        final canBranch = state.canBranchNeuron(currentNeuron.id);
        final blockReason = state.neuronBranchBlockReason(currentNeuron.id);
        final branchCost = state.neuralBranchCost;
        final canAffordBranch = canBranch && state.number >= branchCost;
        final activeLayerIdx = state.neuralActiveExpansionLayer;

        final selectedFn = currentNeuron.activationFn;
        final fnDescription = activationFunctionDescriptions[selectedFn] ?? '';

        final layer = state.neuralNetwork.findNeuronLayer(currentNeuron.id);
        final layerIndex = layer?.index ?? 0;
        final preferredFn = preferredActivationByLayer[layerIndex];
        final activationMatchesPreferred =
            preferredFn != null && currentNeuron.activationFn == preferredFn;
        final depthBonus = 1.0 + 0.25 * layerIndex;
        final preferredBonus = state.neuralPreferredBonus;
        final neuronContribution = NeuralNetwork.neuronContribution(
            layerIndex, currentNeuron,
            preferredBonus: preferredBonus);
        final networkStrength = state.neuralNetworkStrength;
        final sumContributions =
            state.neuralNetwork.contributionSum(preferredBonus: preferredBonus);
        final remaining = sumContributions - neuronContribution;
        final marginalStrength = remaining > 0
            ? networkStrength - math.log(1.0 + remaining)
            : networkStrength;

        // Tutorial step flags
        final tutStep = state.tutorialStep;
        final isGradientTutorial =
            tutStep == TutorialStep.neuralUpgradeGradient;
        final isActivationTutorial =
            tutStep == TutorialStep.neuralChangeActivation;
        final isBranchTutorial = tutStep == TutorialStep.neuralBranchNeuron;
        final hasTutorialHint =
            isGradientTutorial || isActivationTutorial || isBranchTutorial;
        _syncPulse(hasTutorialHint);

        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Tutorial hint banner ─────────────────────────────────────
              if (hasTutorialHint)
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final t = Curves.easeInOut.transform(_pulseCtrl.value);
                    return Container(
                      color: cs.primary.withValues(alpha: 0.06 + t * 0.06),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.touch_app,
                            color:
                                cs.primary.withValues(alpha: 0.55 + t * 0.45),
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isGradientTutorial
                                ? 'UPGRADE THE GRADIENT BELOW'
                                : isActivationTutorial
                                    ? 'CHANGE THE ACTIVATION FUNCTION BELOW'
                                    : 'BRANCH THE NEURON BELOW',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outlineVariant, width: 1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child:
                          Icon(Icons.hub_outlined, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEURON',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 2.0,
                              color: cs.outline,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            currentNeuron.id.replaceAll('_', ' ').toUpperCase(),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    // Gradient badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: currentNeuron.gradientLevel > 0
                              ? cs.primary
                              : cs.outlineVariant,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'GR ${currentNeuron.gradientLevel}/$gradientCap',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: currentNeuron.gradientLevel > 0
                              ? cs.primary
                              : cs.outline,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Container(
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Gradient section ─────────────────────────────────────────
              _buildSectionHighlight(
                active: isGradientTutorial,
                cs: cs,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GRADIENT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.0,
                          color: cs.outline,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(gradientCap, (i) {
                          final filled = i < currentNeuron.gradientLevel;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? cs.primary
                                    : cs.outlineVariant.withValues(alpha: 0.3),
                                border: Border.all(
                                  color:
                                      filled ? cs.primary : cs.outlineVariant,
                                  width: 1,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      if (!gradientMaxed)
                        Text(
                          'Cost: ${NumberFormatter.format(gradientCost)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.outline),
                        )
                      else
                        Text(
                          'MAX LEVEL',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (!gradientMaxed)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canAffordGradient
                                ? () {
                                    final ok = context
                                        .read<GameState>()
                                        .upgradeNeuronGradient(
                                            currentNeuron.id);
                                    if (!ok && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Not enough currency.')),
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              disabledBackgroundColor: cs.surfaceContainerHigh,
                              foregroundColor: cs.onPrimary,
                              disabledForegroundColor:
                                  cs.outline.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(2)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'UPGRADE GRADIENT',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Container(
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Activation function section ───────────────────────────────
              _buildSectionHighlight(
                active: isActivationTutorial,
                cs: cs,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVATION FUNCTION',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.0,
                          color: cs.outline,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: activationFunctions.map((fn) {
                          final selected = fn == selectedFn;
                          final cost =
                              state.neuronActivationCost(currentNeuron, fn);
                          final canAfford =
                              cost == BigInt.zero || state.number >= cost;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: selected
                                    ? null
                                    : () {
                                        if (!canAfford) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Not enough currency.')),
                                          );
                                          return;
                                        }
                                        context
                                            .read<GameState>()
                                            .changeNeuronActivation(
                                                currentNeuron.id, fn);
                                      },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? cs.primary.withValues(alpha: 0.1)
                                        : cs.surfaceContainerLow
                                            .withValues(alpha: 0.5),
                                    border: Border.all(
                                      color: selected
                                          ? cs.primary
                                          : canAfford
                                              ? cs.outlineVariant
                                              : cs.outlineVariant
                                                  .withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        fn.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: selected
                                              ? cs.primary
                                              : canAfford
                                                  ? cs.onSurface
                                                  : cs.outline,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                          fontSize: 8,
                                        ),
                                      ),
                                      if (!selected && cost > BigInt.zero)
                                        Text(
                                          NumberFormatter.format(cost),
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: cs.outline,
                                            fontSize: 7,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fnDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Strength contribution section ─────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STRENGTH CONTRIBUTION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 2.0,
                        color: cs.outline,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Raw',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.outline,
                                  fontSize: 9,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                neuronContribution.toStringAsFixed(2),
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontSize: 18, color: cs.primary),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Marginal Δstrength',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.outline,
                                  fontSize: 9,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+${marginalStrength.toStringAsFixed(4)}',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontSize: 18, color: cs.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activationMatchesPreferred
                          ? '× ${depthBonus.toStringAsFixed(2)} depth × ${preferredBonus.toStringAsFixed(2)} activation '
                              '(matches preferred $preferredFn for L$layerIndex)'
                          : '× ${depthBonus.toStringAsFixed(2)} depth × 1.00 activation '
                              '(L$layerIndex prefers ${preferredFn ?? '—'} for a ${((preferredBonus - 1) * 100).round()}% bonus)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.outline, height: 1.4),
                    ),
                  ],
                ),
              ),

              Container(
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Architecture section ──────────────────────────────────────
              _buildSectionHighlight(
                active: isBranchTutorial,
                cs: cs,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ARCHITECTURE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.0,
                          color: cs.outline,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildArchitectureBody(
                        context: context,
                        theme: theme,
                        cs: cs,
                        neuron: currentNeuron,
                        blockReason: blockReason,
                        canAffordBranch: canAffordBranch,
                        branchCost: branchCost,
                        activeLayerIdx: activeLayerIdx,
                        nextDeepGate: state.nextDeepLayerGate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
