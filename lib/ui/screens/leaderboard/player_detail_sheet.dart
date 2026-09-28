import 'package:flutter/material.dart';

import '../../../data/achievement_data.dart';
import '../../../models/leaderboard.dart';
import '../../../models/trials.dart';
import '../../../utils/number_formatter.dart';
import 'leaderboard_format.dart';
import '../../theme/app_theme.dart';

/// Every public stat of one player, side by side with the viewer's own.
class PlayerDetailSheet extends StatelessWidget {
  const PlayerDetailSheet({
    super.key,
    required this.entry,
    required this.me,
    required this.metric,
    required this.rank,
    this.periodId,
  });

  final LeaderboardEntry entry;
  final LeaderboardEntry? me;
  final LeaderboardMetric metric;
  final int? rank;
  final String? periodId;

  static Future<void> show(
    BuildContext context, {
    required LeaderboardEntry entry,
    required LeaderboardEntry? me,
    required LeaderboardMetric metric,
    required int? rank,
    String? periodId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceContainerLow,
      builder: (_) => PlayerDetailSheet(
        entry: entry,
        me: me,
        metric: metric,
        rank: rank,
        periodId: periodId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMe = me != null && me!.userId == entry.userId;
    final compare = isMe ? null : me;
    final now = DateTime.now();
    final weekId = TrialPeriods.weekId(now);
    final monthId = TrialPeriods.monthId(now);
    final medal = LeaderboardFormat.medalFor(rank ?? 0);

    final stats = <_Stat>[
      _Stat(
        'Highest number',
        entry,
        compare,
        LeaderboardMetric.highest,
      ),
      _Stat(
        'Total earned',
        entry,
        compare,
        LeaderboardMetric.earned,
      ),
      _Stat(
        'Prestiges',
        entry,
        compare,
        LeaderboardMetric.prestiges,
      ),
      _Stat(
        'Neural accuracy',
        entry,
        compare,
        LeaderboardMetric.accuracy,
      ),
      _Stat(
        'Lifetime taps',
        entry,
        compare,
        LeaderboardMetric.taps,
      ),
      _Stat(
        'Achievements',
        entry,
        compare,
        LeaderboardMetric.achievements,
        suffix: ' / ${Achievements.all.length}',
      ),
      _Stat(
        'This week',
        entry,
        compare,
        LeaderboardMetric.weekly,
        current: (e) => e.weekId == weekId,
      ),
      _Stat(
        'This month',
        entry,
        compare,
        LeaderboardMetric.monthly,
        current: (e) => e.monthId == monthId,
      ),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMe ? cs.primary : AppTheme.surfaceContainerHighest,
                    border: medal == null
                        ? null
                        : Border.all(color: medal, width: 2),
                  ),
                  child: Text(
                    entry.initials,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 19,
                      color: isMe ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${entry.displayName} (you)' : entry.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (entry.location.isNotEmpty) entry.location,
                          'active ${LeaderboardFormat.lastActive(entry.updatedAt)}',
                        ].join(' · '),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
                if (rank != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '#$rank',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontSize: 28,
                          color: medal ?? cs.primary,
                        ),
                      ),
                      Text(
                        metric.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (compare != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'COMPARED WITH YOU',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final width = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final stat in stats)
                      SizedBox(
                        width: width,
                        child: _StatTile(
                          stat: stat,
                          highlighted: stat.metric == metric,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat {
  _Stat(
    this.label,
    this.entry,
    this.me,
    this.metric, {
    this.suffix = '',
    bool Function(LeaderboardEntry)? current,
  }) : current = current ?? ((_) => true);

  final String label;
  final LeaderboardEntry entry;
  final LeaderboardEntry? me;
  final LeaderboardMetric metric;
  final String suffix;

  /// Whether a row's value for this stat belongs to the current period.
  final bool Function(LeaderboardEntry) current;

  String valueOf(LeaderboardEntry e) {
    if (!current(e)) {
      return metric == LeaderboardMetric.weekly ||
              metric == LeaderboardMetric.monthly
          ? NumberFormatter.format(BigInt.zero)
          : '—';
    }
    return '${LeaderboardFormat.value(e, metric)}$suffix';
  }

  /// +1 if [entry] leads [me], -1 if it trails, 0 if even or unknown.
  int get comparison {
    final other = me;
    if (other == null) return 0;
    final a = current(entry) ? entry.valueFor(metric) : null;
    final b = current(other) ? other.valueFor(metric) : null;
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    final cmp = a.compareTo(b);
    return metric.descending ? cmp.sign : -cmp.sign;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.highlighted});

  final _Stat stat;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final me = stat.me;
    final comparison = stat.comparison;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted
            ? cs.primary.withValues(alpha: 0.08)
            : AppTheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(color: cs.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.valueOf(stat.entry),
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ),
          if (me != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (comparison != 0)
                  Icon(
                    comparison > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 18,
                    color: comparison > 0
                        ? const Color(0xFFE57373)
                        : const Color(0xFF81C784),
                  ),
                Expanded(
                  child: Text(
                    'You: ${stat.valueOf(me)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontSize: 10, letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
