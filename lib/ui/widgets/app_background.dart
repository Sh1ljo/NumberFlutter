import 'package:flutter/material.dart';

/// Shared radial background used across tab screens (matches main game).
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  static const BoxDecoration gradientDecoration = BoxDecoration(
    gradient: RadialGradient(
      colors: [Color(0xFF1B1B1B), Color(0xFF131313)],
      radius: 1.0,
      center: Alignment.center,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: gradientDecoration),
        child,
      ],
    );
  }
}
