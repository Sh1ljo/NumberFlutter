import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../logic/backend_service.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'auth_screen.dart';
import 'neural_network/neural_canvas.dart';
import 'neural_network/neural_unlock_screen.dart';
import '../widgets/rolling_number_text.dart';

class NeuralNetworkScreen extends StatefulWidget {
  final GlobalKey? neuralNeuronKey;
  final GlobalKey? neuralHudKey;

  const NeuralNetworkScreen({
    super.key,
    this.neuralNeuronKey,
    this.neuralHudKey,
  });

  @override
  State<NeuralNetworkScreen> createState() => _NeuralNetworkScreenState();
}

class _NeuralNetworkScreenState extends State<NeuralNetworkScreen> {
  bool _profileActionBusy = false;

  Future<void> _openProfileEditor() async {
    if (_profileActionBusy) return;
    final backend = BackendService.instance;
    if (!backend.isConfigured || !backend.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile editing needs a connection to the cloud.'),
        ),
      );
      return;
    }

    setState(() {
      _profileActionBusy = true;
    });

    try {
      if (!backend.isSignedIn) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        );
      }
      if (!mounted || !backend.isSignedIn) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _profileActionBusy = false;
        });
      }
    }
  }

  Future<void> _openLeaderboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.toll, color: cs.primary),
                        const SizedBox(width: 8),
                        Selector<GameState, BigInt>(
                          selector: (_, state) => state.number,
                          builder: (context, number, child) {
                            return RollingNumberText(
                              value: number,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontSize: 24),
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Ranks',
                          onPressed: _openLeaderboard,
                          icon: const Icon(Icons.emoji_events_outlined),
                        ),
                        IconButton(
                          tooltip: 'Profile',
                          onPressed: _openProfileEditor,
                          icon: const Icon(Icons.account_circle_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 2, color: cs.surfaceContainerLow),

            // ── Title ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEURAL',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 42),
                  ),
                  Text(
                    'NETWORK',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 42,
                      color: cs.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TAP A NEURON TO UPGRADE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 2.0,
                      color: cs.outlineVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            Container(
                height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

            // ── Neural canvas (with loss HUD on top) ─────────────────────
            Expanded(
              // Deliberately two narrow Selectors rather than one Consumer.
              // The ticker calls notifyListeners() 10x/s, and a Consumer here
              // rebuilt the HUD *and* the entire canvas subtree every tick.
              child: Selector<GameState, bool>(
                selector: (_, state) => state.neuralNetwork.unlocked,
                builder: (context, unlocked, _) {
                  if (!unlocked) return const NeuralUnlockScreen();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Selector<GameState, double>(
                        // Loss is what the HUD renders; rebuild on it alone.
                        selector: (_, state) => state.neuralNetwork.loss,
                        builder: (context, _, __) => _NeuralLossHud(
                          key: widget.neuralHudKey,
                          state: context.read<GameState>(),
                        ),
                      ),
                      Expanded(
                        // The canvas only cares about topology, which changes
                        // on branch/upgrade — not on every loss tick.
                        child: Selector<GameState, (Object, int)>(
                          selector: (_, state) => state.neuralTopologyKey,
                          builder: (context, _, __) => NeuralCanvas(
                            network: context.read<GameState>().neuralNetwork,
                            neuralNeuronKey: widget.neuralNeuronKey,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact HUD that surfaces the live network training metrics:
///   - Accuracy% (1 - loss) — the headline number a player chases.
///   - Multiplier — the gain boost the network is currently granting.
///   - Decay rate — k * strength, so players see *why* upgrades help.
///
/// Rebuilds every tick because the parent `Consumer` of [GameState] rebuilds
/// when the ticker calls notifyListeners().
class _NeuralLossHud extends StatefulWidget {
  const _NeuralLossHud({super.key, required this.state});

  final GameState state;

  @override
  State<_NeuralLossHud> createState() => _NeuralLossHudState();
}

class _NeuralLossHudState extends State<_NeuralLossHud> {
  static const double _emaAlpha = 0.22;
  late double _smoothedAccuracyPct;

  @override
  void initState() {
    super.initState();
    _smoothedAccuracyPct = widget.state.neuralNetwork.accuracy * 100.0;
  }

  @override
  void didUpdateWidget(covariant _NeuralLossHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextAccuracyPct = widget.state.neuralNetwork.accuracy * 100.0;
    _smoothedAccuracyPct = (_smoothedAccuracyPct * (1.0 - _emaAlpha)) +
        (nextAccuracyPct * _emaAlpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accuracyPct = _smoothedAccuracyPct;
    final multiplier = widget.state.neuralLossMultiplier;
    final decay = widget.state.neuralDecayRate;
    // Soft cap is binding when the effective multiplier is strictly less
    // than the raw (uncapped) one — i.e. the prestigeCount-based cap is
    // currently clamping the boost.
    final softCapHit = multiplier < widget.state.neuralLossRawMultiplier;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCURACY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 2.0,
                        color: cs.outlineVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${accuracyPct.toStringAsFixed(2)}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    softCapHit ? 'MULT × (capped)' : 'MULT ×',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      color: cs.outlineVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    multiplier.toStringAsFixed(2),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'decay ${decay.toStringAsFixed(5)}/s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EpochStrip(state: widget.state),
        ],
      ),
    );
  }
}

/// Epoch count plus, once the network has converged, the button that sends
/// it into its next Epoch.
class _EpochStrip extends StatelessWidget {
  const _EpochStrip({required this.state});

  final GameState state;

  Future<void> _confirm(BuildContext context) async {
    final next = state.neuralNetwork.epochs + 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('BEGIN EPOCH $next?'),
        content: const Text(
          'Training restarts from zero and every gradient level resets. '
          'Your topology and activations stay.\n\n'
          'Permanently gain: +10% all production, +1 max gradient level, '
          'and a higher multiplier cap. Each Epoch trains 15% slower.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('BEGIN'),
          ),
        ],
      ),
    );
    if (ok == true) state.startEpoch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final epochs = state.neuralNetwork.epochs;
    final canStart = state.canStartEpoch;
    return Row(
      children: [
        Expanded(
          child: Text(
            epochs == 0
                ? 'EPOCH 0 · converge below 1% loss to begin an Epoch'
                : 'EPOCH $epochs · ×${state.epochProductionMultiplier.toStringAsFixed(1)} production',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.outline,
              letterSpacing: 1.2,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (canStart)
          OutlinedButton(
            onPressed: () => _confirm(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'BEGIN EPOCH',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  fontSize: 10),
            ),
          ),
      ],
    );
  }
}
