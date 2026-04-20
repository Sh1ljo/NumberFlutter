import 'package:flutter/material.dart';
import 'dart:math' as math;

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bars = [0.26, 0.54, 0.82, 0.42, 0.68, 0.34];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NUMBER',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 52,
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'INITIALIZING SYSTEM',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 2.0,
                color: theme.colorScheme.outline.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 64),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SizedBox(
                  width: 208,
                  height: 72,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.55),
                          ),
                          color: theme.colorScheme.surfaceContainerLow
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(bars.length, (index) {
                            final phase = _controller.value * 10 * math.pi;
                            final pulse = math.sin(phase - (index * 0.65));
                            final heightFactor = (bars[index] + pulse * 0.20)
                                .clamp(0.18, 1.0);
                            final opacity = (0.45 + (pulse + 1) * 0.275)
                                .clamp(0.2, 1.0);
                            return Container(
                              width: 16,
                              height: 44 * heightFactor,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            );
                          }),
                        ),
                      ),
                      Positioned(
                        left: (_controller.value * 252) - 44,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  theme.colorScheme.primary
                                      .withValues(alpha: 0.0),
                                  theme.colorScheme.primary
                                      .withValues(alpha: 0.14),
                                  theme.colorScheme.primary
                                      .withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return _buildLoadingDots(theme);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots(ThemeData theme) {
    final progress = _controller.value.clamp(0.0, 1.0);
    return SizedBox(
      width: 208,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'LOADING',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                letterSpacing: 2.4,
                color: theme.colorScheme.outline.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 2,
              value: progress,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
