import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../utils/number_formatter.dart';

/// Shows a live [BigInt] that rolls smoothly between updates instead of
/// stepping.
///
/// The game loop moves the number 10 times a second on a timer that isn't
/// aligned with the display, so the counter used to jump in uneven steps.
/// Here each new value is tweened from whatever is on screen over a bit more
/// than one game tick, so consecutive ticks blend into one continuous roll.
/// It never overshoots the real number, and a drop (a purchase) snaps
/// straight to the new value.
///
/// The text only rebuilds when the formatted string actually changes, and
/// the frame callback stops as soon as a roll finishes.
class RollingNumberText extends StatefulWidget {
  const RollingNumberText({
    super.key,
    required this.value,
    this.style,
    this.maxLines,
    this.softWrap,
    this.overflow,
  });

  final BigInt value;
  final TextStyle? style;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;

  /// Slightly longer than the 100ms game tick, so the next update normally
  /// arrives mid-roll and is picked up without a visible pause.
  static const Duration rollDuration = Duration(milliseconds: 130);

  static String format(BigInt value) =>
      NumberFormatter.format(value, fixedDecimals: true);

  @override
  State<RollingNumberText> createState() => _RollingNumberTextState();
}

class _RollingNumberTextState extends State<RollingNumberText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  late BigInt _shown;
  late BigInt _from;
  late BigInt _to;
  late String _text;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    // Not lazy field initializers: those would first run inside
    // didUpdateWidget and pick up the *new* value.
    _shown = _from = _to = widget.value;
    _text = RollingNumberText.format(widget.value);
  }

  @override
  void didUpdateWidget(RollingNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.value;
    if (target == _to) return;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (target < _shown || reduceMotion) {
      _snapTo(target);
      return;
    }
    _from = _shown;
    _to = target;
    // Restarting keeps one ticker; elapsed resets to zero on the next frame.
    _ticker.stop();
    _ticker.start();
  }

  void _snapTo(BigInt value) {
    _ticker.stop();
    _from = value;
    _to = value;
    _shown = value;
    // Called from didUpdateWidget, which is followed by a build anyway.
    _text = RollingNumberText.format(value);
  }

  void _onFrame(Duration elapsed) {
    final t = elapsed.inMicroseconds /
        RollingNumberText.rollDuration.inMicroseconds;
    if (t >= 1.0) {
      _shown = _to;
      _ticker.stop();
    } else {
      // Linear, so back-to-back ticks join at a constant speed.
      const scale = 10000;
      _shown = _from +
          (_to - _from) * BigInt.from((t * scale).round()) ~/
              BigInt.from(scale);
    }
    final next = RollingNumberText.format(_shown);
    if (next != _text) setState(() => _text = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      style: widget.style,
      maxLines: widget.maxLines,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
    );
  }
}
