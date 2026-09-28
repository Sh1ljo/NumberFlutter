import 'package:flutter/material.dart';

import '../../../logic/backend_service.dart';
import '../../../models/leaderboard.dart';
import '../../../models/user_profile.dart';
import '../../../utils/network_error_utils.dart';
import '../auth_screen.dart';
import 'leaderboard_format.dart';
import 'player_detail_sheet.dart';
import '../../theme/app_theme.dart';

/// Loads one board; [BackendService.fetchLeaderboardPage] by default.
typedef LeaderboardLoader = Future<LeaderboardPage> Function({
  required LeaderboardMetric metric,
  String? periodId,
  String? country,
  String? city,
  bool force,
});

/// One scrollable leaderboard: optional [header] (the trial panel), metric
/// and scope controls, a podium for the top three, the ranked list, and a
/// bar pinned at the bottom with the player's own standing.
///
/// A new metric or scope keeps the current rows on screen (dimmed) until
/// the new ones arrive, then fades them in, so switching never flashes an
/// empty screen or a full-page spinner.
class RankingBoard extends StatefulWidget {
  const RankingBoard({
    super.key,
    required this.metrics,
    required this.userId,
    required this.profile,
    this.periodId,
    this.header,
    this.emptyHint,
    this.loader,
  });

  /// Selectable metrics; chips are only shown when there is more than one.
  final List<LeaderboardMetric> metrics;

  /// Signed-in player, or null to show a sign-in prompt instead of ranks.
  final String? userId;

  /// Needed for the country/city scopes. Null while loading.
  final UserProfile? profile;
  final String? periodId;
  final Widget? header;
  final String? emptyHint;

  /// Replaces the Firestore fetch, e.g. in tests.
  final LeaderboardLoader? loader;

  @override
  State<RankingBoard> createState() => _RankingBoardState();
}

class _RankingBoardState extends State<RankingBoard>
    with AutomaticKeepAliveClientMixin {
  late LeaderboardMetric _metric = widget.metrics.first;
  LeaderboardScope _scope = LeaderboardScope.global;
  String _query = '';
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _rowKeys = {};

  LeaderboardPage? _page;
  Object? _error;
  bool _loading = false;
  int _serial = 0;

  /// Bumped when new rows land, so their entrance animation replays.
  int _version = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _available {
    if (widget.loader != null) return true;
    final backend = BackendService.instance;
    return backend.isConfigured && backend.isInitialized;
  }

  bool get _hasCountry => widget.profile?.country?.isNotEmpty ?? false;
  bool get _hasCity => widget.profile?.city?.isNotEmpty ?? false;

  bool get _scopeReady {
    switch (_scope) {
      case LeaderboardScope.global:
        return true;
      case LeaderboardScope.country:
        return _hasCountry;
      case LeaderboardScope.city:
        return _hasCountry && _hasCity;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RankingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.periodId != widget.periodId) {
      _page = null;
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (widget.userId == null || !_available) return;
    if (!_scopeReady) {
      setState(() {
        _page = LeaderboardPage.empty;
        _error = null;
        _loading = false;
        _version++;
      });
      return;
    }
    final serial = ++_serial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final load =
          widget.loader ?? BackendService.instance.fetchLeaderboardPage;
      final page = await load(
        metric: _metric,
        periodId: widget.periodId,
        country:
            _scope == LeaderboardScope.global ? null : widget.profile?.country,
        city: _scope == LeaderboardScope.city ? widget.profile?.city : null,
        force: force,
      );
      if (!mounted || serial != _serial) return;
      setState(() {
        _page = page;
        _loading = false;
        _version++;
      });
    } catch (error) {
      debugPrint('Leaderboard load failed: $error');
      if (!mounted || serial != _serial) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _selectMetric(LeaderboardMetric metric) {
    if (metric == _metric) return;
    setState(() => _metric = metric);
    _load();
  }

  void _selectScope(LeaderboardScope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _load();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  String _scopeDescription() {
    final by = _metric.description;
    switch (_scope) {
      case LeaderboardScope.global:
        return 'Worldwide by $by';
      case LeaderboardScope.country:
        return _hasCountry
            ? 'In ${widget.profile!.country} by $by'
            : 'Set your country in your profile to see local ranks';
      case LeaderboardScope.city:
        return _hasCountry && _hasCity
            ? 'In ${widget.profile!.city} by $by'
            : 'Set your country and city in your profile to see city ranks';
    }
  }

  List<LeaderboardEntry> _visibleEntries() {
    final entries = _page?.entries ?? const <LeaderboardEntry>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) =>
            e.displayName.toLowerCase().contains(q) ||
            e.location.toLowerCase().contains(q))
        .toList();
  }

  void _openDetails(LeaderboardEntry entry) {
    PlayerDetailSheet.show(
      context,
      entry: entry,
      me: _page?.me,
      metric: _metric,
      periodId: widget.periodId,
      rank: entry.userId == widget.userId ? _page?.myRank : entry.rank,
    );
  }

  void _jumpToMe() {
    final me = _page?.me;
    if (me == null) return;
    final key = _rowKeys[me.userId];
    final rowContext = key?.currentContext;
    if (rowContext != null && _query.isEmpty) {
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.4,
      );
    } else {
      _openDetails(me);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final signedIn = widget.userId != null;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(force: true),
            notificationPredicate: (notification) =>
                notification.depth == 0 && signedIn && _available,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (widget.header != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: widget.header),
                  ),
                if (!_available)
                  _messageSliver(
                    theme,
                    title: 'Rankings are offline',
                    body: 'Could not reach the cloud. You can keep playing; '
                        'rankings come back once you reconnect.',
                  )
                else if (!signedIn)
                  _signInSliver(theme)
                else ...[
                  SliverToBoxAdapter(child: _controls(theme)),
                  ..._contentSlivers(theme),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
        if (signedIn && _available)
          _OwnStandingBar(
            page: _page,
            metric: _metric,
            loading: _page == null && _loading,
            emptyHint: widget.emptyHint,
            onTap: _jumpToMe,
          ),
      ],
    );
  }

  Widget _controls(ThemeData theme) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.metrics.length > 1) ...[
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.metrics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final metric = widget.metrics[index];
                  final selected = metric == _metric;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(metric.label),
                    selected: selected,
                    onSelected: (_) => _selectMetric(metric),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: SegmentedButton<LeaderboardScope>(
                  segments: [
                    const ButtonSegment(
                      value: LeaderboardScope.global,
                      label: Text('Global'),
                    ),
                    ButtonSegment(
                      value: LeaderboardScope.country,
                      label: const Text('Country'),
                      enabled: _hasCountry,
                    ),
                    ButtonSegment(
                      value: LeaderboardScope.city,
                      label: const Text('City'),
                      enabled: _hasCountry && _hasCity,
                    ),
                  ],
                  selected: {_scope},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _selectScope(s.first),
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelSmall
                        ?.copyWith(letterSpacing: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _searching ? 'Close search' : 'Search players',
                onPressed: _toggleSearch,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _searching ? Icons.close : Icons.search,
                    key: ValueKey(_searching),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _searching
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Name, city or country',
                        filled: true,
                        fillColor: AppTheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _scopeDescription(),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(letterSpacing: 0.5),
                ),
              ),
              if (_page?.totalRanked != null && _scopeReady)
                Text(
                  '${_page!.totalRanked} ranked',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(letterSpacing: 0.5),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 2,
            child: AnimatedOpacity(
              opacity: _loading && _page != null ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contentSlivers(ThemeData theme) {
    final page = _page;
    if (page == null) {
      if (_error != null) return [_errorSliver(theme)];
      return [const _SkeletonSliver()];
    }
    if (!_scopeReady) {
      return [
        _messageSliver(
          theme,
          title: 'Add your location',
          body: 'Set your country and city in your profile to compete '
              'locally.',
        ),
      ];
    }
    if (_error != null && page.entries.isEmpty) return [_errorSliver(theme)];

    final entries = _visibleEntries();
    if (entries.isEmpty) {
      return [
        _messageSliver(
          theme,
          title: _query.isEmpty ? 'No one here yet' : 'No players found',
          body: _query.isEmpty
              ? (widget.emptyHint ?? 'Be the first to rank.')
              : 'Only the top ${page.entries.length} are searchable.',
        ),
      ];
    }

    final showPodium = _query.isEmpty && entries.length >= 3;
    final listed = showPodium ? entries.skip(3).toList() : entries;
    final dimmed = _loading;

    return [
      if (showPodium)
        SliverToBoxAdapter(
          child: AnimatedOpacity(
            opacity: dimmed ? 0.45 : 1,
            duration: const Duration(milliseconds: 200),
            child: _Entrance(
              key: ValueKey('podium$_version'),
              index: 0,
              child: _Podium(
                top: entries.take(3).toList(),
                metric: _metric,
                myId: widget.userId,
                onTap: _openDetails,
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverToBoxAdapter(
          child: AnimatedOpacity(
            opacity: dimmed ? 0.45 : 1,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                for (var i = 0; i < listed.length; i++)
                  _Entrance(
                    key: ValueKey('${listed[i].userId}$_version'),
                    index: i + (showPodium ? 1 : 0),
                    child: _RankRow(
                      key: _rowKeys.putIfAbsent(
                          listed[i].userId, () => GlobalKey()),
                      entry: listed[i],
                      metric: _metric,
                      isMe: listed[i].userId == widget.userId,
                      onTap: () => _openDetails(listed[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _errorSliver(ThemeData theme) {
    final message = cloudErrorMessage(
      _error,
      offlineMessage: 'No internet connection. Rankings need to be online.',
      fallbackMessage: 'Could not load this leaderboard right now.',
    );
    return _messageSliver(
      theme,
      title: 'Couldn\'t load rankings',
      body: message,
      action: OutlinedButton(
        onPressed: () => _load(force: true),
        child: const Text('TRY AGAIN'),
      ),
    );
  }

  Widget _signInSliver(ThemeData theme) {
    return _messageSliver(
      theme,
      title: 'Sign in to compete',
      body: 'Your local progress is safe. Create an account to see where '
          'you rank and appear on the boards.',
      action: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        ),
        child: const Text('SIGN IN OR SIGN UP'),
      ),
    );
  }

  Widget _messageSliver(
    ThemeData theme, {
    required String title,
    required String body,
    Widget? action,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
        child: Column(
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.outline),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts a child in, staggered by [index]. Only the first dozen
/// rows animate; the rest are off screen anyway.
class _Entrance extends StatelessWidget {
  const _Entrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  static const int _animatedRows = 12;
  static const int _staggerMs = 35;
  static const int _rowMs = 280;

  @override
  Widget build(BuildContext context) {
    if (index >= _animatedRows) return child;
    final delay = index * _staggerMs;
    final total = delay + _rowMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.entry,
    this.size = 36,
    this.ringColor,
    this.isMe = false,
  });

  final LeaderboardEntry entry;
  final double size;
  final Color? ringColor;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe ? cs.primary : AppTheme.surfaceContainerHighest,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: 2),
      ),
      child: Text(
        entry.initials,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: size * 0.34,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
          color: isMe ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.top,
    required this.metric,
    required this.myId,
    required this.onTap,
  });

  final List<LeaderboardEntry> top;
  final LeaderboardMetric metric;
  final String? myId;
  final ValueChanged<LeaderboardEntry> onTap;

  @override
  Widget build(BuildContext context) {
    // Second, first, third: the winner stands in the middle.
    const order = [1, 0, 2];
    const heights = [64.0, 88.0, 48.0];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var slot = 0; slot < 3; slot++)
            Expanded(
              child: _PodiumSpot(
                entry: top[order[slot]],
                pedestal: heights[slot],
                metric: metric,
                isMe: top[order[slot]].userId == myId,
                onTap: () => onTap(top[order[slot]]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({
    required this.entry,
    required this.pedestal,
    required this.metric,
    required this.isMe,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final double pedestal;
  final LeaderboardMetric metric;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = LeaderboardFormat.medalFor(entry.rank) ?? AppTheme.outline;
    final winner = entry.rank == 1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _Avatar(
              entry: entry,
              size: winner ? 60 : 50,
              ringColor: medal,
              isMe: isMe,
            ),
            const SizedBox(height: 8),
            Text(
              isMe ? 'You' : entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                LeaderboardFormat.value(entry, metric),
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: pedestal,
              width: double.infinity,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    medal.withValues(alpha: 0.28),
                    medal.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Text(
                '${entry.rank}',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 22,
                  color: medal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    super.key,
    required this.entry,
    required this.metric,
    required this.isMe,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final LeaderboardMetric metric;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final medal = LeaderboardFormat.medalFor(entry.rank);
    final location = entry.location;
    final details = [
      if (location.isNotEmpty) location,
      'active ${LeaderboardFormat.lastActive(entry.updatedAt)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isMe ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isMe
              ? BorderSide(color: cs.primary.withValues(alpha: 0.35))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    '#${entry.rank}',
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      color: medal ?? AppTheme.outline,
                    ),
                  ),
                ),
                _Avatar(entry: entry, isMe: isMe, ringColor: medal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            const _YouTag(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      LeaderboardFormat.value(entry, metric),
                      style:
                          theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                    ),
                    Text(
                      LeaderboardFormat.unit(metric),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontSize: 10, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YouTag extends StatelessWidget {
  const _YouTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'YOU',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w900,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}

/// Pinned summary of where the player stands, including the gap to the
/// next player up when that player is on the page.
class _OwnStandingBar extends StatelessWidget {
  const _OwnStandingBar({
    required this.page,
    required this.metric,
    required this.loading,
    required this.emptyHint,
    required this.onTap,
  });

  final LeaderboardPage? page;
  final LeaderboardMetric metric;
  final bool loading;
  final String? emptyHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final me = page?.me;
    final rank = page?.myRank;
    final total = page?.totalRanked;

    Widget content;
    if (loading || page == null) {
      content = const SizedBox(height: 44, key: ValueKey('loading'));
    } else if (me == null) {
      content = Row(
        key: const ValueKey('absent'),
        children: [
          Expanded(
            child: Text(
              emptyHint ??
                  'You\'re not on this board yet. Your rank appears after '
                      'your next cloud sync.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.outline, fontSize: 13),
            ),
          ),
        ],
      );
    } else {
      final ahead = rank == null || rank <= 1
          ? null
          : page!.entries.where((e) => e.rank == rank - 1).firstOrNull;
      final gap = ahead == null ? null : LeaderboardFormat.gap(me, ahead, metric);
      final percentile = rank != null && total != null && total > 0
          ? (rank / total * 100).clamp(1, 100).ceil()
          : null;
      content = Row(
        key: ValueKey('me$rank${metric.name}'),
        children: [
          Text(
            rank == null ? '#—' : '#$rank',
            style: theme.textTheme.displayMedium?.copyWith(
              fontSize: 26,
              color: LeaderboardFormat.medalFor(rank ?? 0) ?? cs.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  [
                    'YOUR RANK',
                    if (percentile != null) 'TOP $percentile%',
                  ].join(' · '),
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${LeaderboardFormat.value(me, metric)} '
                  '${LeaderboardFormat.unit(metric)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (gap != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gap,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 15),
                ),
                Text(
                  'to pass #${ahead!.rank}',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppTheme.outline),
        ],
      );
    }

    return Material(
      color: AppTheme.surfaceContainerLow,
      child: InkWell(
        onTap: me == null ? null : onTap,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows shown on the very first load.
class _SkeletonSliver extends StatefulWidget {
  const _SkeletonSliver();

  @override
  State<_SkeletonSliver> createState() => _SkeletonSliverState();
}

class _SkeletonSliverState extends State<_SkeletonSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      sliver: SliverToBoxAdapter(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 0.8).animate(_pulse),
          child: Column(
            children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      bar(28, 16),
                      const SizedBox(width: 16),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(120.0 + (i % 3) * 30, 12),
                            const SizedBox(height: 6),
                            bar(80, 10),
                          ],
                        ),
                      ),
                      bar(56, 16),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
