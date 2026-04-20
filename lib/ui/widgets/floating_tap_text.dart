import 'package:flutter/material.dart';

class FloatingTapText extends StatefulWidget {
  final String text;
  final Offset position;
  final VoidCallback onComplete;
  final bool isProbabilityStrike;

  const FloatingTapText({
    super.key,
    required this.text,
    required this.position,
    required this.onComplete,
    this.isProbabilityStrike = false,
  });

  @override
  State<FloatingTapText> createState() => _FloatingTapTextState();
}

class _FloatingTapTextState extends State<FloatingTapText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isProbabilityStrike ? 760 : 680),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 45),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _positionAnimation = Tween<Offset>(
      begin: widget.position,
      end:
          widget.position - Offset(0, widget.isProbabilityStrike ? 72.0 : 52.0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
            begin: 0.92, end: widget.isProbabilityStrike ? 1.26 : 1.08),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
            begin: widget.isProbabilityStrike ? 1.26 : 1.08, end: 1.0),
        weight: 65,
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCrit = widget.isProbabilityStrike;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.text,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isCrit
                      ? const Color(0xFFFFD166)
                      : theme.colorScheme.primary,
                  fontSize: isCrit ? 34 : 24,
                  fontWeight: isCrit ? FontWeight.w700 : FontWeight.w500,
                  shadows: isCrit
                      ? const [
                          Shadow(
                            color: Color(0x66FFD166),
                            blurRadius: 16,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
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
