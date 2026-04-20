import 'package:flutter/material.dart';

class FloatingTapText extends StatefulWidget {
  final String text;
  final Offset position;
  final VoidCallback onComplete;

  const FloatingTapText({
    super.key,
    required this.text,
    required this.position,
    required this.onComplete,
  });

  @override
  State<FloatingTapText> createState() => _FloatingTapTextState();
}

class _FloatingTapTextState extends State<FloatingTapText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _positionAnimation = Tween<Offset>(
      begin: widget.position,
      end: widget.position - const Offset(0, 50),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Text(
              widget.text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
