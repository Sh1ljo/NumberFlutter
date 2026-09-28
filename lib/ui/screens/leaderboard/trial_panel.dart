import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../logic/game_state.dart';
import '../../../models/trials.dart';
import '../../../utils/number_formatter.dart';
import 'leaderboard_format.dart';
import '../../theme/app_theme.dart';

/// The player's weekly or monthly trial: countdown, goals with live
/// progress, and claim buttons.
class TrialPanel extends StatefulWidget {
  const TrialPanel({super.key, required this.cadence});

  final TrialCadence cadence;

  @override
  State<TrialPanel> createState() => _TrialPanelState();
}

class _TrialPanelState extends State<TrialPanel> {
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    // The game rebuilds this constantly anyway; this keeps the countdown
    // honest when nothing else is changing.
    _countdown = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  bool get _weekly => widget.cadence == TrialCadence.weekly;

  void _showClaimed(double? amount) {
    if (amount == null || !mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            '+${LeaderboardFormat.pp(amount)} from the '
            '${_weekly ? 'weekly' : 'monthly'} trial',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gs = context.watch<GameState>();
    final run = gs.trials.runFor(widget.cadence);
    final now = DateTime.now().toUtc();
    final counters = gs.trialCounters;

    if (run == null) {
      return const SizedBox.shrink();
    }

    final done = run.completedCount(counters);
    final total = run.objectives.length;
    final subtitle = _weekly
        ? 'Week ${run.periodId.split('-W').last} · '
            '${LeaderboardFormat.periodRange(widget.cadence, now)}'
        : LeaderboardFormat.monthTitle(now);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _weekly ? 'WEEKLY TRIAL' : 'MONTHLY TRIAL',
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(letterSpacing: 0.4),
                    ),
                  ],
                ),
              ),
              _Pill(
                label: '${LeaderboardFormat.timeLeft(
                  TrialPeriods.endOf(widget.cadence, now),
                  now: now,
                )} left',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < done ? cs.primary : AppTheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$done of $total complete',
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          for (final objective in run.objectives)
            _ObjectiveTile(
              objective: objective,
              fraction: run.fractionOf(objective, counters),
              progress: run.progressOf(objective, counters),
              complete: run.isComplete(objective, counters),
              claimed: run.isClaimed(objective.id),
              onClaim: () => _showClaimed(
                gs.claimTrialObjective(widget.cadence, objective.id),
              ),
            ),
          const SizedBox(height: 4),
          _SweepTile(
            reward: run.sweepReward,
            ready: run.canClaimSweep(counters),
            claimed: run.isClaimed(TrialRun.sweepKey),
            remaining: total - done,
            onClaim: () =>
                _showClaimed(gs.claimTrialSweep(widget.cadence)),
          ),
          const SizedBox(height: 10),
          Text(
            'Targets are set from your progress when the '
            '${_weekly ? 'week' : 'month'} begins (UTC). Rewards are '
            'prestige points.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.outline,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveTile extends StatelessWidget {
  const _ObjectiveTile({
    required this.objective,
    required this.fraction,
    required this.progress,
    required this.complete,
    required this.claimed,
    required this.onClaim,
  });

  final TrialObjective objective;
  final double fraction;
  final BigInt progress;
  final bool complete;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shown = progress > objective.target ? objective.target : progress;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LeaderboardFormat.goalTitle(objective),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: claimed ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.outline,
                    color: claimed ? AppTheme.outline : null,
                  ),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: fraction),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      color: complete ? cs.primary : cs.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormatter.format(shown)} / '
                  '${NumberFormatter.format(objective.target)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(letterSpacing: 0.3),
                ),
                Text(
                  LeaderboardFormat.goalHint(objective.goal),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ClaimButton(
            reward: objective.reward,
            ready: complete && !claimed,
            claimed: claimed,
            onClaim: onClaim,
          ),
        ],
      ),
    );
  }
}

class _SweepTile extends StatelessWidget {
  const _SweepTile({
    required this.reward,
    required this.ready,
    required this.claimed,
    required this.remaining,
    required this.onClaim,
  });

  final double reward;
  final bool ready;
  final bool claimed;
  final int remaining;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ready
            ? cs.primary.withValues(alpha: 0.10)
            : AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clear the trial',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  claimed
                      ? 'Bonus collected'
                      : ready
                          ? 'Every goal done. Collect your bonus'
                          : '$remaining goal${remaining == 1 ? '' : 's'} left for the bonus',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ClaimButton(
            reward: reward,
            ready: ready,
            claimed: claimed,
            onClaim: onClaim,
          ),
        ],
      ),
    );
  }
}

/// Reward chip that becomes a CLAIM button when ready and a check once
/// claimed, animating between the three.
class _ClaimButton extends StatelessWidget {
  const _ClaimButton({
    required this.reward,
    required this.ready,
    required this.claimed,
    required this.onClaim,
  });

  final double reward;
  final bool ready;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (claimed) {
      child = Icon(Icons.check, key: const ValueKey('claimed'), color: AppTheme.outline);
    } else if (ready) {
      child = FilledButton(
        key: const ValueKey('ready'),
        onPressed: onClaim,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 34),
          textStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        child: Text('CLAIM ${LeaderboardFormat.pp(reward)}'),
      );
    } else {
      child = _Pill(
        key: const ValueKey('locked'),
        label: LeaderboardFormat.pp(reward),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 0.4,
          color: cs.onSurface,
        ),
      ),
    );
  }
}
