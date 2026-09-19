import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../data/achievement_data.dart';
import '../../logic/game_state.dart';
import '../../logic/login_prompt_policy.dart';
import '../../logic/tutorial_step.dart';
import '../../logic/backend_service.dart';
import '../../utils/network_error_utils.dart';
import '../widgets/app_background.dart';
import '../widgets/offline_gains_dialog.dart';
import '../widgets/profile_editor_dialog.dart';
import 'main_game_screen.dart';
import 'upgrades_screen.dart';
import 'prestige/artifacts_view.dart';
import 'prestige/prestige_screen.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
import 'neural_network_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'more_menu_screen.dart';
import 'auth_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/tutorial_overlay.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final LoginPromptPolicy _loginPromptPolicy = LoginPromptPolicy();
  bool _loginPromptShownThisSession = false;
  bool _loginPromptSettledThisSession = false;
  bool _loginPromptCheckInFlight = false;
  bool _offlineDialogQueued = false;
  String? _promptedProfileUserId;
  bool _profilePromptInProgress = false;
  String? _lastCloudErrorNotified;
  bool _offlineNoticeVisible = false;
  bool _prestigeNoticeVisible = false;
  int? _lastPrestigeReadyNotifiedCount;
  OverlayEntry? _prestigeNoticeEntry;
  bool _reconnectNoticeVisible = false;
  OverlayEntry? _reconnectNoticeEntry;
  bool _unlockNoticeVisible = false;
  OverlayEntry? _unlockNoticeEntry;
  GameState? _gameState;

  final GlobalKey _tapAreaKey = GlobalKey();
  final GlobalKey _momentumBarKey = GlobalKey();
  final GlobalKey _neuralNeuronKey = GlobalKey();
  final GlobalKey _neuralHudKey = GlobalKey();
  final List<GlobalKey> _navKeys = List.generate(5, (_) => GlobalKey());
  final Map<String, GlobalKey> _upgradeRowKeys = {
    GameState.clickPowerId: GlobalKey(),
    GameState.autoClickerId: GlobalKey(),
    GameState.probabilityStrikeId: GlobalKey(),
    GameState.momentumId: GlobalKey(),
    GameState.kineticSynergyId: GlobalKey(),
    GameState.overclockId: GlobalKey(),
    GameState.dimensionalTapId: GlobalKey(),
    GameState.cascadeResonatorId: GlobalKey(),
    GameState.temporalCollapseId: GlobalKey(),
  };
  final GlobalKey _prestigeInitiateKey = GlobalKey();
  final GlobalKey _prestigeMultiplierKey = GlobalKey();
  final GlobalKey _prestigeGainCardKey = GlobalKey();
  final GlobalKey _nexusOptProtocolNodeKey = GlobalKey();
  final GlobalKey _idleCategoryKey = GlobalKey();

  late final List<Widget> _screens;

  /// Single place that maps a named tutorial target to its live GlobalKey.
  ///
  /// The overlay used to reach for `navKeys[1]` / `navKeys[3]` directly from a
  /// 39-case switch, and `momentumBarKey` was declared and consumed but never
  /// actually supplied — leaving `demonstrateMomentum` with no spotlight and
  /// no way to advance except ~51 consecutive clicks.
  GlobalKey? _resolveTutorialTarget(TutorialTarget target) {
    switch (target) {
      case TutorialTarget.tapArea:
        return _tapAreaKey;
      case TutorialTarget.navGenerators:
        return _navKeys[TutorialTab.generators];
      case TutorialTarget.navUpgrades:
        return _navKeys[TutorialTab.upgrades];
      case TutorialTarget.navPrestige:
        return _navKeys[TutorialTab.prestige];
      case TutorialTarget.navNeural:
        return _navKeys[TutorialTab.neural];
      case TutorialTarget.idleCategory:
        return _idleCategoryKey;
      case TutorialTarget.prestigeMultiplier:
        return _prestigeMultiplierKey;
      case TutorialTarget.prestigeGainCard:
        return _prestigeGainCardKey;
      case TutorialTarget.nexusOptProtocolNode:
        return _nexusOptProtocolNodeKey;
      case TutorialTarget.momentumBar:
        return _momentumBarKey;
      case TutorialTarget.neuralNeuron:
        return _neuralNeuronKey;
      case TutorialTarget.neuralHud:
        return _neuralHudKey;
      case TutorialTarget.upgradeAutoClicker:
        return _upgradeRowKeys[GameState.autoClickerId];
      case TutorialTarget.upgradeClickPower:
        return _upgradeRowKeys[GameState.clickPowerId];
      case TutorialTarget.upgradeProbabilityStrike:
        return _upgradeRowKeys[GameState.probabilityStrikeId];
      case TutorialTarget.upgradeMomentum:
        return _upgradeRowKeys[GameState.momentumId];
      case TutorialTarget.upgradeKineticSynergy:
        return _upgradeRowKeys[GameState.kineticSynergyId];
      case TutorialTarget.upgradeOverclock:
        return _upgradeRowKeys[GameState.overclockId];
    }
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      MainGameScreen(
        tapAreaKey: _tapAreaKey,
        momentumBarKey: _momentumBarKey,
      ),
      UpgradesScreen(upgradeRowKeys: _upgradeRowKeys, idleCategoryKey: _idleCategoryKey),
      PrestigeScreen(
        initiateButtonKey: _prestigeInitiateKey,
        prestigeMultiplierKey: _prestigeMultiplierKey,
        prestigeGainCardKey: _prestigeGainCardKey,
        nexusOptProtocolNodeKey: _nexusOptProtocolNodeKey,
      ),
      NeuralNetworkScreen(
        neuralNeuronKey: _neuralNeuronKey,
        neuralHudKey: _neuralHudKey,
      ),
      const ShopScreen(),
      const SettingsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gameState = context.read<GameState>();
      gameState.registerTutorialResetCallback(_onTutorialReset);
      _gameState = gameState;
      // Listen explicitly instead of firing these off from build(): the 100ms
      // ticker calls notifyListeners(), so anything driven from build ran
      // ~10x/s behind ad-hoc boolean guards.
      gameState.addListener(_onGameStateChanged);
      _maybeShowLoginPrompt();
      _onGameStateChanged();
    });
  }

  /// True when nothing more important owns the screen: no tutorial (main,
  /// Nexus or neural), no prestige animation, and no sheet, dialog or pushed
  /// screen on top of the main layout. Every popup waits for this rather
  /// than being dropped, so it shows as soon as the player is free.
  bool get _screenIsFree {
    final gameState = _gameState;
    if (gameState == null || !mounted) return false;
    if (gameState.isTutorialActive || gameState.isPrestigeAnimating) {
      return false;
    }
    return ModalRoute.of(context)?.isCurrent != false;
  }

  bool get _topBannerVisible =>
      _prestigeNoticeVisible || _reconnectNoticeVisible;

  void _onTutorialReset() {
    if (mounted) setState(() => _currentIndex = 0);
  }

  /// Reacts to GameState changes outside of build, so dialogs, overlays and
  /// network fetches are never triggered as a build side effect.
  void _onGameStateChanged() {
    final _perfSw = Stopwatch()..start(); // TEMP-PERF-PROBE
    try {
      _onGameStateChangedInner();
    } finally {
      _perfSw.stop(); // TEMP-PERF-PROBE
      if (_perfSw.elapsedMilliseconds > 6) {
        debugPrint('[PERF] _onGameStateChanged() took '
            '${_perfSw.elapsedMilliseconds}ms');
      }
    }
  }

  void _onGameStateChangedInner() {
    if (!mounted) return;

    // notifyListeners() can in principle land mid-frame. Inserting an
    // OverlayEntry or pushing a dialog during build or layout throws, so
    // defer to the end of the frame when that happens.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onGameStateChanged();
      });
      return;
    }

    final gameState = _gameState;
    if (gameState == null) return;

    _maybePromptForLocation();
    _maybeShowLoginPrompt();
    _maybeShowOfflineNotice(gameState.lastCloudSyncError);
    _maybeShowReconnectNotice();

    final hasOfflineProgress = gameState.offlineGainsThisSession > BigInt.zero ||
        gameState.offlineAccuracyGain > 0;
    // Hold off on the "new upgrade" popup while the offline-earnings dialog
    // is still up (or about to appear) so it doesn't stack on top of it —
    // it fires the moment the player acknowledges those earnings instead.
    // A tutorial or the prestige animation starting takes the screen back
    // from any notice already showing.
    if (gameState.isTutorialActive || gameState.isPrestigeAnimating) {
      if (_unlockNoticeVisible) _removeUnlockNotice();
      if (_prestigeNoticeVisible) _removePrestigeNotice();
    }
    if (!hasOfflineProgress) {
      // The artifact pick goes first; notices wait until it's closed.
      _maybeShowArtifactOffer();
      _maybeShowNotice();
    }

    if (!gameState.isPrestigeAnimating) {
      _maybeShowPrestigeReadyNotice(
        canPrestige: gameState.number >= gameState.prestigeRequirement,
        prestigeCount: gameState.prestigeCount,
      );
    }

    // goodLuck is the wrap-up card and belongs on the main screen.
    if (gameState.tutorialStep == TutorialStep.goodLuck && _currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }

    if (hasOfflineProgress && !_offlineDialogQueued) {
      _offlineDialogQueued = true;
      OfflineGainsDialog.show(
        context,
        gameState.offlineGainsThisSession,
        accuracyGain: gameState.offlineAccuracyGain,
        onAcknowledge: () {
          if (!mounted) return;
          context.read<GameState>().clearOfflineGains();
        },
      );
    } else if (!hasOfflineProgress && _offlineDialogQueued) {
      _offlineDialogQueued = false;
    }
  }

  /// Considers the unprompted account modal. [LoginPromptPolicy] owns the
  /// "is now a good time" decision; this only handles the parts that need a
  /// live widget tree.
  Future<void> _maybeShowLoginPrompt() async {
    if (_loginPromptSettledThisSession || _loginPromptCheckInFlight) return;
    final backend = BackendService.instance;
    if (!backend.isConfigured || !backend.isInitialized) return;

    // Cheap gates first: this runs off the game-state listener, which fires
    // ~10x/s, and must not hit SharedPreferences on every tick. A player who
    // has not reached the milestone yet simply isn't settled — they get
    // re-checked once they do.
    final gameState = _gameState ?? context.read<GameState>();
    if (!gameState.tutorialCompleted || gameState.isTutorialActive) return;
    if (gameState.highestNumber < LoginPromptPolicy.progressWorthSaving) return;

    // Another modal (offline gains, a tutorial card) owns the screen: wait
    // rather than stacking. Checked before the prefs read so this does not
    // burn the session's single decision.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    _loginPromptCheckInFlight = true;
    final bool allowed;
    try {
      allowed = await _loginPromptPolicy.shouldPrompt(
        signedIn: backend.isSignedIn,
        tutorialCompleted: gameState.tutorialCompleted,
        highestNumber: gameState.highestNumber,
      );
    } finally {
      _loginPromptCheckInFlight = false;
    }
    // Snoozes and dismissal counts cannot change under us mid-session, so a
    // "no" here is final until the next launch.
    _loginPromptSettledThisSession = true;
    if (!allowed || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loginPromptShownThisSession) return;
      // Re-checked after the frame: a dialog may have opened during the await.
      if (ModalRoute.of(context)?.isCurrent != true) {
        _loginPromptSettledThisSession = false;
        return;
      }
      _loginPromptShownThisSession = true;
      _showLoginPrompt();
    });
  }

  Future<void> _showLoginPrompt() async {
    final theme = Theme.of(context);
    final choice = await showDialog<_LoginPromptChoice>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Save Your Progress'),
        content: Text(
          'Create an account or sign in to save your progress to the cloud and compete on leaderboards.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_LoginPromptChoice.never),
            child: const Text("DON'T ASK AGAIN"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_LoginPromptChoice.later),
            child: const Text('LATER'),
          ),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(ctx).pop(_LoginPromptChoice.signIn),
            icon: const Icon(Icons.login),
            label: const Text('SIGN IN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );

    // A barrier tap is a soft no, not a free retry — otherwise dismissing the
    // cheapest way possible is the one path that gets you asked again tomorrow.
    switch (choice ?? _LoginPromptChoice.later) {
      case _LoginPromptChoice.never:
        await _loginPromptPolicy.retire();
      case _LoginPromptChoice.later:
        await _loginPromptPolicy.recordDismissed();
      case _LoginPromptChoice.signIn:
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        );
        if (BackendService.instance.isSignedIn) {
          await _loginPromptPolicy.retire();
        } else {
          // Backed out of the auth screen without finishing: same as LATER.
          await _loginPromptPolicy.recordDismissed();
        }
    }
  }

  void _maybePromptForLocation() {
    final backend = BackendService.instance;
    if (!backend.isConfigured || !backend.isInitialized) return;
    final userId = backend.currentUserId;
    if (userId == null) {
      _promptedProfileUserId = null;
      return;
    }
    if (_profilePromptInProgress || _promptedProfileUserId == userId) return;

    _profilePromptInProgress = true;
    _promptedProfileUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final profile = await backend.fetchOrCreateProfile(userId: userId);
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
        _offlineNoticeVisible ||
        !_screenIsFree) {
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

  void _maybeShowReconnectNotice() {
    final gameState = _gameState;
    if (gameState == null || _topBannerVisible) return;
    if (!gameState.consumeJustReconnected()) return;
    // Purely informational: not worth holding for later.
    if (!_screenIsFree) return;

    _reconnectNoticeVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _reconnectNoticeVisible = false;
        return;
      }
      final overlay = Overlay.of(context, rootOverlay: true);
      _reconnectNoticeEntry?.remove();
      _reconnectNoticeEntry = _TopBanner.insert(
        overlay,
        icon: Icons.wifi,
        title: 'Back Online',
        subtitle: 'Reconnected — your progress is syncing to the cloud.',
        onClosed: _removeReconnectNotice,
      );
    });
  }

  void _removeReconnectNotice() {
    _reconnectNoticeEntry?.remove();
    _reconnectNoticeEntry = null;
    _reconnectNoticeVisible = false;
  }

  /// When the last notice closed. Upgrade and achievement notices share one
  /// slot and at least [_noticeGap] of quiet between them; anything that
  /// unlocks meanwhile waits and is folded into the next notice, so a burst
  /// of progress reads as one popup instead of a stream of them.
  DateTime? _lastNoticeClosedAt;
  static const Duration _noticeGap = Duration(seconds: 30);

  void _maybeShowNotice() {
    final gameState = _gameState;
    if (gameState == null || _unlockNoticeVisible || _artifactOfferOpen) {
      return;
    }
    final upgradeIds = List<String>.from(gameState.pendingUnlockedUpgradeIds);
    final achievementIds = List<String>.from(gameState.pendingAchievementIds);
    if (upgradeIds.isEmpty && achievementIds.isEmpty) return;

    void drain() {
      for (final id in upgradeIds) {
        gameState.dismissUnlockNotice(id);
      }
      for (final id in achievementIds) {
        gameState.dismissAchievementNotice(id);
      }
    }

    // The main tutorial ends in a reset, so anything it unlocks is dropped.
    if (!gameState.tutorialCompleted) {
      drain();
      return;
    }
    // Nexus / neural tutorials, the prestige animation and open sheets
    // (neuron sheet, artifact pick, dialogs) all take priority: hold the
    // queue and fold it into one notice once the player is free.
    if (!_screenIsFree) return;

    final lastClosed = _lastNoticeClosedAt;
    if (lastClosed != null &&
        DateTime.now().difference(lastClosed) < _noticeGap) {
      return;
    }
    drain();

    final String label;
    final String message;
    final VoidCallback onTap;
    if (achievementIds.isEmpty && upgradeIds.length == 1) {
      final upgradeId = upgradeIds.first;
      final upgrade =
          gameState.upgrades.where((u) => u.id == upgradeId).firstOrNull;
      if (upgrade == null) return;
      label = 'NEW UPGRADE';
      message = upgrade.name;
      onTap = () => _revealUpgrade(upgradeId, upgrade.effectType);
    } else if (achievementIds.isEmpty) {
      label = 'NEW UPGRADES';
      message = '${upgradeIds.length} new upgrades available';
      onTap = _goToUpgradesTab;
    } else if (upgradeIds.isEmpty && achievementIds.length == 1) {
      label = 'ACHIEVEMENT · +1%';
      message = Achievements.byId(achievementIds.first)?.title ??
          'Achievement unlocked';
      onTap = () => AchievementsScreen.open(context);
    } else if (upgradeIds.isEmpty) {
      label = 'ACHIEVEMENTS · +${achievementIds.length}%';
      message = '${achievementIds.length} achievements unlocked';
      onTap = () => AchievementsScreen.open(context);
    } else {
      label = 'NEW UNLOCKS';
      message = '${upgradeIds.length} '
          '${upgradeIds.length == 1 ? 'upgrade' : 'upgrades'} · '
          '${achievementIds.length} '
          '${achievementIds.length == 1 ? 'achievement' : 'achievements'}';
      onTap = _goToUpgradesTab;
    }

    _unlockNoticeVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _unlockNoticeVisible = false;
        return;
      }
      final overlay = Overlay.of(context, rootOverlay: true);
      _unlockNoticeEntry?.remove();
      _unlockNoticeEntry = OverlayEntry(
        builder: (ctx) => _UpgradeUnlockedNotice(
          label: label,
          message: message,
          onClosed: _removeUnlockNotice,
          onTap: () {
            _removeUnlockNotice();
            onTap();
          },
        ),
      );
      overlay.insert(_unlockNoticeEntry!);
    });
  }

  /// (claimed milestones, prestige count) the artifact sheet was last shown
  /// for, so "decide later" isn't re-asked until the next prestige.
  (int, int)? _artifactOfferPromptedFor;
  bool _artifactOfferOpen = false;

  void _maybeShowArtifactOffer() {
    final gameState = _gameState;
    if (gameState == null || _artifactOfferOpen) return;
    if (!gameState.tutorialCompleted || !_screenIsFree) return;
    if (gameState.pendingArtifactChoices <= 0) return;
    final key =
        (gameState.artifactState.claimedMilestones, gameState.prestigeCount);
    if (_artifactOfferPromptedFor == key) return;
    _artifactOfferPromptedFor = key;
    _artifactOfferOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_screenIsFree) {
        // Something claimed the screen in the meantime: ask again later.
        _artifactOfferOpen = false;
        _artifactOfferPromptedFor = null;
        return;
      }
      _removeUnlockNotice();
      await ArtifactChoiceSheet.show(context);
      _artifactOfferOpen = false;
      if (!mounted) return;
      // Claiming one can leave another milestone waiting (a long-time
      // player's first launch after this update).
      final gs = _gameState;
      if (gs != null) {
        _artifactOfferPromptedFor =
            (gs.artifactState.claimedMilestones == key.$1)
                ? key
                : null;
      }
    });
  }

  void _removeUnlockNotice() {
    if (_unlockNoticeVisible) _lastNoticeClosedAt = DateTime.now();
    _unlockNoticeEntry?.remove();
    _unlockNoticeEntry = null;
    _unlockNoticeVisible = false;
  }

  /// Switches to the Upgrades tab, selects the right click/idle category, and
  /// scrolls the given upgrade row to the middle of the viewport.
  void _revealUpgrade(String upgradeId, String category) {
    context.read<GameState>().setSelectedUpgradeCategory(category);
    _goToUpgradesTab();
    _scrollToUpgradeRow(upgradeId);
  }

  void _goToUpgradesTab() {
    if (_currentIndex != 1) {
      setState(() => _currentIndex = 1);
      context.read<GameState>().onMainTabChanged(1);
    }
  }

  void _scrollToUpgradeRow(String upgradeId, [int attempt = 0]) {
    final ctx = _upgradeRowKeys[upgradeId]?.currentContext;
    if (ctx == null) {
      // The list needs a frame (or a few, after a tab/category switch) to lay
      // its rows out before the GlobalKey's context exists.
      if (attempt < 20 && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToUpgradeRow(upgradeId, attempt + 1);
        });
      }
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  void _maybeShowPrestigeReadyNotice({
    required bool canPrestige,
    required int prestigeCount,
  }) {
    if (!canPrestige ||
        _topBannerVisible ||
        _lastPrestigeReadyNotifiedCount == prestigeCount ||
        !_screenIsFree) {
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

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => MoreMenuScreen(
        onMenuItemSelected: (index) {
          Navigator.of(ctx).pop();
          if (index == _currentIndex) return;
          setState(() {
            _currentIndex = index;
          });
          context.read<GameState>().onMainTabChanged(index);
        },
      ),
    );
  }

  @override
  void dispose() {
    _removePrestigeNotice();
    _removeReconnectNotice();
    _removeUnlockNotice();
    // The reset callback is a single slot holding this State's setState, so
    // leaving it registered retained the disposed MainLayout.
    _gameState?.unregisterTutorialResetCallback(_onTutorialReset);
    _gameState?.removeListener(_onGameStateChanged);
    _gameState = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // build() is now pure. Dialogs, overlay notices, forced navigation and
    // the profile fetch all live in _onGameStateChanged, which is driven by
    // an explicit listener rather than by rebuilds.
    final isPrestigeAnimating =
        context.select<GameState, bool>((gs) => gs.isPrestigeAnimating);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
            // The nav bar is drawn on top of the active screen rather than
            // beside it, so screens have to be told about the space it eats.
            // Feeding it through MediaQuery means every screen's SafeArea and
            // every LayoutBuilder below this point sees an honest viewport —
            // which is what keeps the neural canvas from centring its network
            // into the region hidden behind the bar.
            MediaQuery(
              data: mediaQuery.copyWith(
                padding: mediaQuery.padding.copyWith(
                  bottom: mediaQuery.padding.bottom + BottomNavBar.chromeHeight,
                ),
                viewPadding: mediaQuery.viewPadding.copyWith(
                  bottom: mediaQuery.viewPadding.bottom +
                      BottomNavBar.chromeHeight,
                ),
              ),
              child: _screens[_currentIndex],
            ),
            if (!isPrestigeAnimating)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomNavBar(
                  currentIndex: _currentIndex,
                  itemKeys: _navKeys,
                  onIndexChanged: (index) {
                    // Handle "More" menu button
                    if (index == 4) {
                      _showMoreMenu(context);
                      return;
                    }
                    if (index == _currentIndex) return;
                    setState(() {
                      _currentIndex = index;
                    });
                    context.read<GameState>().onMainTabChanged(index);
                  },
                ),
              ),
            TutorialOverlay(
              resolveKey: _resolveTutorialTarget,
              currentTab: _currentIndex,
              modalRouteActive: ModalRoute.of(context)?.isCurrent == false,
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

/// Small dismissible banner that slides down from the top, auto-closes, and
/// carries an icon/title/subtitle. Used for connectivity notices.
class _TopBanner extends StatefulWidget {
  const _TopBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClosed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClosed;

  /// Inserts a [_TopBanner] into [overlay] and returns its entry.
  static OverlayEntry insert(
    OverlayState overlay, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onClosed,
  }) {
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopBanner(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onClosed: onClosed,
      ),
    );
    overlay.insert(entry);
    return entry;
  }

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
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
            key: ValueKey('top_banner_${widget.title}'),
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
                leading: Icon(widget.icon, color: theme.colorScheme.primary),
                title: Text(widget.title, style: theme.textTheme.titleMedium),
                subtitle:
                    Text(widget.subtitle, style: theme.textTheme.bodyMedium),
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

/// Slides in from the right when one or more new upgrades become available.
/// A single unlock names the upgrade and, on tap, centers it in the Upgrades
/// list; a burst of several collapses into one "N new upgrades" notice that
/// just jumps to the Upgrades tab, so a wave of unlocks doesn't spam the
/// player with a popup per upgrade.
class _UpgradeUnlockedNotice extends StatefulWidget {
  const _UpgradeUnlockedNotice({
    required this.label,
    required this.message,
    required this.onTap,
    required this.onClosed,
  });

  final String label;
  final String message;
  final VoidCallback onTap;
  final VoidCallback onClosed;

  @override
  State<_UpgradeUnlockedNotice> createState() =>
      _UpgradeUnlockedNoticeState();
}

class _UpgradeUnlockedNoticeState extends State<_UpgradeUnlockedNotice>
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
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.1, 0),
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

  void _handleTap() {
    if (_closing) return;
    _closing = true;
    widget.onTap();
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
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Align(
        // Shifted up from dead-center so it clears the "CURRENT NUMBER"
        // readout instead of sitting right beside it, while staying pinned
        // to the same right edge.
        alignment: const Alignment(1.0, -0.35),
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Dismissible(
              key: const ValueKey('upgrade_unlocked_notice'),
              direction: DismissDirection.startToEnd,
              onDismissed: (_) => _closeImmediately(),
              child: GestureDetector(
                onTap: _handleTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                        right: Radius.circular(4),
                      ),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(-2, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.new_releases,
                                color: theme.colorScheme.primary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              widget.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.message,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to view',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the player chose in the "Save Your Progress" prompt. A barrier tap
/// yields null and is read as [later].
enum _LoginPromptChoice { never, later, signIn }
