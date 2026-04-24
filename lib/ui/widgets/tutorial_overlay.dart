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
  final GlobalKey? prestigeMultiplierKey;
  final GlobalKey? prestigeGainCardKey;
  final GlobalKey? idleCategoryKey;

  const TutorialOverlay({
    super.key,
    required this.tapAreaKey,
    required this.navKeys,
    required this.upgradeRowKeys,
    required this.prestigeButtonKey,
    this.prestigeMultiplierKey,
    this.prestigeGainCardKey,
    this.idleCategoryKey,
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
      case TutorialStep.clickToFifty:
        return widget.tapAreaKey;
      case TutorialStep.navUpgrades:
      case TutorialStep.navUpgradesForClick:
        return widget.navKeys.length > 1 ? widget.navKeys[1] : null;
      case TutorialStep.selectIdle:
        return widget.idleCategoryKey;
      case TutorialStep.buyAutoClicker:
        return widget.upgradeRowKeys[GameState.autoClickerId];
      case TutorialStep.navGenerators:
        return widget.navKeys.isNotEmpty ? widget.navKeys[0] : null;
      case TutorialStep.buyClickPower:
        return widget.upgradeRowKeys[GameState.clickPowerId];
      case TutorialStep.navPrestige:
        return widget.navKeys.length > 2 ? widget.navKeys[2] : null;
      case TutorialStep.prestigeMultiplierHint:
        return widget.prestigeMultiplierKey;
      case TutorialStep.prestigeGainHint:
        return widget.prestigeGainCardKey;
      case TutorialStep.welcome:
      case TutorialStep.watchIdle:
      case TutorialStep.exploreUpgrades:
      case TutorialStep.learnPrestige:
      case TutorialStep.learnPrestigeDetails:
      case TutorialStep.goodLuck:
      case TutorialStep.done:
        return null;
    }
  }

  void _updateHole(TutorialStep step) {
    _holeRect = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _keyForStep(step);
      final ctx = key?.currentContext;
      if (ctx == null) return;
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

        if (step != _lastStep || category != _lastCategory) {
          _lastStep = step;
          _lastCategory = category;
          _updateHole(step);
        }

        final media = MediaQuery.of(context);
        final size = media.size;
        final hole = _holeRect;

        final isTapToContinue = step == TutorialStep.welcome ||
            step == TutorialStep.exploreUpgrades ||
            step == TutorialStep.learnPrestige ||
            step == TutorialStep.learnPrestigeDetails ||
            step == TutorialStep.prestigeMultiplierHint ||
            step == TutorialStep.prestigeGainHint ||
            step == TutorialStep.goodLuck;
        final isWatchIdle = step == TutorialStep.watchIdle;
        final isNavStep = step == TutorialStep.navUpgrades ||
            step == TutorialStep.navGenerators ||
            step == TutorialStep.navUpgradesForClick;

        final titleBody = _copyForStep(step);
        final onTapContinue = isTapToContinue
            ? () => context.read<GameState>().onTutorialTapToContinue()
            : () {};

        // watchIdle: floating card only — no dim, no blocking
        if (isWatchIdle) {
          if (titleBody == null) return const SizedBox.shrink();
          return Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                _CaptionCard(
                  title: titleBody.$1,
                  body: titleBody.$2,
                  hole: null,
                  screenSize: size,
                  padding: media.padding,
                  centerOnScreen: false,
                  positionTop: media.padding.top + 80,
                  showTopContinueHint: false,
                  continueHintOverride: null,
                ),
              ],
            ),
          );
        }

        // Nav steps: no dim at all — taps pass through to nav bar.
        // MaterialType.transparency sets absorbHitTest=false so the Material
        // does NOT intercept taps in areas with no child widget.
        if (isNavStep) {
          return Material(
            type: MaterialType.transparency,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (hole != null && hole.width > 0 && hole.height > 0)
                  Positioned(
                    left: hole.left,
                    top: hole.top,
                    width: hole.width,
                    height: hole.height,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final t = Curves.easeInOut
                              .transform(_pulseController.value);
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
                if (titleBody != null)
                  _CaptionCard(
                    title: titleBody.$1,
                    body: titleBody.$2,
                    hole: hole,
                    screenSize: size,
                    padding: media.padding,
                    centerOnScreen: hole == null,
                    showTopContinueHint: false,
                    continueHintOverride: null,
                  ),
                Positioned(
                  right: 12,
                  top: media.padding.top + 8,
                  child: TextButton(
                    onPressed: () =>
                        context.read<GameState>().skipTutorial(),
                    child: Text(
                      'SKIP',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                letterSpacing: 2,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Dim overlay
              if (hole != null && hole.width > 0 && hole.height > 0) ...[
                _DimBar(
                  rect: Rect.fromLTWH(0, 0, size.width, hole.top),
                  onBlock: onTapContinue,
                ),
                _DimBar(
                  rect: Rect.fromLTWH(
                      0, hole.bottom, size.width, size.height - hole.bottom),
                  onBlock: onTapContinue,
                ),
                _DimBar(
                  rect: Rect.fromLTWH(0, hole.top, hole.left, hole.height),
                  onBlock: onTapContinue,
                ),
                _DimBar(
                  rect: Rect.fromLTWH(hole.right, hole.top,
                      size.width - hole.right, hole.height),
                  onBlock: onTapContinue,
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
              ] else if (isTapToContinue)
                // For tap-to-continue steps (welcome, etc.) with no hole,
                // show the dim and capture the tap.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapContinue,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.58),
                    ),
                  ),
                )
              else
                // For action steps with no hole yet (transitional frame),
                // don't block — let the underlying UI receive taps.
                const SizedBox.shrink(),

              // Caption card (_CaptionCard is Positioned and handles IgnorePointer internally)
              if (titleBody != null)
                _CaptionCard(
                  title: titleBody.$1,
                  body: titleBody.$2,
                  hole: hole,
                  screenSize: size,
                  padding: media.padding,
                  centerOnScreen: (isTapToContinue && step != TutorialStep.prestigeMultiplierHint && step != TutorialStep.prestigeGainHint) || hole == null,
                  showTopContinueHint: isTapToContinue,
                  continueHintOverride: step == TutorialStep.learnPrestige
                      ? 'TAP ANYWHERE TO START PLAYING'
                      : null,
                ),

              // Full-screen tap detector for tap-to-continue steps
              if (isTapToContinue)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: onTapContinue,
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
  final Rect? hole;
  final Size screenSize;
  final EdgeInsets padding;
  final bool centerOnScreen;
  final bool showTopContinueHint;
  final String? continueHintOverride;
  final double? positionTop;

  const _CaptionCard({
    required this.title,
    required this.body,
    required this.hole,
    required this.screenSize,
    required this.padding,
    this.centerOnScreen = false,
    this.showTopContinueHint = false,
    this.continueHintOverride,
    this.positionTop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cardWidth = 280.0;
    const hMargin = 24.0;
    double top;
    double left;

    if (positionTop != null) {
      top = positionTop!;
      left = ((screenSize.width - cardWidth) / 2)
          .clamp(hMargin, screenSize.width - cardWidth - hMargin);
    } else if (centerOnScreen || hole == null) {
      top = ((screenSize.height - 200) / 2).clamp(
        padding.top + 52.0,
        screenSize.height - 260,
      );
      left = ((screenSize.width - cardWidth) / 2)
          .clamp(hMargin, screenSize.width - cardWidth - hMargin);
    } else {
      final h = hole!;
      // Large hole (e.g. full play field): pin card to top of hole.
      if (h.height > screenSize.height * 0.4) {
        top = (h.top + 24).clamp(padding.top + 52.0, screenSize.height - 220);
        left = ((screenSize.width - cardWidth) / 2)
            .clamp(hMargin, screenSize.width - cardWidth - hMargin);
      } else {
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
        left = left.clamp(hMargin, screenSize.width - cardWidth - hMargin);
      }
    }

    final hintText = continueHintOverride ??
        (showTopContinueHint ? 'TAP ANYWHERE TO CONTINUE' : null);

    return Positioned(
      left: left,
      top: top,
      width: cardWidth,
      child: IgnorePointer(
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
                if (hintText != null) ...[
                  Text(
                    hintText,
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
      ),
    );
  }
}

(String, String)? _copyForStep(TutorialStep step) {
  switch (step) {
    case TutorialStep.welcome:
      return (
        'WELCOME TO NUMBER',
        'Your goal: collect the biggest number possible. Tap the play field to generate numbers, spend them on upgrades to grow faster, and prestige for permanent multipliers.',
      );
    case TutorialStep.clickToFifty:
      return (
        'GENERATORS',
        'Tap anywhere on the play field to generate numbers! Every tap adds to your count. Keep clicking — reach 50 to unlock your first upgrade.',
      );
    case TutorialStep.navUpgrades:
      return (
        'NICE WORK!',
        'You hit 50! Your first upgrade is within reach. Open UPGRADES below.',
      );
    case TutorialStep.selectIdle:
      return (
        'IDLE UPGRADES',
        'Switch to the IDLE tab. Idle upgrades generate numbers automatically — even when you\'re not tapping.',
      );
    case TutorialStep.buyAutoClicker:
      return (
        'AUTO-CLICKER',
        'Buy the Auto-Clicker! Each level adds +1 number per second automatically.',
      );
    case TutorialStep.navGenerators:
      return (
        'SEE IT WORK',
        'Great purchase! Head back to GENERATORS and watch your numbers climb on their own.',
      );
    case TutorialStep.watchIdle:
      return (
        'IDLE INCOME',
        'Your numbers are growing by themselves now. You can still click for extra gains. Reach 100 to continue!',
      );
    case TutorialStep.navUpgradesForClick:
      return (
        'POWER UP YOUR CLICKS',
        'Nice grind! Head to UPGRADES again — this time we\'ll boost your click power.',
      );
    case TutorialStep.buyClickPower:
      return (
        'CLICK POWER',
        'Buy Click Power! Each level increases how much every tap earns you.',
      );
    case TutorialStep.exploreUpgrades:
      return (
        'EXPLORE',
        'There are many more upgrades to discover — idle generators, click multipliers, and special mechanics. Experiment to find what works best!',
      );
    case TutorialStep.learnPrestige:
      return (
        'PRESTIGE',
        'Reset your progress to earn a permanent multiplier that boosts all future gains. The bigger your number when you prestige, the stronger your multiplier!',
      );
    case TutorialStep.navPrestige:
      return (
        'TIME TO PRESTIGE',
        'Open the PRESTIGE tab to start your first prestige and unlock the Nexus.',
      );
    case TutorialStep.learnPrestigeDetails:
      return (
        'HOW PRESTIGE WORKS',
        'Reset your current run to earn a permanent Prestige Multiplier. This multiplier applies to ALL future gains — it grows stronger with each prestige!',
      );
    case TutorialStep.prestigeMultiplierHint:
      return (
        'YOUR PRESTIGE MULTIPLIER',
        'This is your permanent boost that multiplies everything: clicks, idle gains, and upgrades. The more you prestige, the larger this multiplier becomes.',
      );
    case TutorialStep.prestigeGainHint:
      return (
        'PRESTIGE COST & GAIN',
        'You need to reach the "Required number" shown here. When you prestige, you\'ll earn the multiplier shown above. The bigger your current number, the bigger your next multiplier!',
      );
    case TutorialStep.goodLuck:
      return (
        'YOU\'RE READY!',
        'You\'ve learned the basics. Now go grind, prestige, and climb the leaderboards. Good luck!',
      );
    case TutorialStep.done:
      return null;
  }
}
