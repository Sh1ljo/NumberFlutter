import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/backend_service.dart';
import '../../logic/trial/trial_calendar.dart';
import '../../logic/trial/trial_controller.dart';
import '../../logic/trial/trial_run.dart';
import '../widgets/guide_overlay.dart';
import '../widgets/system_loading_indicator.dart';
import '../../models/user_profile.dart';
import '../../utils/number_formatter.dart';
import '../../utils/network_error_utils.dart';
import 'auth_screen.dart';
import 'trial/trial_screen.dart';
import 'trial/trial_widgets.dart';

/// All-Time ranks the main game and never resets. Weekly and Monthly rank
/// the Trial, where everyone starts from zero.
enum LeaderboardPeriod { allTime, weekly, monthly }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    this.initialPeriod = LeaderboardPeriod.allTime,
  });

  final LeaderboardPeriod initialPeriod;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _refreshEpoch = 0;
  late LeaderboardPeriod _period = widget.initialPeriod;
  LeaderboardScope _scope = LeaderboardScope.global;
  LeaderboardMetric _metric = LeaderboardMetric.number;

  final GlobalKey _periodKey = GlobalKey();
  final GlobalKey _periodCardKey = GlobalKey();

  /// The fetch for the current user/period/metric/scope/refresh. It used to
  /// be created inside build(), so any rebuild of the auth StreamBuilder (a
  /// token refresh, a keyboard or MediaQuery change) started a new network
  /// fetch.
  String? _rowsKey;
  Future<_LeaderboardData>? _rowsFuture;

  @override
  void initState() {
    super.initState();
    final trial = context.read<TrialController>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await trial.ensureLoaded();
      if (!mounted) return;
      await GuideOverlay.showOnce(
        context,
        id: 'leaderboard_intro_v1',
        steps: _guideSteps(),
        accent: TrialPalette.accent,
      );
    });
  }

  void _selectPeriod(LeaderboardPeriod period) {
    if (!mounted || _period == period) return;
    setState(() => _period = period);
  }

  List<GuideStep> _guideSteps() => [
        GuideStep(
          target: _periodKey,
          icon: Icons.leaderboard_outlined,
          title: 'THREE LEADERBOARDS',
          body: 'ALL-TIME ranks your main game: biggest number and best '
              'accuracy. It never resets.\n\nWEEKLY and MONTHLY rank the '
              'Trial, where every player starts equal.',
          onShow: () => _selectPeriod(LeaderboardPeriod.allTime),
        ),
        GuideStep(
          target: _periodCardKey,
          icon: Icons.emoji_events_outlined,
          title: 'THE WEEKLY TRIAL',
          body: 'Each Monday everyone starts a fresh run from zero, with two '
              'modifiers that shake up the rules. Your main game is never '
              'touched. Tap ENTER to play.',
          onShow: () => _selectPeriod(LeaderboardPeriod.weekly),
        ),
        GuideStep(
          target: _periodCardKey,
          icon: Icons.calendar_month_outlined,
          title: 'MONTHLY',
          body: 'Every Trial week earns points (100 per ×10 you reach). The '
              'monthly board adds them up, so showing up every week beats '
              'one lucky week.',
          onShow: () => _selectPeriod(LeaderboardPeriod.monthly),
        ),
        GuideStep(
          icon: Icons.help_outline,
          title: "THAT'S IT",
          body: 'Tap ? at the top any time to see this again.',
          onShow: () => _selectPeriod(LeaderboardPeriod.weekly),
        ),
      ];

  String _rowsKeyFor(String userId) =>
      '${userId}_${_period.name}_${_metric.name}_${_scope.name}_$_refreshEpoch';

  Future<_LeaderboardData> _rowsFor(String key, TrialController trial) {
    if (key != _rowsKey || _rowsFuture == null) {
      _rowsKey = key;
      _rowsFuture = _fetchRows(trial);
    }
    return _rowsFuture!;
  }

  String _formatLeaderboardNumber(dynamic value) {
    final raw = value?.toString() ?? '0';
    final parsed = BigInt.tryParse(raw);
    if (parsed == null) return raw;
    return NumberFormatter.format(parsed);
  }

  /// Renders a `neural_lowest_loss` value as an "Accuracy: 99.21%" string for
  /// the loss leaderboard. Lower loss = higher accuracy = better.
  String _formatAccuracy(dynamic value) {
    final raw = (value as num?)?.toDouble();
    if (raw == null) return 'Accuracy: —';
    final accuracy = (1.0 - raw).clamp(0.0, 1.0) * 100.0;
    return 'Accuracy: ${accuracy.toStringAsFixed(2)}%';
  }

  Future<UserProfile?> _fetchProfile() async {
    final s = BackendService.instance;
    final userId = s.currentUserId;
    if (userId == null) return null;
    return s.fetchOrCreateProfile(userId: userId);
  }

  Future<_LeaderboardData> _fetchRows(TrialController trial) async {
    final s = BackendService.instance;
    if (!s.isInitialized || !s.isSignedIn) {
      return const _LeaderboardData(
          profile: null, rows: <Map<String, dynamic>>[]);
    }
    final profile = await _fetchProfile();
    String? country;
    String? city;
    if (_scope == LeaderboardScope.country) {
      country = profile?.country;
    } else if (_scope == LeaderboardScope.city) {
      country = profile?.country;
      city = profile?.city;
    }
    if (_scope == LeaderboardScope.country && (country?.isEmpty ?? true)) {
      return _LeaderboardData(
          profile: profile, rows: const <Map<String, dynamic>>[]);
    }
    if (_scope == LeaderboardScope.city &&
        ((country?.isEmpty ?? true) || (city?.isEmpty ?? true))) {
      return _LeaderboardData(
          profile: profile, rows: const <Map<String, dynamic>>[]);
    }

    if (_period == LeaderboardPeriod.allTime) {
      final rows = await s.fetchLeaderboard(
        limit: 100,
        country: country,
        city: city,
        metric: _metric == LeaderboardMetric.loss ? 'loss' : 'number',
      );
      return _LeaderboardData(profile: profile, rows: rows);
    }

    await trial.ensureLoaded();
    // Post the latest score first so the board (and your rank) include it.
    await trial.submit(force: true);
    final weekly = _period == LeaderboardPeriod.weekly;
    final board = weekly ? TrialBoard.weekly : TrialBoard.monthly;
    final periodId = weekly ? trial.week.id : trial.week.month.id;
    final rows = await s.fetchTrialLeaderboard(
      board: board,
      periodId: periodId,
      country: country,
      city: city,
    );
    final double? myScore = weekly
        ? trial.run?.scoreLog10
        : trial.monthPoints(trial.week.month).toDouble();
    int? myRank;
    if (myScore != null && myScore > 0) {
      try {
        myRank = await s.fetchTrialRank(
          board: board,
          periodId: periodId,
          score: myScore,
          country: country,
          city: city,
        );
      } catch (_) {
        // The rank line is a bonus; the board still shows without it.
      }
    }
    return _LeaderboardData(profile: profile, rows: rows, myRank: myRank);
  }

  String _title() {
    switch (_period) {
      case LeaderboardPeriod.allTime:
        return 'LEADERBOARDS';
      case LeaderboardPeriod.weekly:
        return 'WEEKLY TRIAL';
      case LeaderboardPeriod.monthly:
        return 'MONTHLY TRIAL';
    }
  }

  String _subtitleForScope(UserProfile? profile, TrialController trial) {
    final String byMetric;
    switch (_period) {
      case LeaderboardPeriod.allTime:
        byMetric = _metric == LeaderboardMetric.loss
            ? 'best neural network accuracy'
            : 'highest number';
      case LeaderboardPeriod.weekly:
        byMetric = 'Week ${trial.week.isoWeekNumber} Trial score';
      case LeaderboardPeriod.monthly:
        byMetric = '${trial.week.month.name} Trial points';
    }
    switch (_scope) {
      case LeaderboardScope.global:
        return 'Top players worldwide by $byMetric';
      case LeaderboardScope.country:
        final country = profile?.country;
        if (country == null || country.isEmpty) {
          return 'Set your country in profile to see local rankings';
        }
        return 'Top players in $country by $byMetric';
      case LeaderboardScope.city:
        final country = profile?.country;
        final city = profile?.city;
        if (country == null ||
            city == null ||
            country.isEmpty ||
            city.isEmpty) {
          return 'Set both country and city in profile to see city rankings';
        }
        return 'Top players in $city, $country by $byMetric';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = BackendService.instance;
    // Only rebuild on coarse changes. The Trial screen is pushed on top of
    // this one and ticks the controller 10x a second; the card is refreshed
    // when the player comes back instead.
    context.select<TrialController, (bool, bool, bool)>(
        (t) => (t.isLoaded, t.isActive, t.run != null));
    final trial = context.read<TrialController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _title(),
                        maxLines: 1,
                        style: theme.textTheme.displayLarge
                            ?.copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'How leaderboards work',
                    onPressed: () => GuideOverlay.show(
                      context,
                      id: 'leaderboard_intro_v1',
                      steps: _guideSteps(),
                      accent: TrialPalette.accent,
                    ),
                    icon: const Icon(Icons.help_outline),
                  ),
                ],
              ),
            ),
            Padding(
              key: _periodKey,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _PeriodSelector(
                period: _period,
                onChanged: _selectPeriod,
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),
            Expanded(
              child: !backend.isConfigured || !backend.isInitialized
                  ? _unavailable(theme, trial)
                  : StreamBuilder(
                      stream: backend.authStateChanges(),
                      builder: (context, _) {
                        final userId = backend.currentUserId;
                        if (userId == null) {
                          return _signedOut(theme, trial);
                        }
                        final rowsKey = _rowsKeyFor(userId);
                        return FutureBuilder<_LeaderboardData>(
                          key: ValueKey<String>(rowsKey),
                          future: _rowsFor(rowsKey, trial),
                          builder: (context, snapshot) =>
                              _board(theme, trial, userId, snapshot),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card at the top of the Weekly and Monthly tabs. Shown whether or not
  /// the player is signed in: the Trial itself works offline.
  Widget? _periodCard(TrialController trial) {
    switch (_period) {
      case LeaderboardPeriod.allTime:
        return null;
      case LeaderboardPeriod.weekly:
        return _TrialWeekCard(
          key: _periodCardKey,
          trial: trial,
          onEnter: () async {
            await TrialScreen.open(context);
            if (mounted) setState(() => _refreshEpoch++);
          },
        );
      case LeaderboardPeriod.monthly:
        return _TrialMonthCard(key: _periodCardKey, trial: trial);
    }
  }

  Widget _unavailable(ThemeData theme, TrialController trial) {
    final card = _periodCard(trial);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (card != null) ...[card, const SizedBox(height: 24)],
        Text(
          'Leaderboard is unavailable right now (could not reach the cloud). '
          'You can still play offline${card != null ? ', including the Trial' : ' from other tabs'}.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _signedOut(ThemeData theme, TrialController trial) {
    final card = _periodCard(trial);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (card != null) ...[card, const SizedBox(height: 28)],
        Text(
          card == null
              ? 'Sign in to view global rankings'
              : 'Sign in to post your score and see the rankings',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your local progress is unchanged. Create an account to compete on leaderboards.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('SIGN IN OR SIGN UP'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _board(
    ThemeData theme,
    TrialController trial,
    String userId,
    AsyncSnapshot<_LeaderboardData> snapshot,
  ) {
    final card = _periodCard(trial);
    final List<Widget> body;
    if (snapshot.connectionState != ConnectionState.done) {
      body = const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: SystemLoadingIndicator()),
        ),
      ];
    } else if (snapshot.hasError) {
      final message = cloudErrorMessage(
        snapshot.error,
        offlineMessage:
            'No internet connection. Leaderboard is unavailable offline.',
        fallbackMessage: 'Could not load leaderboard.',
      );
      body = [
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(message,
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        ),
      ];
    } else {
      body = _rows(theme, trial, userId, snapshot.data);
    }

    return RefreshIndicator(
      onRefresh: () async {
        final refreshed = _fetchRows(trial);
        await refreshed;
        if (!mounted) return;
        // Show the rows just fetched rather than fetching them a second time.
        setState(() {
          _refreshEpoch++;
          _rowsKey = _rowsKeyFor(userId);
          _rowsFuture = refreshed;
        });
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          if (card != null) ...[card, const SizedBox(height: 20)],
          ...body,
        ],
      ),
    );
  }

  List<Widget> _rows(ThemeData theme, TrialController trial, String userId,
      _LeaderboardData? data) {
    data ??= const _LeaderboardData(
      profile: null,
      rows: <Map<String, dynamic>>[],
    );
    final rows = data.rows;
    final profile = data.profile;
    final hasCountry = (profile?.country?.isNotEmpty ?? false);
    final hasCity = (profile?.city?.isNotEmpty ?? false);
    final missingScopeLocation =
        (_scope == LeaderboardScope.country && !hasCountry) ||
            (_scope == LeaderboardScope.city && (!hasCountry || !hasCity));
    final isTrial = _period != LeaderboardPeriod.allTime;

    return [
      Text(_subtitleForScope(profile, trial),
          style: theme.textTheme.labelSmall),
      const SizedBox(height: 14),
      // Metric only exists for All-Time: the Trial boards rank one thing.
      if (!isTrial) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Number'),
              selected: _metric == LeaderboardMetric.number,
              onSelected: (_) =>
                  setState(() => _metric = LeaderboardMetric.number),
            ),
            ChoiceChip(
              label: const Text('Accuracy'),
              selected: _metric == LeaderboardMetric.loss,
              onSelected: (_) =>
                  setState(() => _metric = LeaderboardMetric.loss),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Global'),
            selected: _scope == LeaderboardScope.global,
            onSelected: (_) => setState(() => _scope = LeaderboardScope.global),
          ),
          ChoiceChip(
            label: const Text('Country'),
            selected: _scope == LeaderboardScope.country,
            onSelected: hasCountry
                ? (_) => setState(() => _scope = LeaderboardScope.country)
                : null,
          ),
          ChoiceChip(
            label: const Text('City'),
            selected: _scope == LeaderboardScope.city,
            onSelected: hasCountry && hasCity
                ? (_) => setState(() => _scope = LeaderboardScope.city)
                : null,
          ),
        ],
      ),
      if (isTrial && data.myRank != null) ...[
        const SizedBox(height: 14),
        _YourRank(rank: data.myRank!, value: _myValueLabel(trial)),
      ],
      const SizedBox(height: 18),
      if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            missingScopeLocation
                ? 'Update your profile to view this local leaderboard.'
                : isTrial
                    ? 'No scores yet this ${_period == LeaderboardPeriod.weekly ? 'week' : 'month'}. Enter the Trial and be the first.'
                    : 'No scores yet. Be the first to rank.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        )
      else
        for (var index = 0; index < rows.length; index++)
          _rowTile(theme, rows[index], index, userId),
    ];
  }

  String _myValueLabel(TrialController trial) {
    if (_period == LeaderboardPeriod.weekly) {
      return formatTrialNumber(trial.run?.totalEarned ?? 0);
    }
    return '${trial.monthPoints(trial.week.month)} pts';
  }

  Widget _rowTile(
      ThemeData theme, Map<String, dynamic> row, int index, String userId) {
    final rank = row['rank']?.toString() ?? '${index + 1}';
    final displayName = row['display_name']?.toString() ?? 'Player';
    final isMe = row['user_id'] == userId;
    final String value;
    Widget? badge;
    switch (_period) {
      case LeaderboardPeriod.allTime:
        // Loss metric shows "Accuracy: 99.21%"; number metric shows the
        // formatted highest number.
        value = _metric == LeaderboardMetric.loss
            ? _formatAccuracy(row['neural_lowest_loss'])
            : _formatLeaderboardNumber(row['highest_number_numeric']);
      case LeaderboardPeriod.weekly:
        final total = (row['total'] as num?)?.toDouble() ?? 0;
        value = formatTrialNumber(total);
        badge = TrialTierBadge(tier: TrialTier.forScore(total), compact: true);
      case LeaderboardPeriod.monthly:
        value = '${(row['score'] as num?)?.toInt() ?? 0} pts';
    }
    final country = row['country']?.toString();
    final city = row['city']?.toString();
    final location = [city, country]
        .where((v) => v != null && v.trim().isNotEmpty)
        .join(', ');
    return Container(
      decoration: BoxDecoration(
        color: isMe ? TrialPalette.accentDim : null,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.surfaceContainerLow),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: isMe ? 8 : 0, vertical: 4),
        leading: Text('#$rank', style: theme.textTheme.titleLarge),
        title: Row(
          children: [
            Flexible(
              child: Text(
                isMe ? '$displayName (you)' : displayName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 8), badge],
          ],
        ),
        subtitle: Text(
          location.isEmpty ? value : '$value\n$location',
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final isTrial = period != LeaderboardPeriod.allTime;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<LeaderboardPeriod>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: isTrial ? TrialPalette.accent : Colors.white,
          selectedForegroundColor: Colors.black,
        ),
        segments: const [
          ButtonSegment(
            value: LeaderboardPeriod.allTime,
            label: Text('ALL-TIME'),
          ),
          ButtonSegment(
            value: LeaderboardPeriod.weekly,
            label: Text('WEEKLY'),
          ),
          ButtonSegment(
            value: LeaderboardPeriod.monthly,
            label: Text('MONTHLY'),
          ),
        ],
        selected: {period},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _TrialWeekCard extends StatelessWidget {
  const _TrialWeekCard({super.key, required this.trial, required this.onEnter});

  final TrialController trial;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final week = trial.week;
    final run = trial.run;
    final started = run != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrialPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TrialPalette.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'WEEK ${week.isoWeekNumber}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: TrialPalette.accent, fontSize: 18),
                ),
              ),
              const Icon(Icons.timer_outlined,
                  size: 14, color: TrialPalette.accent),
              const SizedBox(width: 4),
              Text(
                '${formatTrialCountdown(week.remaining(trial.now))} left',
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Everyone starts from zero. Same rules for all.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final m in trial.modifiers) ...[
                Expanded(
                  child: TrialModifierChip(
                    modifier: m,
                    onTap: () => showTrialRulesSheet(
                      context,
                      week: week,
                      modifiers: trial.modifiers,
                    ),
                  ),
                ),
                if (m != trial.modifiers.last) const SizedBox(width: 8),
              ],
            ],
          ),
          if (started) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text('YOUR SCORE  ', style: theme.textTheme.labelSmall),
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
            if (run.pendingDrafts > 0) ...[
              const SizedBox(height: 6),
              Text(
                'A DRAFT IS WAITING FOR YOU',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: TrialPalette.accent),
              ),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onEnter,
              style: FilledButton.styleFrom(
                backgroundColor: TrialPalette.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(started ? Icons.play_arrow : Icons.flag_outlined),
              label: Text(started ? 'CONTINUE TRIAL' : 'ENTER THE TRIAL'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialMonthCard extends StatelessWidget {
  const _TrialMonthCard({super.key, required this.trial});

  final TrialController trial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = trial.week.month;
    final weeks = trial.monthWeeks(month);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrialPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TrialPalette.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  month.name.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: TrialPalette.accent, fontSize: 18),
                ),
              ),
              const Icon(Icons.timer_outlined,
                  size: 14, color: TrialPalette.accent),
              const SizedBox(width: 4),
              Text(
                '${formatTrialCountdown(month.remaining(trial.now))} left',
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Each Trial week earns points. Your month is their sum.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final w in month.weeks)
                Expanded(
                  child: _WeekPoints(
                    label: 'W${w.isoWeekNumber}',
                    points: weeks[w.id],
                    isCurrent: w == trial.week,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('YOUR TOTAL  ', style: theme.textTheme.labelSmall),
              Text(
                '${trial.monthPoints(month)} pts',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekPoints extends StatelessWidget {
  const _WeekPoints({
    required this.label,
    required this.points,
    required this.isCurrent,
  });

  final String label;
  final int? points;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? TrialPalette.accentDim : null,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isCurrent
              ? TrialPalette.accent
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
          const SizedBox(height: 2),
          Text(
            points == null ? '—' : '$points',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _YourRank extends StatelessWidget {
  const _YourRank({required this.rank, required this.value});

  final int rank;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TrialPalette.accentDim,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text('YOU', style: theme.textTheme.labelSmall),
          const SizedBox(width: 12),
          Text('#$rank',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: TrialPalette.accent)),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

enum LeaderboardScope { global, country, city }

enum LeaderboardMetric { number, loss }

class _LeaderboardData {
  const _LeaderboardData({
    required this.profile,
    required this.rows,
    this.myRank,
  });

  final UserProfile? profile;
  final List<Map<String, dynamic>> rows;
  final int? myRank;
}
