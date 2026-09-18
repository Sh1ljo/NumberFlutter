import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded loading animation: pulsing bars + "LOADING" strip.
///
/// The bars always loop to show activity. [progress] (0..1) drives the strip
/// with real progress, easing between updates; leave it null for an
/// indeterminate strip while waiting on work of unknown length.
class SystemLoadingIndicator extends StatefulWidget {
  const SystemLoadingIndicator({
    super.key,
    this.progress,
    this.label = 'LOADING',
  });

  final double? progress;
  final String label;

  static const List<double> _bars = [0.26, 0.54, 0.82, 0.42, 0.68, 0.34];

  /// How long the strip takes to ease to a new [progress] value.
  static const Duration progressEase = Duration(milliseconds: 300);

  @override
  State<SystemLoadingIndicator> createState() => _SystemLoadingIndicatorState();
}

class _SystemLoadingIndicatorState extends State<SystemLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat();

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
                        return SizedBox(
                          width: 16,
                          height: 44,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 16,
                              height: 44 * heightFactor,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
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
        _buildLoadingStrip(theme),
      ],
    );
  }

  Widget _buildLoadingStrip(ThemeData theme) {
    final progress = widget.progress;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 9,
      letterSpacing: 2.4,
      color: theme.colorScheme.outline.withValues(alpha: 0.8),
    );
    final background =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final foreground = AlwaysStoppedAnimation<Color>(theme.colorScheme.primary);

    return SizedBox(
      width: 208,
      child: progress == null
          ? Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.label, style: labelStyle),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: background,
                    valueColor: foreground,
                  ),
                ),
              ],
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(end: progress.clamp(0.0, 1.0)),
              duration: SystemLoadingIndicator.progressEase,
              curve: Curves.easeOut,
              builder: (context, value, _) => Column(
                children: [
                  Row(
                    children: [
                      Text(widget.label, style: labelStyle),
                      const Spacer(),
                      Text('${(value * 100).round()}%', style: labelStyle),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      value: value,
                      backgroundColor: background,
                      valueColor: foreground,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
