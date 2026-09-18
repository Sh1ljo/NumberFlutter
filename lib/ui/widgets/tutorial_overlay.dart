import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_state.dart';
import '../../logic/tutorial_step.dart';

/// Resolves a [TutorialTarget] to the GlobalKey currently representing it.
///
/// Owned by MainLayout. This indirection replaces the hardcoded `navKeys[1]` /
/// `navKeys[3]` indices that were scattered through a 39-case switch.
typedef TutorialKeyResolver = GlobalKey? Function(TutorialTarget target);

/// Dimmed overlay with a clear "hole" over the target and a caption card.
///
/// Behaviour per step comes entirely from [tutorialSpecs]; this widget only
/// knows how to render the five [TutorialMode]s.
class TutorialOverlay extends StatefulWidget {
  final TutorialKeyResolver resolveKey;

  /// Tab currently shown by MainLayout, matched against
  /// [TutorialStepSpec.requiredTab].
  final int currentTab;

  /// True while a modal route (e.g. NeuronDetailSheet) covers the overlay, so
  /// [TutorialMode.inSheet] steps know to stay quiet.
  final bool modalRouteActive;

  const TutorialOverlay({
    super.key,
    required this.resolveKey,
    required this.currentTab,
    this.modalRouteActive = false,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  Rect? _holeRect;
  TutorialStep? _lastStep;
  String? _lastCategory;
  int? _lastTab;
  int? _lastSubTab;
  int _holeGeneration = 0;
  Timer? _retryTimer;

  /// Scrollable the current target lives in, listened to so the hole follows
  /// the target instead of being resolved once and then left behind.
  ScrollPosition? _trackedScroll;

  static const double _holePadding = 8.0;

  @override
  void dispose() {
    _retryTimer?.cancel();
    _detachScroll();
    super.dispose();
  }

  void _detachScroll() {
    _trackedScroll?.removeListener(_onTrackedScroll);
    _trackedScroll = null;
  }

  void _onTrackedScroll() {
    final step = _lastStep;
    if (step == null || !mounted) return;
    _measure(step, _holeGeneration);
  }

  void _restartHoleTracking(TutorialStep step) {
    _retryTimer?.cancel();
    _detachScroll();
    _holeRect = null;
    final generation = ++_holeGeneration;
    _scheduleResolve(step, generation, 0);
  }

  void _scheduleResolve(TutorialStep step, int generation, int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _holeGeneration != generation) return;

      // Captured before the await below so no BuildContext is read across the
      // async gap. A resize rebuilds and bumps the generation anyway.
      final screenSize = MediaQuery.of(context).size;
      final key = _keyFor(step);
      final ctx = key?.currentContext;
      if (ctx == null) {
        // Target not laid out yet — a lazy list row, a tab still animating
        // in, or the neural canvas doing its first fit. The old code gave up
        // permanently after 5 tries at 100ms; keep trying on a widening
        // backoff for as long as the step is active.
        if (attempt < 40) {
          final delayMs = attempt < 5 ? 100 : (attempt < 15 ? 250 : 500);
          _retryTimer?.cancel();
          _retryTimer = Timer(Duration(milliseconds: delayMs), () {
            if (mounted && _holeGeneration == generation) {
              _scheduleResolve(step, generation, attempt + 1);
            }
          });
        }
        return;
      }

      try {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      } catch (_) {
        // Target isn't inside a Scrollable, or it was disposed mid-scroll.
        // Measuring below still works.
      }

      if (!mounted || _holeGeneration != generation) return;

      // Follow the target if it lives in a scroll view.
      // Re-read the context after the await rather than reusing `ctx`, and
      // check it is still mounted — the target may have scrolled out of a
      // lazy list or had its tab swapped while we waited.
      final freshCtx = _keyFor(step)?.currentContext;
      if (freshCtx != null && freshCtx.mounted) {
        final scroll = Scrollable.maybeOf(freshCtx)?.position;
        if (scroll != null && scroll != _trackedScroll) {
          _detachScroll();
          _trackedScroll = scroll..addListener(_onTrackedScroll);
        }
      }

      _measure(step, generation, screenSize: screenSize);
    });
  }

  void _measure(TutorialStep step, int generation, {Size? screenSize}) {
    if (!mounted || _holeGeneration != generation) return;
    final renderObject = _keyFor(step)?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final offset = renderObject.localToGlobal(Offset.zero);
    final screen = screenSize ?? MediaQuery.of(context).size;

    // Clip to the screen. left/top used to be clamped to >= 0 while
    // right/bottom were not, so a partially off-screen target produced dim
    // bars with negative dimensions that silently no-op'd, leaving undimmed
    // gaps around the hole.
    final raw = Rect.fromLTWH(
      offset.dx - _holePadding,
      offset.dy - _holePadding,
      renderObject.size.width + _holePadding * 2,
      renderObject.size.height + _holePadding * 2,
    );
    final clipped = raw.intersect(Offset.zero & screen);
    final next = (clipped.width <= 0 || clipped.height <= 0) ? null : clipped;

    if (next != _holeRect) {
      setState(() => _holeRect = next);
    }
  }

  GlobalKey? _keyFor(TutorialStep step) {
    final target = specFor(step).target;
    if (target == null) return null;
    return widget.resolveKey(target);
  }

  @override
  Widget build(BuildContext context) {
    // Selected rather than consumed: this overlay is mounted for the whole
    // session and the game ticker notifies ~10x/s, but what it renders only
    // depends on these three values.
    return Selector<GameState, (bool, TutorialStep, String, int)>(
      selector: (_, gs) => (
        gs.isTutorialActive,
        gs.tutorialStep,
        gs.selectedUpgradeCategory,
        gs.prestigeSubTabIndex,
      ),
      builder: (context, _, __) {
        final gameState = context.read<GameState>();
        if (!gameState.isTutorialActive) return const SizedBox.shrink();

        final step = gameState.tutorialStep;
        final spec = specFor(step);
        final category = gameState.selectedUpgradeCategory;
        final tab = widget.currentTab;
        final subTab = gameState.prestigeSubTabIndex;

        // Re-resolve the hole when anything that could move the target
        // changes. Still kicked from build, but it only schedules a
        // post-frame measurement and never calls setState synchronously.
        if (step != _lastStep ||
            category != _lastCategory ||
            tab != _lastTab ||
            subTab != _lastSubTab) {
          _lastStep = step;
          _lastCategory = category;
          _lastTab = tab;
          _lastSubTab = subTab;
          _restartHoleTracking(step);
        }

        // Wrong tab: the target isn't on screen, so pointing at it would be
        // worse than staying quiet. SKIP stays available regardless.
        final onWrongTab = spec.requiredTab != null && spec.requiredTab != tab;
        // Wrong upgrade category: the spotlit row doesn't exist yet.
        final onWrongCategory =
            spec.requiredCategory != null && spec.requiredCategory != category;

        final media = MediaQuery.of(context);

        if (onWrongTab || onWrongCategory) {
          return _skipOnly(context, media, gameState);
        }

        switch (spec.mode) {
          case TutorialMode.inSheet:
            // NeuronDetailSheet renders its own guidance while open. When it
            // isn't open, show a normal floating card — this used to render
            // nothing at all, with no SKIP, so dismissing the sheet left the
            // player permanently stuck.
            if (widget.modalRouteActive) return const SizedBox.shrink();
            return _floating(context, spec, media, gameState);

          case TutorialMode.floatingHint:
            return _floating(context, spec, media, gameState);

          case TutorialMode.passthroughHint:
            return _passthrough(context, spec, media, gameState);

          case TutorialMode.tapToContinue:
          case TutorialMode.spotlightAction:
          case TutorialMode.spotlightTapToContinue:
            return _spotlight(context, spec, media, gameState);
        }
      },
    );
  }

  /// Floating card, nothing dimmed, nothing blocked.
  Widget _floating(
    BuildContext context,
    TutorialStepSpec spec,
    MediaQueryData media,
    GameState gameState,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (spec.hasCopy)
            _CaptionCard(
              title: spec.title!,
              body: spec.body!,
              hole: null,
              screenSize: media.size,
              padding: media.padding,
              centerOnScreen: false,
              positionTop: media.padding.top + 80,
            ),
          _skipButton(context, media, gameState),
        ],
      ),
    );
  }

  /// Pulsing outline over the target; taps pass straight through to it.
  Widget _passthrough(
    BuildContext context,
    TutorialStepSpec spec,
    MediaQueryData media,
    GameState gameState,
  ) {
    final hole = _holeRect;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hole != null) _PulseOutline(rect: hole),
          if (spec.hasCopy)
            _CaptionCard(
              title: spec.title!,
              body: spec.body!,
              hole: hole,
              screenSize: media.size,
              padding: media.padding,
              centerOnScreen: hole == null,
            ),
          _skipButton(context, media, gameState),
        ],
      ),
    );
  }

  /// Dim everything but the target.
  Widget _spotlight(
    BuildContext context,
    TutorialStepSpec spec,
    MediaQueryData media,
    GameState gameState,
  ) {
    final hole = _holeRect;
    final size = media.size;
    final tapToContinue = spec.isTapToContinue;
    final tapInsideHole = spec.mode == TutorialMode.spotlightTapToContinue;
    final onTap =
        tapToContinue ? () => gameState.onTutorialTapToContinue() : null;

    final children = <Widget>[];

    if (hole != null) {
      // Four bars around the hole. Taps on them are swallowed (or advance the
      // step), so only the spotlit target stays reachable.
      for (final bar in [
        Rect.fromLTRB(0, 0, size.width, hole.top),
        Rect.fromLTRB(0, hole.bottom, size.width, size.height),
        Rect.fromLTRB(0, hole.top, hole.left, hole.bottom),
        Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom),
      ]) {
        children.add(_DimBar(rect: bar, onBlock: onTap));
      }
      children.add(_PulseOutline(rect: hole));
      if (tapInsideHole) {
        children.add(_HoleTapLayer(
          rect: hole,
          onTap: () => gameState.onTutorialTapToContinue(),
        ));
      }
    } else if (tapToContinue) {
      // No target (or not resolved yet) but the step advances on any tap:
      // dim the whole screen and take the tap.
      children.add(Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.58)),
        ),
      ));
    }
    // An unresolved spotlightAction step deliberately renders no dim, so the
    // player can still reach the UI while the target is being located.

    final showCard =
        spec.hasCopy && (hole != null || tapToContinue || spec.target == null);
    if (showCard) {
      children.add(_CaptionCard(
        title: spec.title!,
        body: spec.body!,
        hole: hole,
        screenSize: size,
        padding: media.padding,
        centerOnScreen: hole == null,
        continueHint: tapToContinue
            ? (spec.continueHint ?? 'TAP ANYWHERE TO CONTINUE')
            : tapInsideHole
                ? (spec.continueHint ?? 'TAP THE HIGHLIGHTED AREA TO CONTINUE')
                : null,
      ));
    }

    children.add(_skipButton(context, media, gameState));

    return Material(
      type: MaterialType.transparency,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }

  /// SKIP and nothing else — used when the player has navigated away from the
  /// screen a step belongs to. Every state of the tutorial keeps a way out.
  Widget _skipOnly(
    BuildContext context,
    MediaQueryData media,
    GameState gameState,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [_skipButton(context, media, gameState)]),
    );
  }

  Widget _skipButton(
    BuildContext context,
    MediaQueryData media,
    GameState gameState,
  ) {
    return Positioned(
      right: 12,
      top: media.padding.top + 8,
      child: TextButton(
        onPressed: gameState.skipTutorial,
        child: Text(
          'SKIP',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 2,
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ),
    );
  }
}

class _PulseOutline extends StatefulWidget {
  final Rect rect;
  const _PulseOutline({required this.rect});

  @override
  State<_PulseOutline> createState() => _PulseOutlineState();
}

class _PulseOutlineState extends State<_PulseOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.rect;
    if (rect.width <= 0 || rect.height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      // Pulses at 60fps for as long as a spotlight is up; keep that from
      // repainting the whole screen underneath.
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_ctrl.value);
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.35 + t * 0.45),
                    width: 2,
                  ),
                ),
                child: child,
              );
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _HoleTapLayer extends StatelessWidget {
  final Rect rect;
  final VoidCallback onTap;
  const _HoleTapLayer({required this.rect, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (rect.width <= 0 || rect.height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DimBar extends StatelessWidget {
  final Rect rect;

  /// Null means "swallow the tap" — which is what gates a spotlight step to
  /// its target.
  final VoidCallback? onBlock;

  const _DimBar({required this.rect, this.onBlock});

  @override
  Widget build(BuildContext context) {
    if (rect.width <= 0 || rect.height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBlock ?? () {},
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.58)),
      ),
    );
  }
}

class _CaptionCard extends StatelessWidget {
  final String title;
  final String body;
  final Rect? hole;
  final Size screenSize;
  final EdgeInsets padding;
  final bool centerOnScreen;
  final String? continueHint;
  final double? positionTop;

  const _CaptionCard({
    required this.title,
    required this.body,
    required this.hole,
    required this.screenSize,
    required this.padding,
    this.centerOnScreen = false,
    this.continueHint,
    this.positionTop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const hMargin = 24.0;

    // Never let the clamp bounds invert. With a fixed 280 width this threw an
    // assertion ("min must be <= max") on any viewport narrower than 328px —
    // a real crash on small phones and on resized desktop windows.
    final available = screenSize.width - hMargin * 2;
    final cardWidth = available < 280.0 ? available : 280.0;
    if (cardWidth <= 0) return const SizedBox.shrink();

    double clampLeft(double value) {
      final maxLeft = screenSize.width - cardWidth - hMargin;
      if (maxLeft <= hMargin) return (screenSize.width - cardWidth) / 2;
      return value.clamp(hMargin, maxLeft);
    }

    final centeredLeft = clampLeft((screenSize.width - cardWidth) / 2);

    // Vertical placement resolves against the card's real height rather than
    // the 200/220/260px guesses the old code hardcoded, which pushed long
    // bodies off the bottom on short screens.
    return CustomSingleChildLayout(
      delegate: _CardLayoutDelegate(
        hole: hole,
        padding: padding,
        cardWidth: cardWidth,
        centerOnScreen: centerOnScreen,
        positionTop: positionTop,
        centeredLeft: centeredLeft,
        clampLeft: clampLeft,
      ),
      child: IgnorePointer(child: _card(theme, cardWidth)),
    );
  }

  Widget _card(ThemeData theme, double cardWidth) {
    return SizedBox(
      width: cardWidth,
      child: TweenAnimationBuilder<double>(
        // Keyed on the title alone: keying on layout state as well meant the
        // entrance animation replayed whenever the hole resolved and the card
        // moved, which is what made it look like it was jumping.
        key: ValueKey(title),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 12),
            child: child,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              // Long copy on a short or very narrow viewport scrolls instead
              // of overflowing. shrinkWrap keeps the card its natural height
              // whenever it does fit, which is the normal case.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (continueHint != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      continueHint!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                        color: theme.colorScheme.outline,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Places the caption card once its real height is known.
class _CardLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect? hole;
  final EdgeInsets padding;
  final double cardWidth;
  final bool centerOnScreen;
  final double? positionTop;
  final double centeredLeft;
  final double Function(double) clampLeft;

  _CardLayoutDelegate({
    required this.hole,
    required this.padding,
    required this.cardWidth,
    required this.centerOnScreen,
    required this.positionTop,
    required this.centeredLeft,
    required this.clampLeft,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Bound to the band the card can actually be placed in, not the whole
    // surface — otherwise a narrow screen makes the text tall enough to
    // overflow the region and Flutter reports a RenderFlex overflow.
    final usable =
        constraints.maxHeight - (padding.top + 52.0) - (padding.bottom + 24.0);
    return BoxConstraints(
      minWidth: cardWidth,
      maxWidth: cardWidth,
      maxHeight: usable > 0 ? usable : constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final h = childSize.height;
    final topLimit = padding.top + 52.0;
    final bottomLimit = size.height - padding.bottom - 24.0 - h;

    double clampTop(double value) {
      if (bottomLimit <= topLimit) return topLimit;
      return value.clamp(topLimit, bottomLimit);
    }

    if (positionTop != null) {
      return Offset(centeredLeft, clampTop(positionTop!));
    }

    final rect = hole;
    if (centerOnScreen || rect == null) {
      return Offset(centeredLeft, clampTop((size.height - h) / 2));
    }

    // A hole taller than 40% of the screen (e.g. the whole play field) gets
    // the card pinned just inside its top edge rather than below it.
    if (rect.height > size.height * 0.4) {
      return Offset(centeredLeft, clampTop(rect.top + 24));
    }

    // Prefer below the hole, fall back to above, then to beside its centre.
    var top = rect.bottom + 16;
    if (top + h > size.height - padding.bottom - 24) {
      final above = rect.top - 16 - h;
      top = above >= topLimit ? above : (rect.center.dy - h / 2);
    }
    return Offset(clampLeft(rect.center.dx - cardWidth / 2), clampTop(top));
  }

  @override
  bool shouldRelayout(_CardLayoutDelegate old) =>
      old.hole != hole ||
      old.padding != padding ||
      old.cardWidth != cardWidth ||
      old.centerOnScreen != centerOnScreen ||
      old.positionTop != positionTop ||
      old.centeredLeft != centeredLeft;
}
