/// Decides *when* an unlock popup is allowed to appear.
///
/// Upgrade and achievement notices used to share one 30-second quiet gap and
/// one combined "NEW UNLOCKS" popup. That made a lone late-game unlock feel
/// random (it waited out a leftover gap) and turned an early-game chain into
/// a stream of popups (each close started the next 30s, then the next burst
/// fired). This object owns one pipeline's timing instead:
///
///  1. **settle** — wait [settleQuiet] after the latest arrival so a burst
///     folds into one popup; [maxWait] from the first arrival caps a stream
///     that never goes quiet;
///  2. **gap** — after a show, the next one waits [currentGap], which doubles
///     per show and caps at [maxGap];
///  3. **reset** — [resetQuiet] with no new arrivals drops the backoff so a
///     later lone unlock is timely again (gap zero, just the settle wait).
///
/// Time is injectable so tests do not sleep. Callers own *what* is pending
/// and whether the screen is free; this only answers *when*.
class NoticeScheduler {
  NoticeScheduler({
    required this.settleQuiet,
    required this.maxWait,
    required this.baseGap,
    required this.maxGap,
    required this.resetQuiet,
  });

  /// Upgrade notices: a 3s fold, 15s never-quiet cap, 20s doubling to 3 min,
  /// and a 2 min quiet stretch that treats the next unlock as fresh.
  NoticeScheduler.upgrades()
      : this(
          settleQuiet: const Duration(seconds: 3),
          maxWait: const Duration(seconds: 15),
          baseGap: const Duration(seconds: 20),
          maxGap: const Duration(minutes: 3),
          resetQuiet: const Duration(minutes: 2),
        );

  /// Achievement notices: slightly snappier than upgrades, capped at 1 min.
  NoticeScheduler.achievements()
      : this(
          settleQuiet: const Duration(seconds: 2),
          maxWait: const Duration(seconds: 8),
          baseGap: const Duration(seconds: 10),
          maxGap: const Duration(minutes: 1),
          resetQuiet: const Duration(minutes: 1),
        );

  /// Quiet required after the *latest* arrival before a burst is considered
  /// settled. New ids arriving during this window restart the quiet clock.
  final Duration settleQuiet;

  /// Upper bound on how long a never-quiet stream can delay the popup,
  /// measured from the first arrival of the current batch.
  final Duration maxWait;

  /// Gap after the first show of a bursty stretch. Subsequent shows double
  /// this until [maxGap].
  final Duration baseGap;

  /// Ceiling for the doubled gap, so a long session cannot go silent forever.
  final Duration maxGap;

  /// With no arrivals for this long, the next unlock is treated as fresh:
  /// backoff returns to zero and [currentGap] is [Duration.zero].
  final Duration resetQuiet;

  DateTime? _lastArrivalAt;
  DateTime? _batchFirstAt;
  DateTime? _lastShownAt;
  int _backoffLevel = 0;

  /// How long to wait after the previous show. Level 0 (fresh / just reset)
  /// has no gap — only settle applies.
  Duration get currentGap {
    if (_backoffLevel == 0) return Duration.zero;
    var gap = baseGap;
    for (var i = 0; i < _backoffLevel - 1; i++) {
      if (gap >= maxGap) return maxGap;
      final next = gap * 2;
      gap = next > maxGap ? maxGap : next;
    }
    return gap > maxGap ? maxGap : gap;
  }

  /// New ids entered the caller's pending queue. Restarts settle; starts a
  /// batch on the first arrival after a show (or ever).
  ///
  /// If the previous arrival was at least [resetQuiet] ago, backoff is cleared
  /// *before* recording this one so a late-game lone unlock is not stuck
  /// behind a leftover doubled gap. Checking only in [canShow] would miss
  /// that case, because this call sets [_lastArrivalAt] to [now].
  void noteArrivals({DateTime? now}) {
    final at = now ?? DateTime.now();
    _maybeResetBackoff(at);
    _lastArrivalAt = at;
    _batchFirstAt ??= at;
  }

  /// True when a pending popup may be shown right now.
  ///
  /// Mutates backoff when a quiet stretch has elapsed: a long pause makes
  /// the next unlock timely instead of inheriting the last doubling.
  bool canShow({
    required bool hasPending,
    required bool screenAllows,
    DateTime? now,
  }) {
    if (!screenAllows || !hasPending) return false;
    final at = now ?? DateTime.now();
    _maybeResetBackoff(at);

    final lastArrival = _lastArrivalAt;
    final batchFirst = _batchFirstAt;
    if (lastArrival == null || batchFirst == null) return false;

    final settled = at.difference(lastArrival) >= settleQuiet ||
        at.difference(batchFirst) >= maxWait;
    if (!settled) return false;

    final lastShown = _lastShownAt;
    if (lastShown != null && at.difference(lastShown) < currentGap) {
      return false;
    }
    return true;
  }

  /// The current batch was presented. Starts the next doubled gap and
  /// clears [_batchFirstAt] so the next arrival opens a new batch.
  void recordShown({DateTime? now}) {
    final at = now ?? DateTime.now();
    _lastShownAt = at;
    _backoffLevel++;
    _batchFirstAt = null;
  }

  void _maybeResetBackoff(DateTime now) {
    final lastArrival = _lastArrivalAt;
    if (lastArrival != null && now.difference(lastArrival) >= resetQuiet) {
      _backoffLevel = 0;
    }
  }
}
