import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_state.dart';
import '../../logic/tutorial_step.dart';

/// Dimmed overlay with a clear "hole" over the target and a caption card.
class TutorialOverlay extends StatefulWidget {
  final GlobalKey? tapAreaKey;
  final List<GlobalKey> navKeys;
  final Map<String, GlobalKey> upgradeRowKeys;
  final GlobalKey? prestigeButtonKey;

  const TutorialOverlay({
    super.key,
    required this.tapAreaKey,
    required this.navKeys,
    required this.upgradeRowKeys,
    required this.prestigeButtonKey,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Rect? _holeRect;
  TutorialStep? _lastStep;
  String? _lastCategory;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  GlobalKey? _keyForStep(TutorialStep step) {
    switch (step) {
      case TutorialStep.welcomeTap:
        return widget.tapAreaKey;
      case TutorialStep.navUpgrades:
        return widget.navKeys.length > 1 ? widget.navKeys[1] : null;
      case TutorialStep.buyClickPower:
        return widget.upgradeRowKeys[GameState.clickPowerId];
      case TutorialStep.buyAutoClicker:
        return widget.upgradeRowKeys[GameState.autoClickerId];
      case TutorialStep.buyProbabilityStrike:
        return widget.upgradeRowKeys[GameState.probabilityStrikeId];
      case TutorialStep.navPrestige:
        return widget.navKeys.length > 2 ? widget.navKeys[2] : null;
      case TutorialStep.initiatePrestige:
        return widget.prestigeButtonKey;
      case TutorialStep.done:
        return null;
    }
  }

  // Clears _holeRect immediately (so the current build sees null) then
  // resolves the new rect after the next frame when widgets are laid out.
  void _updateHole(TutorialStep step) {
    _holeRect = null; // cleared synchronously; build reads null this frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _keyForStep(step);
      final ctx = key?.currentContext;
      if (ctx == null) return; // still null — caption stays centered
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final box = renderObject;
      final offset = box.localToGlobal(Offset.zero);
      const pad = 8.0;
      setState(() {
        _holeRect = Rect.fromLTWH(
          (offset.dx - pad).clamp(0.0, double.infinity),
          (offset.dy - pad).clamp(0.0, double.infinity),
          box.size.width + pad * 2,
          box.size.height + pad * 2,
        );
      });
      try {
        Scrollable.maybeOf(ctx)?.position.ensureVisible(
              renderObject,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: 0.35,
            );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        if (!gameState.isTutorialActive) {
          return const SizedBox.shrink();
        }
        final step = gameState.tutorialStep;
        final category = gameState.selectedUpgradeCategory;

        // Re-resolve the hole when step OR upgrade category changes so that
        // category-switching steps (buyAutoClicker, buyProbabilityStrike)
        // correctly highlight the newly visible row.
        if (step != _lastStep || category != _lastCategory) {
          _lastStep = step;
          _lastCategory = category;
          _updateHole(step); // also clears _holeRect synchronously
        }

        final media = MediaQuery.of(context);
        final size = media.size;
        final hole = _holeRect;
        final isWelcomeStep = step == TutorialStep.welcomeTap;

        final titleBody = _copyForStep(step);
        final onWelcomeTap = isWelcomeStep
            ? () => context.read<GameState>().onTutorialWelcomeTap()
            : () {};

        return Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Dim overlay — four bars around the hole, or a full dim when
              // no hole is resolved yet.
              if (hole != null && hole.width > 0 && hole.height > 0) ...[
                _DimBar(
                  rect: Rect.fromLTWH(0, 0, size.width, hole.top),
                  onBlock: onWelcomeTap,
                ),
                _DimBar(
                  rect: Rect.fromLTWH(
                      0, hole.bottom, size.width, size.height - hole.bottom),
                  onBlock: onWelcomeTap,
                ),
                _DimBar(
                  rect: Rect.fromLTWH(0, hole.top, hole.left, hole.height),
                  onBlock: onWelcomeTap,
                ),
                _DimBar(
                  rect: Rect.fromLTWH(
                      hole.right, hole.top, size.width - hole.right, hole.height),
                  onBlock: onWelcomeTap,
                ),
                // Pulsing border around the hole
                Positioned(
                  left: hole.left,
                  top: hole.top,
                  width: hole.width,
                  height: hole.height,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final t =
                          Curves.easeInOut.transform(_pulseController.value);
                      return IgnorePointer(
                        child: DecoratedBox(
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
                        ),
                      );
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
              ] else
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onWelcomeTap,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.58),
                    ),
                  ),
                ),

              // Caption card — always shown (centered when hole is not yet
              // resolved so the user always has guidance).
              if (titleBody != null)
                IgnorePointer(
                  child: _CaptionCard(
                    title: titleBody.$1,
                    body: titleBody.$2,
                    hole: hole,
                    screenSize: size,
                    padding: media.padding,
                    centerOnScreen: isWelcomeStep || hole == null,
                    showTopContinueHint: isWelcomeStep,
                  ),
                ),

              // Full-screen tap detector for the welcome step only.
              if (isWelcomeStep)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: onWelcomeTap,
                    child: const SizedBox.expand(),
                  ),
                ),

              // SKIP button
              Positioned(
                right: 12,
                top: media.padding.top + 8,
                child: TextButton(
                  onPressed: () => context.read<GameState>().skipTutorial(),
                  child: Text(
                    'SKIP',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DimBar extends StatelessWidget {
  final Rect rect;
  final VoidCallback onBlock;

  const _DimBar({required this.rect, required this.onBlock});

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
        onTap: onBlock,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.58),
        ),
      ),
    );
  }
}

class _CaptionCard extends StatelessWidget {
  final String title;
  final String body;
  final Rect? hole; // nullable — null while target widget is being resolved
  final Size screenSize;
  final EdgeInsets padding;
  final bool centerOnScreen;
  final bool showTopContinueHint;

  const _CaptionCard({
    required this.title,
    required this.body,
    required this.hole,
    required this.screenSize,
    required this.padding,
    this.centerOnScreen = false,
    this.showTopContinueHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cardWidth = 320.0;
    double top;
    double left;

    if (centerOnScreen || hole == null) {
      top = (screenSize.height / 2 - 110).clamp(
        padding.top + 52.0,
        screenSize.height - 240,
      );
      left = ((screenSize.width - cardWidth) / 2)
          .clamp(16.0, screenSize.width - cardWidth - 16);
    } else {
      final h = hole!;
      top = h.bottom + 16;
      if (top + 200 > screenSize.height - padding.bottom - 24) {
        top = h.top - 16 - 200;
        if (top < padding.top + 48) {
          top = (h.center.dy - 100).clamp(
            padding.top + 52.0,
            screenSize.height - 220,
          );
        }
      }
      left = h.center.dx - cardWidth / 2;
      left = left.clamp(16.0, screenSize.width - cardWidth - 16);
    }

    return Positioned(
      left: left,
      top: top,
      width: cardWidth,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('$title$centerOnScreen'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) {
          return Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * 12),
              child: child,
            ),
          );
        },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTopContinueHint) ...[
                  Text(
                    'TAP ANYWHERE TO CONTINUE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.3,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

(String, String)? _copyForStep(TutorialStep step) {
  switch (step) {
    case TutorialStep.welcomeTap:
      return (
        'WELCOME TO NUMBERFLUTTER',
        'You generate Numbers by tapping the playfield, then spend them on upgrades to grow faster.'
      );
    case TutorialStep.navUpgrades:
      return (
        'UPGRADES',
        'Tap UPGRADES in the bar below. That\'s where you spend Numbers on permanent boosts.'
      );
    case TutorialStep.buyClickPower:
      return (
        'CLICK POWER',
        'Buy Click Power first. Each level adds more Numbers every time you tap.'
      );
    case TutorialStep.buyAutoClicker:
      return (
        'AUTO-CLICKER',
        'Buy Auto-Clicker so Numbers tick in automatically every second.'
      );
    case TutorialStep.buyProbabilityStrike:
      return (
        'SPECIAL CLICKS',
        'Special upgrades like Probability Strike add new mechanics. Numbers have been credited — buy one level now.'
      );
    case TutorialStep.navPrestige:
      return (
        'PRESTIGE',
        'Eventually you reset your run for a permanent multiplier. Open PRESTIGE when you\'re ready for the next lesson.'
      );
    case TutorialStep.initiatePrestige:
      return (
        'INITIATE PRESTIGE',
        'You\'ve got enough Numbers for your first prestige. Confirm the ritual — afterwards you\'ll start fresh with a permanent boost.'
      );
    case TutorialStep.done:
      return null;
  }
}
