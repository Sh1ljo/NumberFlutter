import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_state.dart';
import '../screens/leaderboard_screen.dart';

/// Header button that opens the leaderboard, with a dot while a Trial
/// reward is waiting to be claimed.
class LeaderboardButton extends StatelessWidget {
  const LeaderboardButton({super.key, this.tooltip = 'Leaderboard'});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final claimable =
        context.select<GameState, bool>((gs) => gs.hasClaimableTrialReward);
    return IconButton(
      tooltip: claimable ? '$tooltip · trial reward ready' : tooltip,
      // Straight to the trials when there is something to collect there.
      onPressed: () => LeaderboardScreen.open(
        context,
        initialTab: claimable ? _firstClaimableTab(context) : 0,
      ),
      icon: Badge(
        isLabelVisible: claimable,
        smallSize: 8,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.emoji_events_outlined),
      ),
    );
  }

  static int _firstClaimableTab(BuildContext context) {
    final gs = context.read<GameState>();
    final counters = gs.trialCounters;
    if (gs.trials.weekly?.hasClaimable(counters) ?? false) return 1;
    return 2;
  }
}
