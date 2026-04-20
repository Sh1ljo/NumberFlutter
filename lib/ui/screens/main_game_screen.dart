import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../widgets/pulse_number.dart';
import '../widgets/floating_tap_text.dart';
import '../../utils/number_formatter.dart';

class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  final List<FloatingTapText> _floatingTexts = [];
  final GlobalKey<PulseNumberState> _numberKey = GlobalKey();

  final List<DateTime> _recentTaps = [];
  DateTime _lastWarningTime = DateTime.fromMillisecondsSinceEpoch(0);

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
      return; // Throttle to max 30 CPS
    }
    _recentTaps.add(now);

    final gameState = context.read<GameState>();
    _numberKey.currentState?.pulse();
    final clickResult = gameState.click();

    // Add floating text
    setState(() {
      final text = '+${NumberFormatter.format(clickResult.gain)}';

      _floatingTexts.add(
        FloatingTapText(
          key: UniqueKey(),
          text: text,
          isProbabilityStrike: clickResult.probabilityStrikeTriggered,
          position: globalPosition -
              const Offset(
                  20, 20), // offset lightly so it spawns roughly near finger
          onComplete: () {
            // Wait a bit before cleaning up to avoid concurrent modification during build if many are completing
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  // We remove the oldest that match (assuming it might be this one)
                  if (_floatingTexts.isNotEmpty) {
                    _floatingTexts.removeAt(0);
                  }
                });
              }
            });
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Consumer<GameState>(
            builder: (context, state, child) {
              final theme = Theme.of(context);
              return SafeArea(
                child: Column(
                  children: [
                    // Header (mocked based on HTML)
                    Padding(
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
                              Text(
                                NumberFormatter.format(state.number),
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontSize: 24),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                        height: 2,
                        color: theme.colorScheme.surfaceContainerLow),
                    if (state.hasMomentumUpgrade)
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 6.0),
                        child: _MomentumProgressBar(
                          progress: state.momentumProgress,
                          multiplier: state.momentumMultiplier,
                        ),
                      ),

                    // Main Area
                    Expanded(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) =>
                            _onTapAnywhere(event.position),
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
                              PulseNumber(
                                key: _numberKey,
                                value: state.number,
                                onTap:
                                    () {}, // Tap handled by the parent GestureDetector now
                              ),
                              const SizedBox(height: 48),
                              Text(
                                '+${NumberFormatter.formatDouble(state.totalIdleRate)} / sec',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.5),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
    final multiplierProgress =
        ((multiplier - 1.0).clamp(0.0, 1.0) as num).toDouble();
    final rawProgress = (progress.clamp(0.0, 1.0) as num).toDouble();
    final normalized =
        rawProgress > multiplierProgress ? rawProgress : multiplierProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MOMENTUM  x${multiplier.toStringAsFixed(2)}',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: theme.colorScheme.primary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOutCubic,
                    widthFactor: normalized,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.75),
                            theme.colorScheme.primary,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
