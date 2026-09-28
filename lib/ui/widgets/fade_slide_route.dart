import 'package:flutter/material.dart';

/// A full-screen route that fades in while rising a few pixels, and plays
/// the same motion backwards on pop.
///
/// The platform default (Android's zoom transition) scales the whole page
/// from 85%, which reads as a jump on screens with their own dark
/// background; a short fade + lift keeps the motion continuous.
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  FadeSlideRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
