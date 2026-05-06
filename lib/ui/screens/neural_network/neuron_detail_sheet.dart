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

  static void show(BuildContext context, NeuralNeuron neuron) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NeuronDetailSheet(neuron: neuron),
    );
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
    )..repeat(reverse: true);
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
                ? 'The pyramid is fully expanded — no more layers can be added.'
                : 'This neuron sits at a position that does not branch in the pyramid.',
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

    return Consumer<GameState>(
      builder: (context, state, _) {
        final currentNeuron =
            state.neuralNetwork.findNeuron(widget.neuron.id);
        if (currentNeuron == null) {
          Navigator.of(context).pop();
          return const SizedBox.shrink();
        }

        final gradientCost = currentNeuron.gradientUpgradeCost;
        final canAffordGradient =
            !currentNeuron.isGradientMaxed && state.number >= gradientCost;

        final canBranch =
            state.neuralNetwork.canNeuronBranch(currentNeuron.id);
        final blockReason =
            state.neuralNetwork.branchBlockReason(currentNeuron.id);
        final branchCost =
            state.neuralNetwork.addLayerCost(state.neuralNetwork.layers.length);
        final canAffordBranch = canBranch && state.number >= branchCost;
        final activeLayerIdx = state.neuralNetwork.activeExpansionLayerIndex;

        final selectedFn = currentNeuron.activationFn;
        final fnDescription = activationFunctionDescriptions[selectedFn] ?? '';

        final layer =
            state.neuralNetwork.findNeuronLayer(currentNeuron.id);
        final layerIndex = layer?.index ?? 0;
        final preferredFn = preferredActivationByLayer[layerIndex];
        final activationMatchesPreferred =
            preferredFn != null && currentNeuron.activationFn == preferredFn;
        final depthBonus = 1.0 + 0.25 * layerIndex;
        final activationBonus = activationMatchesPreferred ? 1.10 : 1.0;
        final neuronContribution =
            (currentNeuron.gradientLevel + 1) * depthBonus * activationBonus;
        final networkStrength = state.neuralNetwork.computeStrength();
        double sumContributions = 0.0;
        for (final l in state.neuralNetwork.layers) {
          final db = 1.0 + 0.25 * l.index;
          final pf = preferredActivationByLayer[l.index];
          for (final n in l.neurons) {
            final ab = (pf != null && n.activationFn == pf) ? 1.10 : 1.0;
            sumContributions += (n.gradientLevel + 1) * db * ab;
          }
        }
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

        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            border:
                Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
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
                            color: cs.primary
                                .withValues(alpha: 0.55 + t * 0.45),
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
                      child: Icon(Icons.hub_outlined,
                          color: cs.primary, size: 22),
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
                            currentNeuron.id
                                .replaceAll('_', ' ')
                                .toUpperCase(),
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
                        'GR ${currentNeuron.gradientLevel}/5',
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
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Gradient section ─────────────────────────────────────────
              _buildSectionHighlight(
                active: isGradientTutorial,
                cs: cs,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
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
                        children: List.generate(5, (i) {
                          final filled = i < currentNeuron.gradientLevel;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? cs.primary
                                    : cs.outlineVariant
                                        .withValues(alpha: 0.3),
                                border: Border.all(
                                  color: filled
                                      ? cs.primary
                                      : cs.outlineVariant,
                                  width: 1,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      if (!currentNeuron.isGradientMaxed)
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
                      if (!currentNeuron.isGradientMaxed)
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Activation function section ───────────────────────────────
              _buildSectionHighlight(
                active: isActivationTutorial,
                cs: cs,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
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
                          final cost = currentNeuron.activationChangeCost(fn);
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
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
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
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3)),

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
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 18, color: cs.primary),
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
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 18, color: cs.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activationMatchesPreferred
                          ? '× ${depthBonus.toStringAsFixed(2)} depth × 1.10 activation '
                              '(matches preferred $preferredFn for L$layerIndex)'
                          : '× ${depthBonus.toStringAsFixed(2)} depth × 1.00 activation '
                              '(L$layerIndex prefers ${preferredFn ?? '—'} for a 10% bonus)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.outline, height: 1.4),
                    ),
                  ],
                ),
              ),

              Container(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Architecture section ──────────────────────────────────────
              _buildSectionHighlight(
                active: isBranchTutorial,
                cs: cs,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
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
