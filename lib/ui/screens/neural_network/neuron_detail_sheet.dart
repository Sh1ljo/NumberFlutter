import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import '../../../models/neural_network.dart';
import '../../../utils/number_formatter.dart';

class NeuronDetailSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer<GameState>(
      builder: (context, state, _) {
        final currentNeuron = state.neuralNetwork.findNeuron(neuron.id);
        if (currentNeuron == null) {
          Navigator.of(context).pop();
          return const SizedBox.shrink();
        }

        final gradientCost = currentNeuron.gradientUpgradeCost;
        final canAffordGradient =
            !currentNeuron.isGradientMaxed && state.number >= gradientCost;
        final layerCost =
            state.neuralNetwork.addLayerCost(state.neuralNetwork.layers.length);
        final canAffordLayer = state.number >= layerCost;

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
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Gradient section ─────────────────────────────────────────
              Padding(
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
                    // Level dots
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
                                  : cs.outlineVariant.withValues(alpha: 0.3),
                              border: Border.all(
                                color: filled ? cs.primary : cs.outlineVariant,
                                width: 1,
                              ),
                            ),
                          ),
                        );
                      }),
                      // Remaining text
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
                                      .upgradeNeuronGradient(currentNeuron.id);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Not enough currency.')),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            disabledBackgroundColor:
                                cs.surfaceContainerHigh,
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

              Container(
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Activation function section ───────────────────────────────
              Padding(
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
                        final selected = fn == currentNeuron.activationFn;
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
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
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
                  ],
                ),
              ),

              Container(
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

              // ── Architecture section ──────────────────────────────────────
              Padding(
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adds 2 neurons to a new hidden layer on the right',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.outline),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Cost: ${NumberFormatter.format(layerCost)}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: canAffordLayer
                              ? () {
                                  final ok = context
                                      .read<GameState>()
                                      .addNeuralLayer();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    if (!ok) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Not enough currency.')),
                                      );
                                    }
                                  }
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            disabledForegroundColor:
                                cs.outline.withValues(alpha: 0.5),
                            side: BorderSide(
                              color: canAffordLayer
                                  ? cs.primary
                                  : cs.outlineVariant,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            'ADD LAYER',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
