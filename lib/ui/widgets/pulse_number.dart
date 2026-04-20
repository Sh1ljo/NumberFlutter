import 'package:flutter/material.dart';
import '../../utils/number_formatter.dart';

class PulseNumber extends StatefulWidget {
  final BigInt value;
  final VoidCallback onTap;

  const PulseNumber({super.key, required this.value, required this.onTap});

  @override
  State<PulseNumber> createState() => PulseNumberState();
}

class PulseNumberState extends State<PulseNumber> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
               vsync: this, 
               duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    );
  }

  void pulse() {
    _controller.forward().then((_) => _controller.reverse());
  }

  void _handleTap() {
    widget.onTap();
    pulse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Text(
          NumberFormatter.format(widget.value),
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
