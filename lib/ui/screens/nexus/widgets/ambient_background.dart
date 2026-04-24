import 'package:flutter/material.dart';
import 'ambient_painter.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground();

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: AmbientPainter(
                progress: _controller.value,
                primary: theme.colorScheme.primary,
                surface: theme.colorScheme.surface,
                outline: theme.colorScheme.outline,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}
