import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One card of a [GuideOverlay] walkthrough.
class GuideStep {
  final String title;
  final String body;
  final IconData? icon;

  /// Widget to spotlight. The card sits centred when null or not on screen.
  final GlobalKey? target;

  /// Runs when the step appears, before its spotlight is measured: lets a
  /// step switch a tab so the thing it talks about is actually on screen.
  final VoidCallback? onShow;

  const GuideStep({
    required this.title,
    required this.body,
    this.icon,
    this.target,
    this.onShow,
  });
}

/// A short, skippable, step-by-step walkthrough for a screen that lives
/// outside the main tutorial (pushed routes like the leaderboard and the
/// Trial, where MainLayout's tutorial overlay can't reach).
///
/// Unlike the main tutorial it never waits on the player to perform an
/// action: NEXT / BACK / SKIP only, so it can't get stuck. Replayable from
/// each screen's "?" button.
class GuideOverlay extends StatefulWidget {
  const GuideOverlay({super.key, required this.steps, this.accent});

  final List<GuideStep> steps;
  final Color? accent;

  static String _seenKey(String id) => 'guide_seen_$id';

  /// Shows the guide unless the player has already finished or skipped it.
  static Future<void> showOnce(
    BuildContext context, {
    required String id,
    required List<GuideStep> steps,
    Color? accent,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_seenKey(id)) ?? false) return;
    } catch (_) {
      // Storage unavailable: better to show it than never.
    }
    if (!context.mounted) return;
    await show(context, id: id, steps: steps, accent: accent);
  }

  static Future<void> show(
    BuildContext context, {
    required String id,
    required List<GuideStep> steps,
    Color? accent,
  }) async {
    await Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => GuideOverlay(steps: steps, accent: accent),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey(id), true);
    } catch (_) {}
  }

  @override
  State<GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<GuideOverlay> {
  int _index = 0;

  GuideStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  Rect? _targetRect() {
    final box = _step.target?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(6);
  }

  @override
  void initState() {
    super.initState();
    _showStep();
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
      _showStep();
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
      _showStep();
    }
  }

  /// Runs the step's [GuideStep.onShow], then re-measures the spotlight once
  /// the screen underneath has rebuilt.
  void _showStep() {
    final onShow = _step.onShow;
    if (onShow == null) return;
    // After the frame: onShow usually calls setState on the screen below,
    // which must not happen while this route is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onShow();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accent ?? theme.colorScheme.primary;
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final hole = _targetRect();

    return PopScope(
      canPop: true,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: hole == null
                  ? CustomPaint(
                      painter: _SpotlightPainter(hole: null, accent: accent),
                    )
                  // Glides between targets instead of jumping.
                  : TweenAnimationBuilder<Rect?>(
                      tween: RectTween(end: hole),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      builder: (context, rect, _) => CustomPaint(
                        painter: _SpotlightPainter(hole: rect, accent: accent),
                      ),
                    ),
            ),
            _placeCard(theme, accent, size, padding, hole),
          ],
        ),
      ),
    );
  }

  Widget _placeCard(ThemeData theme, Color accent, Size size,
      EdgeInsets padding, Rect? hole) {
    const margin = 20.0;
    final width = (size.width - margin * 2).clamp(0.0, 360.0);
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _CardPlacement(hole: hole, padding: padding, width: width),
        child: _card(theme, accent),
      ),
    );
  }

  Widget _card(ThemeData theme, Color accent) {
    final step = _step;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_index),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, (1 - v) * 10), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        // Scrolls rather than overflowing on a very short screen.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (step.icon != null) ...[
                    Icon(step.icon, size: 20, color: accent),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      step.title,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
                    ),
                  ),
                  Text(
                    '${_index + 1}/${widget.steps.length}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                step.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!_isLast)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('SKIP'),
                    ),
                  const Spacer(),
                  if (_index > 0)
                    TextButton(onPressed: _back, child: const Text('BACK')),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(_isLast ? 'GOT IT' : 'NEXT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puts the card below the spotlight, else above it, else over its top
/// edge, always fully on screen. Uses the card's real height, so long copy
/// on a short phone never runs off the edge.
class _CardPlacement extends SingleChildLayoutDelegate {
  _CardPlacement({
    required this.hole,
    required this.padding,
    required this.width,
  });

  final Rect? hole;
  final EdgeInsets padding;
  final double width;

  static const double _gap = 14;
  static const double _edge = 12;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: width).copyWith(
        maxHeight: constraints.maxHeight - padding.vertical - _edge * 2,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (size.width - childSize.width) / 2;
    final minTop = padding.top + _edge;
    final maxTop = size.height - padding.bottom - _edge - childSize.height;
    double clamp(double top) =>
        maxTop <= minTop ? minTop : top.clamp(minTop, maxTop);

    final rect = hole;
    if (rect == null) {
      return Offset(left, clamp((size.height - childSize.height) / 2));
    }
    final below = rect.bottom + _gap;
    if (below <= maxTop) return Offset(left, below);
    final above = rect.top - _gap - childSize.height;
    if (above >= minTop) return Offset(left, above);
    // Neither side fits (a tall target): sit just inside its top edge.
    return Offset(left, clamp(rect.top + _gap));
  }

  @override
  bool shouldRelayout(_CardPlacement old) =>
      old.hole != hole || old.padding != padding || old.width != width;
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.accent});

  final Rect? hole;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final full = Path()..addRect(Offset.zero & size);
    final rect = hole;
    if (rect == null) {
      canvas.drawPath(full, dim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, Path()..addRRect(rrect)),
      dim,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.accent != accent;
}
