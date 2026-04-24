import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/game_state.dart';
import 'views/unstabilized_view.dart';
import 'views/stabilized_view.dart';

class NexusScreen extends StatelessWidget {
  const NexusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prestigeCount =
        context.select<GameState, int>((g) => g.prestigeCount);
    final nexusStabilized =
        context.select<GameState, bool>((g) => g.nexusStabilized);

    if (nexusStabilized) {
      return const StabilizedView();
    }

    return prestigeCount == 0
        ? const UnstabilizedView(prestigeCount: 0)
        : UnstabilizedView(prestigeCount: prestigeCount);
  }
}
