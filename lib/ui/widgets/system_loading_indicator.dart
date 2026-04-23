import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded loading animation: pulsing bars + "LOADING" strip (same as app start).
///
/// [repeat] — `false` for a one-shot progress tied to [duration] (splash);
/// `true` for a looping animation while waiting on async work.
class SystemLoadingIndicator extends StatefulWidget {
  const SystemLoadingIndicator({
    super.key,
    this.repeat = false,
    this.duration = const Duration(milliseconds: 2500),
  });

  final bool repeat;
  final Duration duration;

  static const List<double> _bars = [0.26, 0.54, 0.82, 0.42, 0.68, 0.34];

  @override
  State<SystemLoadingIndicator> createState() => _SystemLoadingIndicatorState();
}

class _SystemLoadingIndicatorState extends State<SystemLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bars = SystemLoadingIndicator._bars;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                        final heightFactor =
                            (bars[index] + pulse * 0.20).clamp(0.18, 1.0);
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
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        if (widget.repeat)
          _buildLoadingStrip(theme)
        else
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => _buildLoadingStrip(theme),
          ),
      ],
    );
  }

  Widget _buildLoadingStrip(ThemeData theme) {
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
            child: widget.repeat
                ? LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  )
                : LinearProgressIndicator(
                    minHeight: 2,
                    value: _controller.value.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
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
