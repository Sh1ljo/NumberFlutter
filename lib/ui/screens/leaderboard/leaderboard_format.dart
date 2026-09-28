import 'package:flutter/material.dart';

import '../../../models/leaderboard.dart';
import '../../../models/trials.dart';
import '../../../utils/number_formatter.dart';

/// Display helpers shared by the leaderboard widgets.
class LeaderboardFormat {
  LeaderboardFormat._();

  static const Color gold = Color(0xFFE8C66A);
  static const Color silver = Color(0xFFC3C9D0);
  static const Color bronze = Color(0xFFCB8E5E);

  static Color? medalFor(int rank) {
    switch (rank) {
      case 1:
        return gold;
      case 2:
        return silver;
      case 3:
        return bronze;
      default:
        return null;
    }
  }

  static String _count(int? value) =>
      value == null ? '—' : NumberFormatter.format(BigInt.from(value));

  static String accuracy(double? percent) =>
      percent == null ? '—' : '${percent.toStringAsFixed(2)}%';

  /// The headline value of [entry] on a [metric] board.
  static String value(LeaderboardEntry entry, LeaderboardMetric metric) {
    switch (metric) {
      case LeaderboardMetric.highest:
        return NumberFormatter.format(entry.highestNumber);
      case LeaderboardMetric.earned:
        return NumberFormatter.format(entry.lifetimeEarned);
      case LeaderboardMetric.prestiges:
        return _count(entry.prestigeCount);
      case LeaderboardMetric.accuracy:
        return accuracy(entry.accuracyPercent);
      case LeaderboardMetric.taps:
        return _count(entry.taps);
      case LeaderboardMetric.achievements:
        return _count(entry.achievements);
      case LeaderboardMetric.weekly:
        return NumberFormatter.format(entry.weekEarned);
      case LeaderboardMetric.monthly:
        return NumberFormatter.format(entry.monthEarned);
    }
  }

  /// Small caption under the headline value.
  static String unit(LeaderboardMetric metric) {
    switch (metric) {
      case LeaderboardMetric.highest:
        return 'highest';
      case LeaderboardMetric.earned:
        return 'earned';
      case LeaderboardMetric.prestiges:
        return 'prestiges';
      case LeaderboardMetric.accuracy:
        return 'accuracy';
      case LeaderboardMetric.taps:
        return 'taps';
      case LeaderboardMetric.achievements:
        return 'unlocked';
      case LeaderboardMetric.weekly:
        return 'this week';
      case LeaderboardMetric.monthly:
        return 'this month';
    }
  }

  /// How far [me] trails [ahead] on [metric], e.g. "+1.20M". Null when
  /// [me] isn't behind.
  static String? gap(
    LeaderboardEntry me,
    LeaderboardEntry ahead,
    LeaderboardMetric metric,
  ) {
    final mine = me.valueFor(metric);
    final theirs = ahead.valueFor(metric);
    if (mine is BigInt && theirs is BigInt) {
      final diff = theirs - mine + BigInt.one;
      return diff > BigInt.zero ? '+${NumberFormatter.format(diff)}' : null;
    }
    if (mine is int && theirs is int) {
      final diff = theirs - mine + 1;
      return diff > 0 ? '+$diff' : null;
    }
    if (mine is double && theirs is double) {
      // Loss: lower is better, so the gap is in accuracy points.
      final diff = (mine - theirs) * 100.0;
      return diff > 0 ? '+${diff.toStringAsFixed(2)}%' : null;
    }
    return null;
  }

  /// "just now", "5m ago", "3h ago", "2d ago".
  static String lastActive(DateTime? time, {DateTime? now}) {
    if (time == null || time.millisecondsSinceEpoch <= 0) return 'unknown';
    final elapsed = (now ?? DateTime.now()).difference(time);
    if (elapsed.inMinutes < 2) return 'just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
    if (elapsed.inDays < 60) return '${elapsed.inDays}d ago';
    return '${elapsed.inDays ~/ 30}mo ago';
  }

  /// "3d 4h", "5h 12m", "14m" until [end].
  static String timeLeft(DateTime end, {DateTime? now}) {
    final left = end.difference((now ?? DateTime.now()).toUtc());
    if (left.isNegative) return 'ending';
    if (left.inDays >= 1) return '${left.inDays}d ${left.inHours % 24}h';
    if (left.inHours >= 1) return '${left.inHours}h ${left.inMinutes % 60}m';
    return '${left.inMinutes.clamp(1, 59)}m';
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  /// "September 2026" (UTC).
  static String monthTitle(DateTime now) {
    final t = now.toUtc();
    return '${_monthNames[t.month - 1]} ${t.year}';
  }

  /// First to last day of the period, e.g. "Sep 28 – Oct 4" (UTC).
  static String periodRange(TrialCadence cadence, DateTime now) {
    final start = TrialPeriods.startOf(cadence, now);
    final end = TrialPeriods.endOf(cadence, now)
        .subtract(const Duration(days: 1));
    return '${_months[start.month - 1]} ${start.day} – '
        '${_months[end.month - 1]} ${end.day}';
  }

  static String goalTitle(TrialObjective objective) {
    final target = objective.target;
    final amount = NumberFormatter.format(target);
    switch (objective.goal) {
      case TrialGoal.earn:
        return 'Earn $amount';
      case TrialGoal.taps:
        return 'Tap $amount times';
      case TrialGoal.prestiges:
        return target == BigInt.one ? 'Prestige once' : 'Prestige $amount times';
      case TrialGoal.upgrades:
        return 'Buy $amount upgrade levels';
      case TrialGoal.sparks:
        return 'Catch $amount Neural Sparks';
    }
  }

  static String goalHint(TrialGoal goal) {
    switch (goal) {
      case TrialGoal.earn:
        return 'Taps, idle and offline gains all count';
      case TrialGoal.taps:
        return 'Every tap on the main screen';
      case TrialGoal.prestiges:
        return 'Reset for prestige points';
      case TrialGoal.upgrades:
        return 'Every level bought counts, across prestiges';
      case TrialGoal.sparks:
        return 'Tap the sparks that appear on the main screen';
    }
  }

  static String pp(double amount) => '${NumberFormatter.formatGain(amount)} PP';
}
