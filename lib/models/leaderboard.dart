/// What a leaderboard ranks by. Each maps onto a field of the public
/// `leaderboard/{uid}` row (see BackendService).
enum LeaderboardMetric {
  highest(
    label: 'Highest',
    description: 'highest number',
    sortField: 'highest_number_log10',
  ),
  earned(
    label: 'Earned',
    description: 'total number earned',
    sortField: 'lifetime_earned_log10',
  ),
  prestiges(
    label: 'Prestiges',
    description: 'prestiges',
    sortField: 'prestige_count',
  ),
  accuracy(
    label: 'Accuracy',
    description: 'best neural accuracy',
    sortField: 'neural_lowest_loss',
    descending: false,
  ),
  taps(
    label: 'Taps',
    description: 'lifetime taps',
    sortField: 'lifetime_clicks',
  ),
  achievements(
    label: 'Achievements',
    description: 'achievements unlocked',
    sortField: 'achievements_count',
  ),
  weekly(
    label: 'This week',
    description: 'number earned this week',
    sortField: 'week_earned_log10',
    periodField: 'week_id',
  ),
  monthly(
    label: 'This month',
    description: 'number earned this month',
    sortField: 'month_earned_log10',
    periodField: 'month_id',
  );

  const LeaderboardMetric({
    required this.label,
    required this.description,
    required this.sortField,
    this.descending = true,
    this.periodField,
  });

  final String label;

  /// Completes "Top players worldwide by …".
  final String description;
  final String sortField;

  /// Best first means highest first, except for loss (lower is better).
  final bool descending;

  /// Set for the Trial standings, which only rank rows from the current
  /// period.
  final String? periodField;

  static const List<LeaderboardMetric> allTime = [
    highest,
    earned,
    prestiges,
    accuracy,
    taps,
    achievements,
  ];
}

enum LeaderboardScope { global, country, city }

/// One public leaderboard row.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.rank = 0,
    this.country,
    this.city,
    required this.highestNumber,
    required this.lifetimeEarned,
    this.prestigeCount,
    this.lowestLoss,
    this.taps,
    this.achievements,
    this.weekId,
    required this.weekEarned,
    this.weekDone,
    this.monthId,
    required this.monthEarned,
    this.monthDone,
    this.updatedAt,
  });

  final String userId;
  final String displayName;

  /// Dense rank within the fetched board; 0 when not ranked.
  final int rank;
  final String? country;
  final String? city;
  final BigInt highestNumber;
  final BigInt lifetimeEarned;

  /// Null on rows last uploaded by a build that didn't publish the stat.
  final int? prestigeCount;
  final double? lowestLoss;
  final int? taps;
  final int? achievements;
  final String? weekId;
  final BigInt weekEarned;
  final int? weekDone;
  final String? monthId;
  final BigInt monthEarned;
  final int? monthDone;
  final DateTime? updatedAt;

  String get location => [city, country]
      .where((v) => v != null && v.trim().isNotEmpty)
      .join(', ');

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.takeRunes(2).toUpperCase();
    }
    return (parts.first.takeRunes(1) + parts.last.takeRunes(1))
        .toUpperCase();
  }

  /// Neural accuracy in percent, or null if the network was never trained.
  double? get accuracyPercent {
    final loss = lowestLoss;
    if (loss == null) return null;
    return (1.0 - loss).clamp(0.0, 1.0) * 100.0;
  }

  /// Exact value for [metric], for sorting and tie detection. BigInt for
  /// number-like metrics, double for accuracy (as loss), int otherwise.
  Comparable<Object> valueFor(LeaderboardMetric metric) {
    switch (metric) {
      case LeaderboardMetric.highest:
        return highestNumber;
      case LeaderboardMetric.earned:
        return lifetimeEarned;
      case LeaderboardMetric.prestiges:
        return prestigeCount ?? 0;
      case LeaderboardMetric.accuracy:
        return lowestLoss ?? 1.0;
      case LeaderboardMetric.taps:
        return taps ?? 0;
      case LeaderboardMetric.achievements:
        return achievements ?? 0;
      case LeaderboardMetric.weekly:
        return weekEarned;
      case LeaderboardMetric.monthly:
        return monthEarned;
    }
  }

  LeaderboardEntry withRank(int rank) => LeaderboardEntry(
        userId: userId,
        displayName: displayName,
        rank: rank,
        country: country,
        city: city,
        highestNumber: highestNumber,
        lifetimeEarned: lifetimeEarned,
        prestigeCount: prestigeCount,
        lowestLoss: lowestLoss,
        taps: taps,
        achievements: achievements,
        weekId: weekId,
        weekEarned: weekEarned,
        weekDone: weekDone,
        monthId: monthId,
        monthEarned: monthEarned,
        monthDone: monthDone,
        updatedAt: updatedAt,
      );

  factory LeaderboardEntry.fromDatabase(
      String userId, Map<String, dynamic> data) {
    String? text(String key) {
      final value = (data[key] as String?)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    BigInt big(String key) =>
        BigInt.tryParse(data[key] as String? ?? '') ?? BigInt.zero;
    int? whole(String key) => (data[key] as num?)?.toInt();

    return LeaderboardEntry(
      userId: userId,
      displayName: text('display_name') ?? 'Player',
      country: text('country'),
      city: text('city'),
      highestNumber: big('highest_number_numeric'),
      lifetimeEarned: big('lifetime_earned_numeric'),
      prestigeCount: whole('prestige_count'),
      lowestLoss: (data['neural_lowest_loss'] as num?)?.toDouble(),
      taps: whole('lifetime_clicks'),
      achievements: whole('achievements_count'),
      weekId: text('week_id'),
      weekEarned: big('week_earned_numeric'),
      weekDone: whole('week_done'),
      monthId: text('month_id'),
      monthEarned: big('month_earned_numeric'),
      monthDone: whole('month_done'),
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? ''),
    );
  }
}

/// A fetched board plus where the signed-in player stands on it.
class LeaderboardPage {
  const LeaderboardPage({
    required this.entries,
    required this.fetchedAt,
    this.me,
    this.myRank,
    this.totalRanked,
  });

  final List<LeaderboardEntry> entries;
  final DateTime fetchedAt;

  /// The player's own row, when it has a value for this board.
  final LeaderboardEntry? me;

  /// Rank on this board: from [entries] when the player is on the page,
  /// otherwise counted server-side. Null when unknown.
  final int? myRank;

  /// How many players this board ranks, when the count was available.
  final int? totalRanked;

  static final LeaderboardPage empty =
      LeaderboardPage(entries: const [], fetchedAt: DateTime(0));
}

extension _TakeRunes on String {
  String takeRunes(int count) => String.fromCharCodes(runes.take(count));
}
