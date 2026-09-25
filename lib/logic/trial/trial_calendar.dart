/// Weekly Trial calendar. Everything is UTC so every player shares the same
/// week no matter where they are.
///
/// A Trial week runs Monday 00:00 UTC to the next Monday 00:00 UTC. There is
/// no server job that "resets" anything: each week and month simply has its
/// own leaderboard bucket, keyed by [TrialWeek.id] / [TrialMonth.id], and the
/// app starts writing to the new bucket when the date rolls over.
class TrialWeek {
  /// Monday 00:00 UTC.
  final DateTime start;

  TrialWeek._(this.start);

  /// Days since 1970-01-01 (a Thursday) of the Monday on or before [time].
  static int _mondayEpochDay(DateTime time) {
    final utc = time.toUtc();
    final day =
        DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    // 1970-01-01 is a Thursday, so Monday is 3 days "ahead" of it modulo 7.
    return day - ((day + 3) % 7);
  }

  factory TrialWeek.containing(DateTime time) {
    final monday = _mondayEpochDay(time);
    return TrialWeek._(DateTime.fromMillisecondsSinceEpoch(
      monday * Duration.millisecondsPerDay,
      isUtc: true,
    ));
  }

  factory TrialWeek.current() => TrialWeek.containing(DateTime.now());

  /// Parses an [id] ("2026-09-21"). Returns null if it isn't a Monday.
  static TrialWeek? tryParse(String id) {
    final parts = id.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final date = DateTime.utc(y, m, d);
    if (date.weekday != DateTime.monday) return null;
    return TrialWeek._(date);
  }

  /// Exclusive end: the next Monday 00:00 UTC.
  DateTime get end => start.add(const Duration(days: 7));

  /// Monday's date, e.g. "2026-09-21". Also the Firestore document id.
  String get id => _date(start);

  /// Weeks since the epoch. Seeds this week's modifiers and drafts so every
  /// player gets the same ones.
  int get index =>
      (start.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay + 3) ~/ 7;

  /// ISO-8601 week number (1..53), the number players see ("Week 39").
  int get isoWeekNumber {
    final thursday = start.add(const Duration(days: 3));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    final ordinal = thursday.difference(jan1).inDays;
    return ordinal ~/ 7 + 1;
  }

  /// A week belongs to the month its Thursday falls in (the ISO rule), so a
  /// week that straddles two months counts toward exactly one of them.
  TrialMonth get month {
    final thursday = start.add(const Duration(days: 3));
    return TrialMonth(thursday.year, thursday.month);
  }

  TrialWeek get previous =>
      TrialWeek._(start.subtract(const Duration(days: 7)));
  TrialWeek get next => TrialWeek._(end);

  Duration remaining([DateTime? now]) {
    final left = end.difference((now ?? DateTime.now()).toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  bool contains(DateTime time) {
    final utc = time.toUtc();
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  @override
  bool operator ==(Object other) => other is TrialWeek && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'TrialWeek($id)';
}

class TrialMonth {
  final int year;
  final int month;

  const TrialMonth(this.year, this.month);

  factory TrialMonth.current() => TrialWeek.current().month;

  /// "2026-09". Also the Firestore document id.
  String get id => '$year-${month.toString().padLeft(2, '0')}';

  /// Every Trial week whose Thursday lands in this month (4 or 5 of them).
  List<TrialWeek> get weeks {
    final first = DateTime.utc(year, month, 1);
    var week = TrialWeek.containing(first);
    if (week.month != this) week = week.next;
    final result = <TrialWeek>[];
    while (week.month == this) {
      result.add(week);
      week = week.next;
    }
    return result;
  }

  /// When the monthly board closes: the end of its last week.
  DateTime get end => weeks.last.end;

  Duration remaining([DateTime? now]) {
    final left = end.difference((now ?? DateTime.now()).toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  static const List<String> _names = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  String get name => _names[month - 1];

  @override
  bool operator ==(Object other) =>
      other is TrialMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'TrialMonth($id)';
}

String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// "2d 4h", "3h 12m", "8m", "<1m". Compact enough for a chip.
String formatTrialCountdown(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m';
  return '<1m';
}
