import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../logic/backend_service.dart';
import '../../logic/tutorial_step.dart';
import '../../models/neural_network.dart';
import '../../models/neural_skill.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import 'neural_network/neural_canvas.dart';
import 'neural_network/neural_unlock_screen.dart';
import 'neural_network/skills_view.dart';
import '../widgets/rolling_number_text.dart';
import '../widgets/leaderboard_button.dart';

class NeuralNetworkScreen extends StatefulWidget {
  final GlobalKey? neuralNeuronKey;
  final GlobalKey? neuralHudKey;
  final GlobalKey? skillsTabKey;
  final SkillTutorialKeys? skillKeys;

  const NeuralNetworkScreen({
    super.key,
    this.neuralNeuronKey,
    this.neuralHudKey,
    this.skillsTabKey,
    this.skillKeys,
  });

  @override
  State<NeuralNetworkScreen> createState() => _NeuralNetworkScreenState();
}

class _NeuralNetworkScreenState extends State<NeuralNetworkScreen>
    with SingleTickerProviderStateMixin {
  bool _profileActionBusy = false;

  // NETWORK | SKILLS. Content switches through an IndexedStack rather than a
  // TabBarView: a swipe between tabs would fight the canvas's own panning.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final gs = context.read<GameState>();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: gs.neuralSubTabIndex.clamp(0, 1),
    );
    _tabController.addListener(_handleSubTabChanged);
    if (gs.neuralSubTabIndex == NeuralSubTab.skills) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<GameState>().markSkillsSeen();
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleSubTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleSubTabChanged() {
    if (_tabController.indexIsChanging) return;
    context.read<GameState>().setNeuralSubTabIndex(_tabController.index);
    setState(() {});
  }

  void _openSkills() => _tabController.animateTo(NeuralSubTab.skills);

  /// A tutorial step whose target lives on the other tab brings the player
  /// there, the same way the Prestige screen follows its steps.
  void _followTutorialSubTab(int? wanted) {
    if (wanted == null || _tabController.index == wanted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tabController.index != wanted) {
        _tabController.animateTo(wanted);
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    _followTutorialSubTab(context.select<GameState, int?>(
        (gs) => specFor(gs.tutorialStep).requiredNeuralSubTab));
    final onSkills = _tabController.index == NeuralSubTab.skills;

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
                        const LeaderboardButton(tooltip: 'Ranks'),
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
                    onSkills
                        ? 'TEACH YOUR NETWORK A JOB'
                        : 'TAP A NEURON TO UPGRADE',
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

            // ── NETWORK | SKILLS ─────────────────────────────────────────
            TabBar(
              controller: _tabController,
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 2.0,
              ),
              labelColor: cs.primary,
              unselectedLabelColor: cs.outline,
              indicatorColor: cs.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 2,
              dividerColor: cs.outlineVariant.withValues(alpha: 0.3),
              tabs: [
                const Tab(text: 'NETWORK'),
                Tab(
                  key: widget.skillsTabKey,
                  child: Selector<GameState, (bool, bool)>(
                    selector: (_, gs) =>
                        (gs.skillsUnlocked, gs.hasUnseenSkills),
                    builder: (context, state, _) => _SkillsTabLabel(
                      unlocked: state.$1,
                      showBadge: state.$2,
                    ),
                  ),
                ),
              ],
            ),

            Expanded(
              // The canvas stays mounted so its pan and zoom survive a trip
              // to SKILLS; the Skills list is only built while on show.
              child: IndexedStack(
                index: _tabController.index,
                sizing: StackFit.expand,
                children: [
                  _buildNetworkTab(),
                  onSkills
                      ? SkillsView(tutorialKeys: widget.skillKeys)
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkTab() {
    // Deliberately two narrow Selectors rather than one Consumer.
    // The ticker calls notifyListeners() 10x/s, and a Consumer here
    // rebuilt the HUD *and* the entire canvas subtree every tick.
    return Selector<GameState, bool>(
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
            _SkillsStatusLine(onTap: _openSkills),
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
    );
  }
}

class _SkillsTabLabel extends StatelessWidget {
  final bool unlocked;
  final bool showBadge;

  const _SkillsTabLabel({required this.unlocked, required this.showBadge});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!unlocked) ...[
          const Icon(Icons.lock_outline, size: 12),
          const SizedBox(width: 6),
        ],
        const Text('SKILLS'),
        if (showBadge) ...[
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }
}

/// One line under the HUD: how far Skills are, or what is training. Tapping
/// it opens the SKILLS tab.
class _SkillsStatusLine extends StatelessWidget {
  final VoidCallback onTap;

  const _SkillsStatusLine({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = context.select<GameState, String>((gs) {
      if (!gs.skillsUnlocked) {
        final left = NeuralNetwork.pyramidLayerCount - gs.pyramidLayersBuilt;
        return 'SKILLS UNLOCK IN $left MORE '
            '${left == 1 ? 'LAYER' : 'LAYERS'} · '
            '${gs.pyramidLayersBuilt} / ${NeuralNetwork.pyramidLayerCount}';
      }
      final training = gs.skills.training;
      if (training == null) return 'SKILLS READY · PICK ONE TO TRAIN';
      final mastery = (gs.skillMastery(training) * 100).toStringAsFixed(1);
      return 'TRAINING ${NeuralSkills.def(training).name} · $mastery%';
    });
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.school_outlined, size: 14, color: cs.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.outline,
                  letterSpacing: 1.2,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: cs.outline),
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
