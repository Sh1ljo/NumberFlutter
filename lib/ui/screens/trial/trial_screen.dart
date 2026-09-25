import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/backend_service.dart';
import '../../../logic/trial/trial_calendar.dart';
import '../../../logic/trial/trial_controller.dart';
import '../../../logic/trial/trial_rules.dart';
import '../../../logic/trial/trial_run.dart';
import '../../widgets/floating_tap_text.dart';
import '../../widgets/guide_overlay.dart';
import '../../widgets/tap_ripple_effect.dart';
import '../auth_screen.dart';
import 'trial_widgets.dart';

enum _BuyMode { one, ten, max }

/// The Weekly Trial: a separate run that everyone starts from zero every
/// Monday under the same modifiers.
///
/// Built to never be confused with the main game: its own amber accent, a
/// permanent "TRIAL" header with an EXIT button, and a line saying the main
/// game is still running. The main game's GameState keeps ticking under this
/// route the whole time.
class TrialScreen extends StatefulWidget {
  const TrialScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TrialScreen()),
    );
  }

  @override
  State<TrialScreen> createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> with WidgetsBindingObserver {
  late final TrialController _controller;
  final GlobalKey<FloatingTapTextLayerState> _floatingKey = GlobalKey();
  final GlobalKey<TapRippleLayerState> _rippleKey = GlobalKey();
  final GlobalKey _exitKey = GlobalKey();
  final GlobalKey _rulesKey = GlobalKey();
  final GlobalKey _tapZoneKey = GlobalKey();
  final GlobalKey _draftKey = GlobalKey();
  final GlobalKey _buildKey = GlobalKey();

  final List<DateTime> _recentTaps = [];
  _BuyMode _buyMode = _BuyMode.one;
  bool _draftOpen = false;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<TrialController>();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter());
  }

  Future<void> _enter() async {
    await _controller.enter();
    if (!mounted) return;
    setState(() => _entered = true);
    final finished = _controller.takeFinishedWeek();
    if (finished != null) await _showWeekRecap(finished);
    if (!mounted) return;
    _showAwayGain();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await GuideOverlay.showOnce(
      context,
      id: 'trial_intro_v1',
      steps: _guideSteps(),
      accent: TrialPalette.accent,
    );
  }

  List<GuideStep> _guideSteps() => [
        const GuideStep(
          icon: Icons.emoji_events_outlined,
          title: 'WELCOME TO THE WEEKLY TRIAL',
          body: 'A separate run where every player starts from zero each '
              'Monday. Your main game is not touched, and it keeps running '
              'while you are here.',
        ),
        GuideStep(
          target: _exitKey,
          icon: Icons.logout,
          title: 'EXIT ANY TIME',
          body: 'EXIT takes you straight back. The Trial keeps earning at '
              'half rate while you are away, for up to 8 hours.',
        ),
        GuideStep(
          target: _rulesKey,
          icon: Icons.casino_outlined,
          title: "THIS WEEK'S RULES",
          body: 'Every week has a new Twist and Rule that change how the '
              'game plays. Same for everyone. Tap a card for details.',
        ),
        GuideStep(
          target: _tapZoneKey,
          icon: Icons.touch_app_outlined,
          title: 'EARN',
          body: 'Tap here to earn, and spend on generators below. Your score '
              'is everything you earn this week, so buying never lowers it.',
        ),
        GuideStep(
          target: _draftKey,
          icon: Icons.style_outlined,
          title: 'DRAFTS',
          body: 'Every ×100 you earn unlocks a Draft: pick 1 of 3 perks. '
              'Everyone gets the same choices. Picking well is how you win.',
        ),
        const GuideStep(
          icon: Icons.leaderboard_outlined,
          title: 'CLIMB THE BOARDS',
          body: 'Your score posts to the Weekly board automatically when you '
              'are signed in, and each week also earns points on the '
              'Monthly board. Show up every week!',
        ),
      ];

  void _showAwayGain() {
    final gain = _controller.takeAwayGain();
    if (gain == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: TrialPalette.surface,
      behavior: SnackBarBehavior.floating,
      content: Text(
        'While you were away the Trial earned +${formatTrialNumber(gain)}',
        style: const TextStyle(color: TrialPalette.accent),
      ),
    ));
  }

  Future<void> _showWeekRecap(TrialWeekResult result) {
    final week = TrialWeek.tryParse(result.weekId);
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: TrialPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: TrialPalette.accent),
          ),
          title: Text(
            week == null
                ? 'TRIAL COMPLETE'
                : 'WEEK ${week.isoWeekNumber} COMPLETE',
            style: theme.textTheme.titleLarge
                ?.copyWith(color: TrialPalette.accent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Final score', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(formatTrialNumber(result.total),
                      style: theme.textTheme.displayMedium
                          ?.copyWith(fontSize: 34)),
                  const SizedBox(width: 10),
                  TrialTierBadge(tier: result.tier),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '+${result.points} points toward '
                '${week?.month.name ?? 'the month'}.\n'
                'A new Trial with new rules has started. Everyone is back '
                'at zero.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: TrialPalette.accent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("LET'S GO"),
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.save());
      unawaited(_controller.submit(force: true));
    } else if (state == AppLifecycleState.resumed) {
      // The tick after a long gap credits it as away time.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => mounted ? _showAwayGain() : null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.leave());
    super.dispose();
  }

  void _onTap(Offset globalPosition) {
    final now = DateTime.now();
    _recentTaps.removeWhere((t) => now.difference(t).inMilliseconds > 1000);
    if (_recentTaps.length >= 20) return;
    _recentTaps.add(now);
    final result = _controller.tap();
    if (result.gain <= 0) return;
    _floatingKey.currentState?.add(
      text: result.jackpot
          ? 'JACKPOT +${formatTrialNumber(result.gain)}'
          : '+${formatTrialNumber(result.gain)}',
      isProbabilityStrike: result.critical || result.jackpot,
      position: globalPosition - const Offset(20, 20),
    );
    _rippleKey.currentState?.add(globalPosition);
  }

  Future<void> _openDraft() async {
    final run = _controller.run;
    if (run == null || run.pendingDrafts == 0 || _draftOpen) return;
    _draftOpen = true;
    try {
      final perk = await showTrialDraftSheet(
        context,
        draftNumber: run.draftsTaken + 1,
        choices: run.draftChoices,
        owned: run.perks,
        pendingAfterThis: run.pendingDrafts - 1,
      );
      if (perk == null || !mounted) return;
      _controller.takeDraft(perk);
      if (perk == TrialPerk.windfall && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Windfall! 20 minutes of production, paid now.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      _draftOpen = false;
    }
    // Chain straight into the next one if several were waiting.
    if (mounted && (_controller.run?.pendingDrafts ?? 0) > 0) {
      await _openDraft();
    }
  }

  void _buy(TrialRun run, int i) {
    final count = switch (_buyMode) {
      _BuyMode.one => 1,
      _BuyMode.ten => 10,
      _BuyMode.max => 1 << 30,
    };
    _controller.buy(i, count: count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<TrialController>();
    final run = controller.run;
    final week = controller.week;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0D0A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _header(theme, week),
                Container(height: 2, color: TrialPalette.accent),
                if (!_entered || run == null)
                  const Expanded(
                    child: Center(
                      child:
                          CircularProgressIndicator(color: TrialPalette.accent),
                    ),
                  )
                else ...[
                  _rulesRow(week, run),
                  _scoreStrip(theme, run),
                  if (!BackendService.instance.isSignedIn) _signInHint(theme),
                  Expanded(flex: 5, child: _tapZone(theme, run)),
                  Expanded(flex: 6, child: _buildList(theme, run)),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: TapRippleLayer(key: _rippleKey)),
          ),
          Positioned.fill(
            child:
                IgnorePointer(child: FloatingTapTextLayer(key: _floatingKey)),
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, TrialWeek week) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          OutlinedButton.icon(
            key: _exitKey,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('EXIT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TrialPalette.accent,
              side: const BorderSide(color: TrialPalette.accent),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEKLY TRIAL',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    color: TrialPalette.accent,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Week ${week.isoWeekNumber} · '
                  '${formatTrialCountdown(week.remaining(_controller.now))} left',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(letterSpacing: 0.4, fontSize: 10),
                ),
                Text(
                  'Separate run · your main game keeps running',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.4,
                    fontSize: 10,
                    color: TrialPalette.accent.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'How the Trial works',
            onPressed: () => GuideOverlay.show(
              context,
              id: 'trial_intro_v1',
              steps: _guideSteps(),
              accent: TrialPalette.accent,
            ),
            icon: const Icon(Icons.help_outline, color: TrialPalette.accent),
          ),
        ],
      ),
    );
  }

  Widget _rulesRow(TrialWeek week, TrialRun run) {
    void openRules() => showTrialRulesSheet(
          context,
          week: week,
          modifiers: run.modifiers,
          perks: run.perks,
        );
    final perkCount = run.perks.values.fold<int>(0, (a, b) => a + b);
    return Padding(
      key: _rulesKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final m in run.modifiers) ...[
            Expanded(child: TrialModifierChip(modifier: m, onTap: openRules)),
            const SizedBox(width: 8),
          ],
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: openRules,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    const Icon(Icons.style_outlined,
                        size: 15, color: TrialPalette.accent),
                    const SizedBox(width: 4),
                    Text('$perkCount',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreStrip(ThemeData theme, TrialRun run) {
    final pending = run.pendingDrafts;
    return Padding(
      key: _draftKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: pending > 0
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openDraft,
                style: FilledButton.styleFrom(
                  backgroundColor: TrialPalette.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.style),
                label: Text(pending > 1
                    ? 'DRAFT READY · PICK A PERK ($pending)'
                    : 'DRAFT READY · PICK A PERK'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('SCORE ', style: theme.textTheme.labelSmall),
                    Flexible(
                      child: Text(
                        formatTrialNumber(run.totalEarned),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TrialTierBadge(tier: run.tier, compact: true),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: run.progressToNextDraft,
                          minHeight: 5,
                          backgroundColor: TrialPalette.accentDim,
                          color: TrialPalette.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'DRAFT AT ${formatTrialNumber(run.nextDraftAt)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontSize: 9.5, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _signInHint(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Playing as guest: sign in to post your score.',
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.3),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
            ),
            child: const Text('SIGN IN'),
          ),
        ],
      ),
    );
  }

  Widget _tapZone(ThemeData theme, TrialRun run) {
    final canTap = run.tappingEnabled;
    return Listener(
      key: _tapZoneKey,
      behavior: HitTestBehavior.opaque,
      onPointerDown: canTap ? (e) => _onTap(e.position) : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: RadialGradient(
            colors: [
              TrialPalette.accent.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            radius: 0.9,
          ),
          border:
              Border.all(color: TrialPalette.accent.withValues(alpha: 0.18)),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('BALANCE',
                    style:
                        theme.textTheme.labelSmall?.copyWith(letterSpacing: 4)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatTrialNumber(run.balance, fixed: true),
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+${formatTrialRate(run.liveProduction)} / sec',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: TrialPalette.accent),
                ),
                const SizedBox(height: 10),
                _twistGauge(theme, run),
                const SizedBox(height: 8),
                Text(
                  canTap
                      ? 'TAP ANYWHERE HERE · +${formatTrialRate(run.tapGain)} per tap'
                      : 'HANDS OFF · tapping is disabled this week',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontSize: 9.5, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _twistGauge(ThemeData theme, TrialRun run) {
    if (run.has(TrialModifier.momentum)) {
      final progress = (run.comboMultiplier - 1) / 3;
      return _gauge(theme,
          label: 'COMBO ×${run.comboMultiplier.toStringAsFixed(1)}',
          value: progress);
    }
    if (run.has(TrialModifier.market)) {
      final wave = TrialRun.marketWave(DateTime.now());
      final pct = (wave * 40).round();
      final label = pct <= 0
          ? 'PRICES $pct% · BUY NOW'
          : 'PRICES +$pct% · WAIT FOR THE DIP';
      return _gauge(theme, label: label, value: (1 - wave) / 2);
    }
    return const SizedBox.shrink();
  }

  Widget _gauge(ThemeData theme,
      {required String label, required double value}) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: TrialPalette.accent, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: TrialPalette.accentDim,
              color: TrialPalette.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme, TrialRun run) {
    final now = DateTime.now();
    return Column(
      key: _buildKey,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Row(
            children: [
              Text('BUILD', style: theme.textTheme.labelSmall),
              const Spacer(),
              SegmentedButton<_BuyMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: TrialPalette.accent,
                  selectedForegroundColor: Colors.black,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                segments: const [
                  ButtonSegment(value: _BuyMode.one, label: Text('×1')),
                  ButtonSegment(value: _BuyMode.ten, label: Text('×10')),
                  ButtonSegment(value: _BuyMode.max, label: Text('MAX')),
                ],
                selected: {_buyMode},
                onSelectionChanged: (s) => setState(() => _buyMode = s.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (run.tappingEnabled) _tapUpgradeRow(theme, run),
              for (var i = 0; i < run.generatorCount; i++)
                _generatorRow(theme, run, i, now),
              if (run.generatorCount < trialGenerators.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Minimalist: the top generators are closed this week.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tapUpgradeRow(ThemeData theme, TrialRun run) {
    final cost = run.tapUpgradeCost;
    return _ShopRow(
      icon: Icons.touch_app_outlined,
      title: 'Focus',
      level: 'Lv ${run.tapLevel}',
      detail: 'Taps +2 and +1.5% of your /sec',
      footnote:
          'Now: taps add ${(run.tapShareOfProduction * 100).toStringAsFixed(1)}% of /sec',
      costLabel: formatTrialNumber(cost),
      countLabel: '',
      enabled: run.balance >= cost,
      onBuy: _controller.buyTapUpgrade,
    );
  }

  Widget _generatorRow(ThemeData theme, TrialRun run, int i, DateTime now) {
    final gen = trialGenerators[i];
    final owned = run.owned[i];
    // Tiers unlock one at a time so the list never overwhelms: a tier shows
    // once you own the one below it.
    if (i > 0 && run.owned[i - 1] == 0 && owned == 0) {
      if (i == 1 || run.owned[i - 2] > 0) {
        return _LockedRow(
          hint: 'Buy a ${trialGenerators[i - 1].name} to reveal',
        );
      }
      return const SizedBox.shrink();
    }
    final count = switch (_buyMode) {
      _BuyMode.one => 1,
      _BuyMode.ten => 10,
      _BuyMode.max => run.maxAffordable(i, now).clamp(1, 1 << 30),
    };
    final cost = run.costFor(i, count, now);
    final output = run.generatorOutput(i) * run.globalMultiplier;
    final next = run.nextMilestone(owned);
    final bonus = run.has(TrialModifier.milestoneMadness) ? '×1.5' : '×2';
    return _ShopRow(
      icon: gen.icon,
      title: gen.name,
      level: '$owned',
      detail: owned == 0 ? gen.blurb : '+${formatTrialRate(output)}/s total',
      footnote: 'Next milestone $bonus at $next',
      costLabel: formatTrialNumber(cost),
      countLabel: count > 1 ? '×$count' : '',
      enabled: run.balance >= cost,
      onBuy: () => _buy(run, i),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.icon,
    required this.title,
    required this.level,
    required this.detail,
    required this.footnote,
    required this.costLabel,
    required this.countLabel,
    required this.enabled,
    required this.onBuy,
  });

  final IconData icon;
  final String title;
  final String level;
  final String detail;
  final String footnote;
  final String costLabel;
  final String countLabel;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: enabled
              ? TrialPalette.accent.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: TrialPalette.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text(level,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: TrialPalette.accent)),
                  ],
                ),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                Text(footnote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontSize: 9, letterSpacing: 0.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: FilledButton(
              onPressed: enabled ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: TrialPalette.accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: theme.colorScheme.surfaceContainerHigh,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(costLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (countLabel.isNotEmpty)
                    Text(countLabel, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Text('???', style: theme.textTheme.bodyLarge),
          const SizedBox(width: 10),
          Expanded(
            child: Text(hint,
                style:
                    theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.4)),
          ),
        ],
      ),
    );
  }
}
