import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../logic/supabase_service.dart';
import '../../utils/network_error_utils.dart';
import '../widgets/app_background.dart';
import '../widgets/offline_gains_dialog.dart';
import '../widgets/profile_editor_dialog.dart';
import 'main_game_screen.dart';
import 'upgrades_screen.dart';
import 'prestige/prestige_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import '../widgets/bottom_nav_bar.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _offlineDialogQueued = false;
  String? _promptedProfileUserId;
  bool _profilePromptInProgress = false;
  String? _lastCloudErrorNotified;
  bool _offlineNoticeVisible = false;

  final GlobalKey _tapAreaKey = GlobalKey();
  final List<GlobalKey> _navKeys = List.generate(5, (_) => GlobalKey());
  final Map<String, GlobalKey> _upgradeRowKeys = {
    GameState.clickPowerId: GlobalKey(),
    GameState.autoClickerId: GlobalKey(),
    GameState.probabilityStrikeId: GlobalKey(),
  };
  final GlobalKey _prestigeInitiateKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      MainGameScreen(tapAreaKey: _tapAreaKey),
      UpgradesScreen(upgradeRowKeys: _upgradeRowKeys),
      PrestigeScreen(initiateButtonKey: _prestigeInitiateKey),
      const LeaderboardScreen(),
      const SettingsScreen(),
    ];
  }

  void _maybePromptForLocation() {
    final supabase = SupabaseService.instance;
    if (!supabase.isConfigured || !supabase.isInitialized) return;
    final userId = supabase.currentSession?.user.id;
    if (userId == null) {
      _promptedProfileUserId = null;
      return;
    }
    if (_profilePromptInProgress || _promptedProfileUserId == userId) return;

    _profilePromptInProgress = true;
    _promptedProfileUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final profile = await supabase.fetchOrCreateProfile(userId: userId);
        if (!mounted) return;
        final gameState = context.read<GameState>();
        gameState.setTutorialCompletionFromProfile(profile.tutorialCompleted);
        unawaited(gameState.syncTutorialCompletedToProfileIfNeeded());
        if (profile.hasLocation) return;
        await ProfileEditorDialog.show(
          context,
          requireLocation: true,
          title: 'WHERE ARE YOU PLAYING FROM?',
          subtitle:
              'Choose your country and city so local and global rankings can work correctly.',
        );
      } catch (_) {
        _promptedProfileUserId = null;
      } finally {
        _profilePromptInProgress = false;
      }
    });
  }

  bool _isLikelyOfflineError(String message) {
    return isLikelyNetworkError(message);
  }

  void _maybeShowOfflineNotice(String? error) {
    if (error == null ||
        error == _lastCloudErrorNotified ||
        _offlineNoticeVisible) {
      return;
    }
    _lastCloudErrorNotified = error;
    if (!_isLikelyOfflineError(error)) return;

    _offlineNoticeVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _offlineNoticeVisible = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            title: Text('Offline Mode', style: theme.textTheme.titleLarge),
            content: Text(
              'No internet connection, will save when you are online. Progress will be saved locally',
              style: theme.textTheme.bodyLarge,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      _offlineNoticeVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybePromptForLocation();
    final isPrestigeAnimating =
        context.select<GameState, bool>((gs) => gs.isPrestigeAnimating);
    final cloudError =
        context.select<GameState, String?>((gs) => gs.lastCloudSyncError);
    _maybeShowOfflineNotice(cloudError);
    final offlineGains = context.select<GameState, BigInt>(
      (gs) => gs.offlineGainsThisSession,
    );

    if (offlineGains > BigInt.zero && !_offlineDialogQueued) {
      _offlineDialogQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        OfflineGainsDialog.show(
          context,
          offlineGains,
          onAcknowledge: () {
            if (!mounted) return;
            context.read<GameState>().clearOfflineGains();
          },
        );
      });
    } else if (offlineGains == BigInt.zero && _offlineDialogQueued) {
      _offlineDialogQueued = false;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
            _screens[_currentIndex],
            if (!isPrestigeAnimating)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomNavBar(
                  currentIndex: _currentIndex,
                  itemKeys: _navKeys,
                  onIndexChanged: (index) {
                    if (index == _currentIndex) return;
                    setState(() {
                      _currentIndex = index;
                    });
                    context.read<GameState>().onMainTabChanged(index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
