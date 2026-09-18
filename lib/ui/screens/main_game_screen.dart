import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../logic/game_state.dart';
import '../../logic/backend_service.dart';
import '../widgets/ambient_gradient_background.dart';
import '../widgets/neural_spark.dart';
import '../widgets/pulse_number.dart';
import '../widgets/floating_tap_text.dart';
import '../widgets/profile_editor_dialog.dart';
import '../widgets/tap_ripple_effect.dart';
import 'auth_screen.dart';
import 'player_stats_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import '../../utils/number_formatter.dart';
class MainGameScreen extends StatefulWidget {
  final GlobalKey? tapAreaKey;

  /// Spotlight target for the `demonstrateMomentum` tutorial step.
  final GlobalKey? momentumBarKey;

  const MainGameScreen({super.key, this.tapAreaKey, this.momentumBarKey});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  final GlobalKey<FloatingTapTextLayerState> _floatingLayerKey = GlobalKey();
  final GlobalKey<TapRippleLayerState> _rippleLayerKey = GlobalKey();
  final GlobalKey<PulseNumberState> _numberKey = GlobalKey();
  final GlobalKey _rootStackKey = GlobalKey();

  final List<DateTime> _recentTaps = [];
  DateTime _lastWarningTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _profileActionBusy = false;

  // ── Neural Spark tap-bonus minigame ─────────────────────────────────────
  final math.Random _sparkRng = math.Random();
  Timer? _sparkSpawnTimer;
  Offset? _sparkPosition;
  Key _sparkKey = UniqueKey();
  static const Duration _sparkLifetime = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _scheduleNextSpark();
  }

  @override
  void dispose() {
    _sparkSpawnTimer?.cancel();
    super.dispose();
  }

  void _scheduleNextSpark() {
    _sparkSpawnTimer?.cancel();
    // Randomized so the spawn never feels like a metronome.
    final delaySeconds = 10 + _sparkRng.nextInt(11); // 10..20s
    _sparkSpawnTimer = Timer(Duration(seconds: delaySeconds), _trySpawnSpark);
  }

  /// The tap Listener's live bounds, expressed in the root Stack's local
  /// coordinate space, so a spark can be placed anywhere inside it
  /// regardless of safe-area insets or the nav bar's reserved space.
  Rect? _tapAreaRectInStack() {
    final tapBox =
        widget.tapAreaKey?.currentContext?.findRenderObject() as RenderBox?;
    final stackBox =
        _rootStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (tapBox == null ||
        stackBox == null ||
        !tapBox.hasSize ||
        !stackBox.attached) {
      return null;
    }
    final topLeft = stackBox.globalToLocal(tapBox.localToGlobal(Offset.zero));
    return topLeft & tapBox.size;
  }

  void _trySpawnSpark() {
    if (!mounted) return;
    final rect = _tapAreaRectInStack();
    const margin = 40.0;
    if (rect == null ||
        rect.width < margin * 2 + 40 ||
        rect.height < margin * 2 + 40) {
      // Tap area isn't laid out yet, or is unusually small — skip this
      // spawn and let the next scheduled attempt retry.
      _scheduleNextSpark();
      return;
    }

    final usableWidth = rect.width - margin * 2;
    final usableHeight = rect.height - margin * 2;
    final center = rect.center;
    Offset position;
    var attempts = 0;
    do {
      position = Offset(
        rect.left + margin + _sparkRng.nextDouble() * usableWidth,
        rect.top + margin + _sparkRng.nextDouble() * usableHeight,
      );
      attempts++;
      // Steer away from dead-center so it doesn't spawn right on the number.
    } while ((position - center).distance < 90 && attempts < 6);

    setState(() {
      _sparkPosition = position;
      _sparkKey = UniqueKey();
    });
  }

  void _onSparkExpired() {
    if (!mounted) return;
    setState(() => _sparkPosition = null);
    _scheduleNextSpark();
  }

  void _onSparkCaught() {
    if (!mounted) return;
    setState(() => _sparkPosition = null);
    context.read<GameState>().activateNeuralSparkBoost();
    _scheduleNextSpark();
  }

  void _onTapAnywhere(Offset globalPosition) {
    final now = DateTime.now();

    // Remove taps older than 1 second
    _recentTaps.removeWhere((tap) => now.difference(tap).inMilliseconds > 1000);
    if (_recentTaps.length >= 30) {
      return;
    }
    _recentTaps.add(now);

    final gameState = context.read<GameState>();
    _numberKey.currentState?.pulse();
    final clickResult = gameState.click();

    // Only the particle/ripple layers rebuild; this screen used to setState
    // (and rebuild every header, bar and Selector) on each tap and each
    // particle finishing.
    _floatingLayerKey.currentState?.add(
      text: '+${NumberFormatter.format(clickResult.gain)}',
      isProbabilityStrike: clickResult.probabilityStrikeTriggered,
      position: globalPosition - const Offset(20, 20),
    );
    _rippleLayerKey.currentState?.add(globalPosition);
  }

  Future<void> _openProfileEditor() async {
    if (_profileActionBusy) return;
    final backend = BackendService.instance;
    if (!backend.isConfigured || !backend.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Profile editing needs a connection to the cloud.'),
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

  Future<void> _openStatsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayerStatsScreen()),
    );
  }

  Future<void> _openLeaderboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        key: _rootStackKey,
        children: [
          const AmbientGradientBackground(),
          SafeArea(
            child: Column(
                children: [
                  // Header with granular listening
                  RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.toll,
                                  color: theme.colorScheme.primary),
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
                  Container(
                      height: 2, color: theme.colorScheme.surfaceContainerLow),

                  // Momentum bar with granular listening
                  Selector<GameState,
                      ({bool show, double progress, double multiplier})>(
                    selector: (_, state) => (
                      show: state.hasMomentumUpgrade,
                      progress: state.momentumProgress,
                      multiplier: state.momentumMultiplier,
                    ),
                    builder: (context, data, child) {
                      if (!data.show) return const SizedBox.shrink();
                      return RepaintBoundary(
                        child: Padding(
                          key: widget.momentumBarKey,
                          padding:
                              const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 6.0),
                          child: _MomentumProgressBar(
                            progress: data.progress,
                            multiplier: data.multiplier,
                          ),
                        ),
                      );
                    },
                  ),

                  // Main tap area
                  Expanded(
                    child: Listener(
                      key: widget.tapAreaKey,
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) => _onTapAnywhere(event.position),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CURRENT NUMBER',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(letterSpacing: 4.0),
                            ),
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              child: Selector<GameState, BigInt>(
                                selector: (_, state) => state.number,
                                builder: (context, number, child) {
                                  return PulseNumber(
                                    key: _numberKey,
                                    value: number,
                                    onTap: () {},
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 48),
                            RepaintBoundary(
                              child: Selector<GameState, ({double auto, double total})>(
                                selector: (_, state) => (
                                  auto: state.autoClickRate,
                                  total: state.totalIdleRate,
                                ),
                                builder: (context, rates, child) {
                                  final shownRate =
                                      rates.total > 0 ? rates.total : 0.0;
                                  return Text(
                                    '+${NumberFormatter.formatDouble(shownRate)} / sec',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.5),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Selector<GameState, bool>(
                              selector: (_, state) =>
                                  state.isNeuralSparkBoostActive,
                              builder: (context, active, child) {
                                if (!active) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'NEURAL BOOST ACTIVE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      letterSpacing: 2.0,
                                      color: NeuralSpark.glowColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Selector<GameState,
                                ({bool show, bool active, bool cooling})>(
                              selector: (_, s) => (
                                show: s.canActivateTemporalCollapse ||
                                    s.isTemporalCollapseActive ||
                                    s.isTemporalCollapseCoolingDown,
                                active: s.isTemporalCollapseActive,
                                cooling: s.isTemporalCollapseCoolingDown,
                              ),
                              builder: (context, data, child) {
                                if (!data.show) return const SizedBox.shrink();
                                return _TemporalCollapseButton(
                                  active: data.active,
                                  coolingDown: data.cooling,
                                  onTap: () => context
                                      .read<GameState>()
                                      .activateTemporalCollapse(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),

          // Tap ripples, then floating texts, so gain numbers stay legible.
          Positioned.fill(child: TapRippleLayer(key: _rippleLayerKey)),
          Positioned.fill(child: FloatingTapTextLayer(key: _floatingLayerKey)),

          if (_sparkPosition != null)
            Positioned(
              left: _sparkPosition!.dx - (NeuralSpark.diameter + 20) / 2,
              top: _sparkPosition!.dy - (NeuralSpark.diameter + 20) / 2,
              child: NeuralSpark(
                key: _sparkKey,
                lifetime: _sparkLifetime,
                onCaught: _onSparkCaught,
                onExpire: _onSparkExpired,
              ),
            ),
        ],
      ),
    );
  }
}

class _MomentumProgressBar extends StatelessWidget {
  final double progress;
  final double multiplier;

  const _MomentumProgressBar({
    required this.progress,
    required this.multiplier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MOMENTUM  x${multiplier.toStringAsFixed(2)}',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: normalizedProgress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemporalCollapseButton extends StatelessWidget {
  final bool active;
  final bool coolingDown;
  final VoidCallback onTap;

  const _TemporalCollapseButton({
    required this.active,
    required this.coolingDown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color;
    final String label;
    if (active) {
      color = Colors.deepPurple;
      label = 'COLLAPSING…';
    } else if (coolingDown) {
      color = Colors.grey;
      label = 'TEMPORAL COLLAPSE (cooldown)';
    } else {
      color = Colors.deepPurpleAccent;
      label = 'TEMPORAL COLLAPSE';
    }

    return GestureDetector(
      onTap: (active || coolingDown) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 0.3 : 0.15),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
