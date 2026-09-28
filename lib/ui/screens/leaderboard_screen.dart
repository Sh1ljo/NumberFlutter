import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/backend_service.dart';
import '../../logic/game_state.dart';
import '../../models/leaderboard.dart';
import '../../models/trials.dart';
import '../../models/user_profile.dart';
import '../widgets/fade_slide_route.dart';
import 'leaderboard/ranking_board.dart';
import 'leaderboard/trial_panel.dart';

/// All-time rankings plus the weekly and monthly Trials, each with its own
/// standings.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.initialTab = 0});

  /// 0 all-time, 1 weekly trial, 2 monthly trial.
  final int initialTab;

  static Future<void> open(BuildContext context, {int initialTab = 0}) =>
      Navigator.of(context).push(
        FadeSlideRoute<void>(
          builder: (_) => LeaderboardScreen(initialTab: initialTab),
        ),
      );

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 2),
  );

  /// Loaded once per signed-in user; the boards need it for local scopes.
  String? _profileUserId;
  Future<UserProfile?>? _profileFuture;

  Future<UserProfile?> _profileFor(String userId) {
    if (_profileUserId != userId || _profileFuture == null) {
      _profileUserId = userId;
      _profileFuture = BackendService.instance
          .fetchOrCreateProfile(userId: userId)
          .then<UserProfile?>((p) => p)
          .catchError((Object error) {
        debugPrint('Leaderboard profile load failed: $error');
        return null;
      });
    }
    return _profileFuture!;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = BackendService.instance;
    return Scaffold(
      // Solid, not transparent: a see-through page showed the previous
      // screen through it mid-transition and then snapped to black.
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'LEADERBOARD',
                        maxLines: 1,
                        style: theme.textTheme.displayLarge
                            ?.copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle:
                  theme.textTheme.labelSmall?.copyWith(letterSpacing: 2.0),
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.outline,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(child: _TabLabel(label: 'ALL-TIME')),
                Tab(child: _TrialTabLabel(cadence: TrialCadence.weekly)),
                Tab(child: _TrialTabLabel(cadence: TrialCadence.monthly)),
              ],
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),
            Expanded(
              child: StreamBuilder<Object?>(
                stream: backend.authStateChanges(),
                builder: (context, _) {
                  final userId = backend.currentUserId;
                  if (userId == null) return _tabViews(null, null);
                  return FutureBuilder<UserProfile?>(
                    future: _profileFor(userId),
                    builder: (context, snapshot) =>
                        _tabViews(userId, snapshot.data),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabViews(String? userId, UserProfile? profile) {
    final now = DateTime.now();
    return TabBarView(
      controller: _tabs,
      children: [
        RankingBoard(
          metrics: LeaderboardMetric.allTime,
          userId: userId,
          profile: profile,
        ),
        RankingBoard(
          metrics: const [LeaderboardMetric.weekly],
          periodId: TrialPeriods.weekId(now),
          userId: userId,
          profile: profile,
          header: const TrialPanel(cadence: TrialCadence.weekly),
          emptyHint: 'Earn anything this week to join the standings. '
              'They refresh every few minutes.',
        ),
        RankingBoard(
          metrics: const [LeaderboardMetric.monthly],
          periodId: TrialPeriods.monthId(now),
          userId: userId,
          profile: profile,
          header: const TrialPanel(cadence: TrialCadence.monthly),
          emptyHint: 'Earn anything this month to join the standings. '
              'They refresh every few minutes.',
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, this.showBadge = false});

  final String label;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: showBadge
                ? Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Tab label with a dot while that trial has a reward to claim.
class _TrialTabLabel extends StatelessWidget {
  const _TrialTabLabel({required this.cadence});

  final TrialCadence cadence;

  @override
  Widget build(BuildContext context) {
    final claimable = context.select<GameState, bool>(
      (gs) => gs.trials.runFor(cadence)?.hasClaimable(gs.trialCounters) ?? false,
    );
    return _TabLabel(
      label: cadence == TrialCadence.weekly ? 'WEEKLY' : 'MONTHLY',
      showBadge: claimable,
    );
  }
}
