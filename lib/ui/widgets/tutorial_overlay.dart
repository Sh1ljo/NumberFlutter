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
  final GlobalKey? momentumBarKey;
  final GlobalKey? neuralNeuronKey;
  final GlobalKey? neuralHudKey;

  const TutorialOverlay({
    super.key,
    required this.tapAreaKey,
    required this.navKeys,
    required this.upgradeRowKeys,
    required this.prestigeButtonKey,
    this.prestigeMultiplierKey,
    this.prestigeGainCardKey,
    this.idleCategoryKey,
    this.momentumBarKey,
    this.neuralNeuronKey,
    this.neuralHudKey,
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
  int _holeUpdateGeneration = 0;

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
      case TutorialStep.navNeural:
        return widget.navKeys.length > 3 ? widget.navKeys[3] : null;
      case TutorialStep.neuralTapNeuron:
        return widget.neuralNeuronKey;
      case TutorialStep.neuralViewAccuracy:
        return widget.neuralHudKey;
      case TutorialStep.buyProbabilityStrike:
        return widget.upgradeRowKeys[GameState.probabilityStrikeId];
      case TutorialStep.navGeneratorsForStrike:
        return widget.navKeys.isNotEmpty ? widget.navKeys[0] : null;
      case TutorialStep.navUpgradesForMomentum:
        return widget.navKeys.length > 1 ? widget.navKeys[1] : null;
      case TutorialStep.buyMomentum:
        return null; // floating card only — user finds and buys it themselves
      case TutorialStep.navGeneratorsForMomentum:
        return widget.navKeys.isNotEmpty ? widget.navKeys[0] : null;
      case TutorialStep.demonstrateMomentum:
        return widget.momentumBarKey;
      case TutorialStep.navUpgradesForSpecial:
        return widget.navKeys.length > 1 ? widget.navKeys[1] : null;
      case TutorialStep.kineticSynergyIntro:
        return widget.upgradeRowKeys[GameState.kineticSynergyId];
      case TutorialStep.overclockIntro:
        return widget.upgradeRowKeys[GameState.overclockId];
      case TutorialStep.welcome:
      case TutorialStep.watchIdle:
      case TutorialStep.learnPrestige:
      case TutorialStep.learnPrestigeDetails:
      case TutorialStep.goodLuck:
      case TutorialStep.nexusIntro:
      case TutorialStep.nexusUpgrades:
      case TutorialStep.nexusGoal:
      case TutorialStep.neuralUnlocked:
      case TutorialStep.neuralIntro:
      case TutorialStep.neuralUpgradeGradient:
      case TutorialStep.neuralChangeActivation:
      case TutorialStep.neuralBranchNeuron:
      case TutorialStep.neuralAccuracyLimit:
      case TutorialStep.upgradeIntro:
      case TutorialStep.probabilityStrikeIntro:
      case TutorialStep.triggerProbabilityStrike:
      case TutorialStep.momentumIntro:
      case TutorialStep.upgradesDone:
      case TutorialStep.done:
        return null;
    }
  }

  void _updateHole(TutorialStep step) {
    _holeRect = null;
    final gen = ++_holeUpdateGeneration;
    _doHoleUpdate(step, gen, 0);
  }

  void _doHoleUpdate(TutorialStep step, int gen, int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _holeUpdateGeneration != gen) return;
      final key = _keyForStep(step);
      final ctx = key?.currentContext;
      if (ctx == null) {
        // Item not rendered yet (lazy list) — retry up to 5 times
        if (attempt < 5) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _holeUpdateGeneration == gen) {
              _doHoleUpdate(step, gen, attempt + 1);
            }
          });
        }
        return;
      }

      // Scroll item into view; awaiting means we wait for the animation to
      // finish (or resolve immediately if no scroll was needed).
      try {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      } catch (_) {}

      // One extra frame for layout to settle after the scroll.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      if (!mounted || _holeUpdateGeneration != gen) return;
      final rObj = key?.currentContext?.findRenderObject();
      if (rObj is! RenderBox || !rObj.hasSize) return;
      final offset = rObj.localToGlobal(Offset.zero);
      const pad = 8.0;
      setState(() {
        _holeRect = Rect.fromLTWH(
          (offset.dx - pad).clamp(0.0, double.infinity),
          (offset.dy - pad).clamp(0.0, double.infinity),
          rObj.size.width + pad * 2,
          rObj.size.height + pad * 2,
        );
      });
    });
  }

  /// Steps where the caption card must not appear until the hole is resolved.
  /// Without this guard the card briefly centres on-screen (hole == null) and
  /// then jumps to the correct position once the hole is found.
  static bool _requiresHoleBeforeShow(TutorialStep step) {
    switch (step) {
      case TutorialStep.buyAutoClicker:
      case TutorialStep.buyClickPower:
      case TutorialStep.buyProbabilityStrike:
        return true;
      default:
        return false;
    }
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
            step == TutorialStep.learnPrestige ||
            step == TutorialStep.learnPrestigeDetails ||
            step == TutorialStep.prestigeMultiplierHint ||
            step == TutorialStep.prestigeGainHint ||
            step == TutorialStep.goodLuck ||
            step == TutorialStep.nexusIntro ||
            step == TutorialStep.nexusUpgrades ||
            step == TutorialStep.nexusGoal ||
            step == TutorialStep.neuralUnlocked ||
            step == TutorialStep.neuralIntro ||
            step == TutorialStep.neuralViewAccuracy ||
            step == TutorialStep.neuralAccuracyLimit ||
            step == TutorialStep.upgradeIntro ||
            step == TutorialStep.probabilityStrikeIntro ||
            step == TutorialStep.momentumIntro ||
            step == TutorialStep.kineticSynergyIntro ||
            step == TutorialStep.overclockIntro ||
            step == TutorialStep.upgradesDone;
        final isWatchIdle = step == TutorialStep.watchIdle ||
            step == TutorialStep.triggerProbabilityStrike ||
            step == TutorialStep.buyMomentum ||
            step == TutorialStep.neuralUpgradeGradient ||
            step == TutorialStep.neuralChangeActivation ||
            step == TutorialStep.neuralBranchNeuron;
        final isNavStep = step == TutorialStep.navUpgrades ||
            step == TutorialStep.navGenerators ||
            step == TutorialStep.navUpgradesForClick ||
            step == TutorialStep.navNeural ||
            step == TutorialStep.neuralTapNeuron ||
            step == TutorialStep.navGeneratorsForStrike ||
            step == TutorialStep.navUpgradesForMomentum ||
            step == TutorialStep.navGeneratorsForMomentum ||
            step == TutorialStep.demonstrateMomentum ||
            step == TutorialStep.navUpgradesForSpecial;

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

              // Caption card — suppressed until the hole is found for buy steps
              // so the card never flashes centered and then jumps to the upgrade row.
              if (titleBody != null && (!_requiresHoleBeforeShow(step) || hole != null))
                _CaptionCard(
                  title: titleBody.$1,
                  body: titleBody.$2,
                  hole: hole,
                  screenSize: size,
                  padding: media.padding,
                  centerOnScreen: (isTapToContinue && step != TutorialStep.prestigeMultiplierHint && step != TutorialStep.prestigeGainHint && step != TutorialStep.kineticSynergyIntro && step != TutorialStep.overclockIntro && step != TutorialStep.neuralViewAccuracy) || hole == null,
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
    case TutorialStep.nexusIntro:
      return (
        'THE NEXUS',
        'You stabilized the Nexus — your hub for permanent upgrades. Each prestige earns Prestige Points (PP); spend them on research that survives every reset.',
      );
    case TutorialStep.nexusUpgrades:
      return (
        'PERMANENT RESEARCH',
        'Tap a node to spend PP. Tier I (Optimization, Surge, Enhanced Extraction) opens Tier II (Idle Foundation, Quick Resume, Kinetic Surge), then Tier III (Resonance Core, Echo Protocol). Each level stacks forever.',
      );
    case TutorialStep.nexusGoal:
      return (
        'YOUR GOAL',
        'Climb the tree all the way down to Neural Genesis. Unlocking it awakens the Neural Network — the deepest layer of the game.',
      );
    case TutorialStep.neuralUnlocked:
      return (
        'NEURAL GENESIS',
        'Neural Genesis is online — your first neuron just spawned. Let\'s take a quick tour of the most complex system in the game.',
      );
    case TutorialStep.navNeural:
      return (
        'OPEN NEURAL',
        'Tap NEURAL below to view your network.',
      );
    case TutorialStep.neuralIntro:
      return (
        'YOUR NETWORK',
        'This is your neural network. As it trains, accuracy rises — and higher accuracy multiplies ALL your gains. Let\'s upgrade it step by step.',
      );
    case TutorialStep.neuralTapNeuron:
      return (
        'TAP THE NEURON',
        'That glowing node is your first neuron. Tap it to open the upgrade panel.',
      );
    case TutorialStep.neuralUpgradeGradient:
      return null; // handled inside NeuronDetailSheet
    case TutorialStep.neuralChangeActivation:
      return null; // handled inside NeuronDetailSheet
    case TutorialStep.neuralBranchNeuron:
      return null; // handled inside NeuronDetailSheet
    case TutorialStep.neuralViewAccuracy:
      return (
        'ACCURACY & MULTIPLIER',
        'ACCURACY shows how well your network is trained. The MULT multiplier is derived directly from accuracy — the higher it climbs, the more all your gains are boosted.',
      );
    case TutorialStep.neuralAccuracyLimit:
      return (
        'ALWAYS TRAINING',
        'Accuracy can never reach 100% — it approaches the limit asymptotically. Even 95% accuracy yields a massive multiplier. Keep upgrading neurons and branching layers to train faster.',
      );
    case TutorialStep.upgradeIntro:
      return (
        'EXPLORE SPECIAL UPGRADES',
        'You\'ve got 100M to experiment! Let\'s explore some powerful upgrades and see them in action.',
      );
    case TutorialStep.probabilityStrikeIntro:
      return (
        'PROBABILITY STRIKE',
        'Each click has a 5% chance to trigger a massive strike! The damage spikes are huge. Let\'s buy it and see strikes happen.',
      );
    case TutorialStep.buyProbabilityStrike:
      return (
        'BUY IT',
        'Tap Probability Strike to purchase a level.',
      );
    case TutorialStep.navGeneratorsForStrike:
      return (
        'GO CLICK',
        'Head back to GENERATORS and click multiple times. Watch for those huge damage spikes!',
      );
    case TutorialStep.triggerProbabilityStrike:
      return (
        'KEEP CLICKING',
        'Click rapidly — every click has a 5% chance to trigger a massive strike. Watch those numbers explode!',
      );
    case TutorialStep.navUpgradesForMomentum:
      return (
        'NICE STRIKE!',
        'You saw it! Now head to UPGRADES below — there\'s another upgrade that multiplies your damage the more you click.',
      );
    case TutorialStep.momentumIntro:
      return (
        'MOMENTUM',
        'Each click builds a combo — your damage grows faster and faster as your streak continues. Let\'s buy it and watch the momentum bar climb.',
      );
    case TutorialStep.buyMomentum:
      return (
        'BUY MOMENTUM',
        'Tap Momentum to purchase a level.',
      );
    case TutorialStep.navGeneratorsForMomentum:
      return (
        'GO CLICK!',
        'Head to GENERATORS and click rapidly. Watch the momentum bar climb — the faster you click, the higher your multiplier!',
      );
    case TutorialStep.demonstrateMomentum:
      return (
        'WATCH IT GROW',
        'Click rapidly and watch the momentum bar above climb! The faster you click, the higher it climbs.',
      );
    case TutorialStep.navUpgradesForSpecial:
      return (
        'BACK TO UPGRADES',
        'Head to UPGRADES tab. We\'ll show you two more powerful upgrades.',
      );
    case TutorialStep.kineticSynergyIntro:
      return (
        'KINETIC SYNERGY',
        'Each level adds 1% of your idle income to your clicks. This bridges idle and clicking together — they work as one!',
      );
    case TutorialStep.overclockIntro:
      return (
        'OVERCLOCK',
        'Click fast enough and trigger a power surge that doubles your click power! This is your reward for intense clicking.',
      );
    case TutorialStep.upgradesDone:
      return (
        'MASTERY UNLOCKED',
        'You\'ve explored all the special upgrades! Your earnings reset now — time to play for real and climb the ranks.',
      );
    case TutorialStep.done:
      return null;
  }
}
