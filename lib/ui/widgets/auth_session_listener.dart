import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_state.dart';
import '../../logic/backend_service.dart';

/// When the user signs in after playing offline, merges local progress with cloud.
class AuthSessionListener extends StatefulWidget {
  const AuthSessionListener({required this.child, super.key});

  final Widget child;

  @override
  State<AuthSessionListener> createState() => _AuthSessionListenerState();
}

class _AuthSessionListenerState extends State<AuthSessionListener> {
  StreamSubscription<dynamic>? _sub;
  bool _firstAuthEvent = true;

  @override
  void initState() {
    super.initState();
    // This widget is built before Firebase has started (that happens on the
    // loading screen), so subscribe once it has.
    BackendService.settled.then((_) {
      if (mounted) _subscribe();
    });
  }

  void _subscribe() {
    final backend = BackendService.instance;
    if (!backend.isInitialized || _sub != null) return;

    _sub = backend.authStateChanges().listen((user) {
      if (_firstAuthEvent) {
        _firstAuthEvent = false;
        return;
      }
      final signedIn = user != null;
      if (!signedIn || !mounted) return;
      final gameState = context.read<GameState>();
      unawaited(() async {
        await gameState.refreshTutorialFromCloud();
        await gameState.syncTutorialCompletedToProfileIfNeeded();
        if (!mounted) return;
        gameState.syncWithCloud();
      }());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
