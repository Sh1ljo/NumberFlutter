import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import 'views/unstabilized_view.dart';
import 'views/stabilized_view.dart';

class NexusScreen extends StatelessWidget {
  final GlobalKey? optProtocolNodeKey;

  /// Spotlight target for the Nexus chapter's STABILIZE step.
  final GlobalKey? stabilizeButtonKey;
  const NexusScreen({
    super.key,
    this.optProtocolNodeKey,
    this.stabilizeButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final prestigeCount =
        context.select<GameState, int>((g) => g.prestigeCount);
    final nexusStabilized =
        context.select<GameState, bool>((g) => g.nexusStabilized);

    if (nexusStabilized) {
      return StabilizedView(optProtocolNodeKey: optProtocolNodeKey);
    }

    return UnstabilizedView(
      prestigeCount: prestigeCount,
      stabilizeButtonKey: stabilizeButtonKey,
    );
  }
}
