import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../logic/supabase_service.dart';
import '../../utils/number_formatter.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'auth_screen.dart';
import 'neural_network/neural_canvas.dart';
import 'neural_network/neural_unlock_screen.dart';

class NeuralNetworkScreen extends StatefulWidget {
  const NeuralNetworkScreen({super.key});

  @override
  State<NeuralNetworkScreen> createState() => _NeuralNetworkScreenState();
}

class _NeuralNetworkScreenState extends State<NeuralNetworkScreen> {
  bool _profileActionBusy = false;

  Future<void> _openProfileEditor() async {
    if (_profileActionBusy) return;
    final supabase = SupabaseService.instance;
    if (!supabase.isConfigured || !supabase.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Profile editing needs Supabase configured in assets/.env.'),
        ),
      );
      return;
    }

    setState(() {
      _profileActionBusy = true;
    });

    try {
      if (supabase.currentSession == null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        );
      }
      if (!mounted || supabase.currentSession == null) return;
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
                            return Text(
                              NumberFormatter.format(number),
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
              padding:
                  const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
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

            Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

            // ── Neural canvas (with loss HUD on top) ─────────────────────
            Expanded(
              child: Consumer<GameState>(
                builder: (context, state, _) {
                  if (!state.neuralNetwork.unlocked) {
                    return const NeuralUnlockScreen();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NeuralLossHud(state: state),
                      Expanded(
                        child: NeuralCanvas(network: state.neuralNetwork),
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
class _NeuralLossHud extends StatelessWidget {
  const _NeuralLossHud({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accuracyPct = state.neuralNetwork.accuracy * 100.0;
    final multiplier = state.neuralLossMultiplier;
    final decay = state.neuralDecayRate;
    // Soft cap is binding when the effective multiplier is strictly less
    // than the raw (uncapped) one — i.e. the prestigeCount-based cap is
    // currently clamping the boost.
    final softCapHit = multiplier < state.neuralLossRawMultiplier;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
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
                softCapHit
                    ? 'MULT × (capped)'
                    : 'MULT ×',
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
    );
  }
}
