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
  static const int _maxFloatingTexts = 18;

  final List<DateTime> _recentTaps = [];
  DateTime _lastWarningTime = DateTime.fromMillisecondsSinceEpoch(0);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
                            Icon(Icons.toll, color: theme.colorScheme.primary),
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
                      ],
                    ),
                  ),
                ),
                Container(
                    height: 2, color: theme.colorScheme.surfaceContainerLow),
                
                // Momentum bar with granular listening
                Selector<GameState, ({bool show, double progress, double multiplier})>(
                  selector: (_, state) => (
                    show: state.hasMomentumUpgrade,
                    progress: state.momentumProgress,
                    multiplier: state.momentumMultiplier,
                  ),
                  builder: (context, data, child) {
                    if (!data.show) return const SizedBox.shrink();
                    return RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 6.0),
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
                  child: FractionallySizedBox(
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
