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
  bool _prestigeNoticeVisible = false;
  int? _lastPrestigeReadyNotifiedCount;
  OverlayEntry? _prestigeNoticeEntry;

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

  void _maybeShowPrestigeReadyNotice({
    required bool canPrestige,
    required int prestigeCount,
  }) {
    if (!canPrestige ||
        _prestigeNoticeVisible ||
        _lastPrestigeReadyNotifiedCount == prestigeCount) {
      return;
    }

    _lastPrestigeReadyNotifiedCount = prestigeCount;
    _prestigeNoticeVisible = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _prestigeNoticeVisible = false;
        return;
      }

      final overlay = Overlay.of(context, rootOverlay: true);
      _prestigeNoticeEntry?.remove();
      _prestigeNoticeEntry = OverlayEntry(
        builder: (ctx) => _TopPrestigeNotice(
          onClosed: _removePrestigeNotice,
        ),
      );
      overlay.insert(_prestigeNoticeEntry!);
    });
  }

  void _removePrestigeNotice() {
    _prestigeNoticeEntry?.remove();
    _prestigeNoticeEntry = null;
    _prestigeNoticeVisible = false;
  }

  @override
  void dispose() {
    _removePrestigeNotice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _maybePromptForLocation();
    final isPrestigeAnimating =
        context.select<GameState, bool>((gs) => gs.isPrestigeAnimating);
    if (isPrestigeAnimating && _prestigeNoticeVisible) {
      _removePrestigeNotice();
    }
    final cloudError =
        context.select<GameState, String?>((gs) => gs.lastCloudSyncError);
    _maybeShowOfflineNotice(cloudError);
    final canPrestige = context
        .select<GameState, bool>((gs) => gs.number >= gs.prestigeRequirement);
    final prestigeCount =
        context.select<GameState, int>((gs) => gs.prestigeCount);
    if (!isPrestigeAnimating) {
      _maybeShowPrestigeReadyNotice(
        canPrestige: canPrestige,
        prestigeCount: prestigeCount,
      );
    }
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

class _TopPrestigeNotice extends StatefulWidget {
  const _TopPrestigeNotice({required this.onClosed});

  final VoidCallback onClosed;

  @override
  State<_TopPrestigeNotice> createState() => _TopPrestigeNoticeState();
}

class _TopPrestigeNoticeState extends State<_TopPrestigeNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _autoCloseTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _autoCloseTimer = Timer(const Duration(seconds: 4), _closeAnimated);
  }

  Future<void> _closeAnimated() async {
    if (_closing) return;
    _closing = true;
    await _controller.reverse();
    widget.onClosed();
  }

  void _closeImmediately() {
    if (_closing) return;
    _closing = true;
    widget.onClosed();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Dismissible(
            key: const ValueKey('prestige_ready_notice'),
            direction: DismissDirection.up,
            onDismissed: (_) => _closeImmediately(),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: ListTile(
                leading:
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                title: Text(
                  'Prestige Available',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  'You have enough Numbers to initiate prestige.',
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: IconButton(
                  tooltip: 'Dismiss',
                  onPressed: _closeAnimated,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
