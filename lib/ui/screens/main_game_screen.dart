import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import '../../logic/game_state.dart';
import '../../logic/supabase_service.dart';
import '../widgets/pulse_number.dart';
import '../widgets/floating_tap_text.dart';
import '../widgets/profile_editor_dialog.dart';
import 'auth_screen.dart';
import 'player_stats_screen.dart';
import '../../utils/number_formatter.dart';
import '../../utils/haptic_feedback_engine.dart';

class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen>
    with SingleTickerProviderStateMixin {
  final List<FloatingTapText> _floatingTexts = [];
  final GlobalKey<PulseNumberState> _numberKey = GlobalKey();
  static const int _maxFloatingTexts = 18;

  final List<DateTime> _recentTaps = [];
  DateTime _lastWarningTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _profileActionBusy = false;
  late final AnimationController _screenShakeController;
  late Animation<Offset> _screenShakeOffset;

  @override
  void initState() {
    super.initState();
    _screenShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _screenShakeOffset = const AlwaysStoppedAnimation<Offset>(Offset.zero);
  }

  @override
  void dispose() {
    _screenShakeController.dispose();
    super.dispose();
  }

  void _removeFloatingTextByKey(Key key) {
    if (!mounted) return;
    setState(() {
      _floatingTexts.removeWhere((widget) => widget.key == key);
    });
  }

  void _onTapAnywhere(Offset globalPosition) {
    final now = DateTime.now();

    // Remove taps older than 1 second
    _recentTaps.removeWhere((tap) => now.difference(tap).inMilliseconds > 1000);
    if (_recentTaps.length >= 30) {
      if (now.difference(_lastWarningTime).inSeconds > 3) {
        _lastWarningTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("You really thought you could autoclick?... No chance"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    _recentTaps.add(now);

    final gameState = context.read<GameState>();
    _numberKey.currentState?.pulse();
    final clickResult = gameState.click();
    final hapticsEnabled = gameState.hapticPulseEnabled;
    final vibrationIntensity = gameState.vibrationIntensity;

    unawaited(HapticFeedbackEngine.playTap(
      enabled: hapticsEnabled,
      intensity: vibrationIntensity,
    ));
    if (clickResult.probabilityStrikeTriggered) {
      unawaited(HapticFeedbackEngine.playProbabilityStrike(
        enabled: hapticsEnabled,
        intensity: vibrationIntensity,
      ));
    }
    if (clickResult.personalBestReached) {
      unawaited(HapticFeedbackEngine.playPersonalBest(
        enabled: hapticsEnabled,
        intensity: vibrationIntensity,
      ));
      _triggerScreenShake(
        enabled: hapticsEnabled,
        intensity: vibrationIntensity,
      );
    }

    // Add floating text - optimized to avoid full setState
    if (_floatingTexts.length >= _maxFloatingTexts) {
      _floatingTexts.removeAt(0);
    }
    final text = '+${NumberFormatter.format(clickResult.gain)}';
    final floatingKey = UniqueKey();

    setState(() {
      _floatingTexts.add(
        FloatingTapText(
          key: floatingKey,
          text: text,
          isProbabilityStrike: clickResult.probabilityStrikeTriggered,
          position: globalPosition - const Offset(20, 20),
          onComplete: () {
            _removeFloatingTextByKey(floatingKey);
          },
        ),
      );
    });
  }

  void _triggerScreenShake({
    required bool enabled,
    required double intensity,
  }) {
    if (!enabled || intensity <= 0.0) return;
    final amplitude = lerpDouble(2.0, 8.0, intensity.clamp(0.0, 1.0)) ?? 4.0;
    _screenShakeOffset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: Offset(amplitude, -amplitude)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset(amplitude, -amplitude),
          end: Offset(-amplitude, amplitude * 0.75),
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset(-amplitude, amplitude * 0.75),
          end: Offset(amplitude * 0.45, -amplitude * 0.35),
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset(amplitude * 0.45, -amplitude * 0.35),
          end: Offset.zero,
        ),
        weight: 1.2,
      ),
    ]).animate(CurvedAnimation(
      parent: _screenShakeController,
      curve: Curves.easeOutCubic,
    ));
    _screenShakeController.forward(from: 0.0);
  }

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
      await ProfileEditorDialog.show(context);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: AnimatedBuilder(
              animation: _screenShakeController,
              builder: (context, child) {
                return Transform.translate(
                  offset: _screenShakeOffset.value,
                  child: child,
                );
              },
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
                                tooltip: 'Stats',
                                onPressed: _openStatsScreen,
                                icon: const Icon(Icons.bar_chart),
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
                              child: Selector<GameState, double>(
                                selector: (_, state) => state.totalIdleRate,
                                builder: (context, idleRate, child) {
                                  return Text(
                                    '+${NumberFormatter.formatDouble(idleRate)} / sec',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.5),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating texts overlay
          ..._floatingTexts,
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
