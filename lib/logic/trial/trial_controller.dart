import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend_service.dart';
import 'trial_calendar.dart';
import 'trial_rules.dart';
import 'trial_run.dart';

/// A finished week, kept locally for the monthly total and the
/// "week complete" recap.
class TrialWeekResult {
  final String weekId;
  final double total;
  final int points;

  const TrialWeekResult(this.weekId, this.total, this.points);

  TrialTier get tier => TrialTier.forScore(total);

  Map<String, dynamic> toJson() => {'total': total, 'points': points};

  static TrialWeekResult? fromJson(String weekId, Object? json) {
    if (json is! Map) return null;
    final total = (json['total'] as num?)?.toDouble() ?? 0;
    final points = (json['points'] as num?)?.toInt() ?? 0;
    if (!total.isFinite || total < 0 || points < 0) return null;
    return TrialWeekResult(weekId, total, points);
  }
}

/// Runs the Weekly Trial: owns the [TrialRun], ticks it while the Trial
/// screen is open, credits away time when it isn't, saves it locally and
/// posts the score to the weekly and monthly boards.
///
/// Completely separate from [GameState]: nothing here reads or writes the
/// main game, and the main game keeps running while the Trial is open.
class TrialController extends ChangeNotifier {
  TrialController({DateTime Function()? clock, math.Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? math.Random();

  final DateTime Function() _clock;
  final math.Random _random;

  static const String _runKeyPrefix = 'trial_run_v1_';
  static const String _historyKeyPrefix = 'trial_history_v1_';
  static const Duration _tickInterval = Duration(milliseconds: 100);
  static const Duration _submitInterval = Duration(seconds: 60);
  static const Duration _saveDelay = Duration(seconds: 2);

  /// A gap between ticks longer than this (app backgrounded, device asleep)
  /// counts as away time rather than live play.
  static const Duration _maxLiveGap = Duration(seconds: 5);

  DateTime get now => _clock().toUtc();

  TrialRun? _run;
  final Map<String, TrialWeekResult> _history = {};
  String? _loadedFor;
  Future<void>? _loading;
  bool _loaded = false;

  Timer? _ticker;
  Timer? _saveTimer;
  DateTime? _lastTick;
  bool _active = false;

  DateTime? _lastSubmitAt;
  double _lastSubmittedTotal = -1;
  bool _submitting = false;
  final Set<String> _mergedMonths = {};

  /// Earned while away, shown once when the player comes back.
  double? _pendingAwayGain;

  /// Set when a week closes while the player has a run in it.
  TrialWeekResult? _justFinished;

  bool get isLoaded => _loaded;
  bool get isActive => _active;

  /// This week's run, or null if the player hasn't entered this week yet.
  TrialRun? get run {
    final r = _run;
    return (r != null && r.week == TrialWeek.containing(now)) ? r : null;
  }

  TrialWeek get week => TrialWeek.containing(now);
  List<TrialModifier> get modifiers => modifiersForWeek(week);
  Map<String, TrialWeekResult> get history => Map.unmodifiable(_history);

  /// Monthly points so far for [month], including the live run.
  Map<String, int> monthWeeks(TrialMonth month) {
    final ids = month.weeks.map((w) => w.id).toSet();
    final result = <String, int>{
      for (final e in _history.entries)
        if (ids.contains(e.key)) e.key: e.value.points,
    };
    final r = run;
    if (r != null && ids.contains(r.week.id)) {
      result[r.week.id] = math.max(result[r.week.id] ?? 0, r.points);
    }
    return result;
  }

  int monthPoints(TrialMonth month) =>
      monthWeeks(month).values.fold(0, (a, b) => a + b);

  double? takeAwayGain() {
    final gain = _pendingAwayGain;
    _pendingAwayGain = null;
    return gain;
  }

  TrialWeekResult? takeFinishedWeek() {
    final result = _justFinished;
    _justFinished = null;
    return result;
  }

  // ── Loading & saving ────────────────────────────────────────────────────

  String get _owner => BackendService.instance.currentUserId ?? 'guest';

  /// Loads the save for whoever is signed in. Cheap to call repeatedly;
  /// reloads if the account changed.
  Future<void> ensureLoaded() {
    if (_loaded && _loadedFor == _owner) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final owner = _owner;
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString('$_runKeyPrefix$owner');
    var rawHistory = prefs.getString('$_historyKeyPrefix$owner');
    // A guest who signs in keeps the run they started this week.
    if (raw == null && owner != 'guest') {
      final guest = prefs.getString('${_runKeyPrefix}guest');
      final guestRun = guest == null ? null : _decodeRun(guest);
      if (guestRun != null && guestRun.week == week) {
        raw = guest;
        rawHistory ??= prefs.getString('${_historyKeyPrefix}guest');
        await prefs.remove('${_runKeyPrefix}guest');
        await prefs.remove('${_historyKeyPrefix}guest');
      }
    }
    _run = raw == null ? null : _decodeRun(raw);
    _history.clear();
    if (rawHistory != null) {
      try {
        final decoded = jsonDecode(rawHistory);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            final result = TrialWeekResult.fromJson(e.key as String, e.value);
            if (result != null) _history[result.weekId] = result;
          }
        }
      } catch (_) {
        // A corrupt history only costs the monthly breakdown.
      }
    }
    _loadedFor = owner;
    _loaded = true;
    _lastSubmittedTotal = -1;
    _mergedMonths.clear();
    _rollOverIfNeeded();
    notifyListeners();
  }

  static TrialRun? _decodeRun(String raw) {
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? TrialRun.fromJson(json) : null;
    } catch (_) {
      return null;
    }
  }

  void _scheduleSave() {
    _saveTimer ??= Timer(_saveDelay, () {
      _saveTimer = null;
      unawaited(save());
    });
  }

  Future<void> save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final owner = _loadedFor;
    if (owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final r = _run;
    if (r != null) {
      await prefs.setString('$_runKeyPrefix$owner', jsonEncode(r.toJson()));
    }
    // Two months back is all the monthly board ever needs.
    final keep = _history.values.toList()
      ..sort((a, b) => b.weekId.compareTo(a.weekId));
    await prefs.setString(
      '$_historyKeyPrefix$owner',
      jsonEncode({for (final h in keep.take(10)) h.weekId: h.toJson()}),
    );
  }

  // ── Week rollover ───────────────────────────────────────────────────────

  /// Closes a run whose week has ended: credits its away time up to the
  /// deadline, records the result, and posts the final score (the boards
  /// accept writes for a day after the week ends).
  void _rollOverIfNeeded() {
    final r = _run;
    if (r == null || r.week == week) return;
    r.applyAway(now);
    final result = TrialWeekResult(r.week.id, r.totalEarned, r.points);
    final previous = _history[r.week.id];
    if (previous == null || previous.total < result.total) {
      _history[r.week.id] = result;
    }
    if (r.totalEarned > 0) _justFinished = result;
    _run = null;
    unawaited(_submitRun(r, force: true));
    unawaited(save());
  }

  // ── Playing ─────────────────────────────────────────────────────────────

  /// Called when the Trial screen opens: starts this week's run if needed,
  /// credits time away, and starts ticking.
  Future<void> enter() async {
    await ensureLoaded();
    _rollOverIfNeeded();
    final t = now;
    if (run == null) {
      _run = TrialRun.fresh(week, t);
    } else {
      final gained = _run!.applyAway(t);
      if (gained >= 1) _pendingAwayGain = gained;
    }
    _active = true;
    _lastTick = t;
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
    notifyListeners();
    unawaited(save());
    unawaited(submit(force: true));
  }

  /// Called when the Trial screen closes. Time from here on is away time.
  Future<void> leave() async {
    _ticker?.cancel();
    _ticker = null;
    _active = false;
    final r = run;
    if (r != null) {
      final t = now;
      final last = _lastTick ?? t;
      final gap = t.difference(last);
      if (gap > Duration.zero && gap <= _maxLiveGap) {
        r.tick(gap.inMilliseconds / 1000, t);
      }
    }
    await save();
    // After the first await: this runs from the Trial screen's dispose, when
    // listeners must not be notified synchronously.
    notifyListeners();
    await submit(force: true);
  }

  void _tick() {
    final t = now;
    if (!week.contains(_run?.week.start ?? t)) {
      // The week ended while the screen was open.
      _rollOverIfNeeded();
      _run = TrialRun.fresh(week, t);
      _lastTick = t;
      notifyListeners();
      return;
    }
    final r = _run;
    if (r == null) return;
    final last = _lastTick ?? t;
    final gap = t.difference(last);
    _lastTick = t;
    if (gap > _maxLiveGap) {
      final gained = r.applyAway(t);
      if (gained >= 1) _pendingAwayGain = gained;
    } else {
      r.tick(gap.inMicroseconds / 1e6, t);
    }
    notifyListeners();
    _scheduleSave();
    _maybeSubmit();
  }

  TrialTapResult tap() {
    final r = run;
    if (r == null || !_active) return TrialTapResult.none;
    final result = r.tap(now, _random);
    _changed();
    return result;
  }

  int buy(int generator, {int count = 1}) {
    final r = run;
    if (r == null) return 0;
    final bought = r.buy(generator, now, count: count);
    if (bought > 0) _changed();
    return bought;
  }

  bool buyTapUpgrade() {
    final r = run;
    if (r == null || !r.buyTapUpgrade()) return false;
    _changed();
    return true;
  }

  bool takeDraft(TrialPerk perk) {
    final r = run;
    if (r == null || !r.takeDraft(perk)) return false;
    _changed();
    unawaited(save());
    return true;
  }

  void _changed() {
    notifyListeners();
    _scheduleSave();
  }

  // ── Posting scores ──────────────────────────────────────────────────────

  void _maybeSubmit() {
    final last = _lastSubmitAt;
    if (last == null || now.difference(last) >= _submitInterval) {
      unawaited(submit());
    }
  }

  /// Posts this week's score if it changed. Only signed-in players post;
  /// guests keep playing and post once they sign in.
  Future<void> submit({bool force = false}) async {
    final r = run;
    if (r == null) return;
    await _submitRun(r, force: force);
  }

  Future<void> _submitRun(TrialRun r, {bool force = false}) async {
    final backend = BackendService.instance;
    if (!backend.isInitialized || !backend.isSignedIn || _submitting) return;
    if (r.totalEarned <= 0) return;
    final isCurrent = identical(r, _run);
    if (isCurrent && r.totalEarned == _lastSubmittedTotal) return;
    if (!force &&
        _lastSubmitAt != null &&
        now.difference(_lastSubmitAt!) < _submitInterval) {
      return;
    }
    _submitting = true;
    _lastSubmitAt = now;
    try {
      final month = r.week.month;
      if (_mergedMonths.add(month.id)) {
        // Another device may have posted other weeks of this month.
        final remote = await backend.fetchMyTrialMonthWeeks(month.id);
        for (final e in remote.entries) {
          final local = _history[e.key];
          if (e.key != r.week.id && (local == null || local.points < e.value)) {
            _history[e.key] =
                TrialWeekResult(e.key, local?.total ?? 0, e.value);
          }
        }
      }
      final weeks = <String, int>{
        for (final w in month.weeks)
          if (_history[w.id] != null) w.id: _history[w.id]!.points,
      };
      weeks[r.week.id] = math.max(weeks[r.week.id] ?? 0, r.points);
      await backend.submitTrialScore(
        weekId: r.week.id,
        monthId: month.id,
        scoreLog10: r.scoreLog10,
        total: r.totalEarned,
        points: r.points,
        tier: r.tier.index,
        monthWeeks: weeks,
      );
      if (isCurrent) _lastSubmittedTotal = r.totalEarned;
    } catch (e) {
      // Offline or refused (e.g. the week has closed): the score stays saved
      // locally and the next submit tries again.
      debugPrint('Trial submit failed: $e');
    } finally {
      _submitting = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}
