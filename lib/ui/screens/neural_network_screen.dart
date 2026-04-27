import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../logic/supabase_service.dart';
import '../../utils/number_formatter.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'auth_screen.dart';

class NeuralNetworkScreen extends StatefulWidget {
  const NeuralNetworkScreen({super.key});

  @override
  State<NeuralNetworkScreen> createState() => _NeuralNetworkScreenState();
}

class _NeuralNetworkScreenState extends State<NeuralNetworkScreen> {
  bool _profileActionBusy = false;

  Future<void> _openProfileEditor() async {
    if (_profileActionBusy) return;
    final supabase = SupabaseService.instance;
    if (!supabase.isConfigured || !supabase.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Profile editing needs Supabase configured in assets/.env.'),
        ),
      );
      return;
    }

    setState(() {
      _profileActionBusy = true;
    });

    try {
      if (supabase.currentSession == null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        );
      }
      if (!mounted || supabase.currentSession == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _profileActionBusy = false;
        });
      }
    }
  }

  Future<void> _openLeaderboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.toll, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Selector<GameState, BigInt>(
                          selector: (_, state) => state.number,
                          builder: (context, number, child) {
                            return Text(
                              NumberFormatter.format(number),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontSize: 24),
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Ranks',
                          onPressed: _openLeaderboard,
                          icon: const Icon(Icons.emoji_events_outlined),
                        ),
                        IconButton(
                          tooltip: 'Profile',
                          onPressed: _openProfileEditor,
                          icon: const Icon(Icons.account_circle_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Text(
                'NEURAL NETWORK',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
