import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_state.dart';
import '../../logic/supabase_service.dart';

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
    final supabase = SupabaseService.instance;
    if (!supabase.isInitialized) return;

    _sub = supabase.authStateChanges().listen((data) {
      if (_firstAuthEvent) {
        _firstAuthEvent = false;
        return;
      }
      final signedIn = data.session != null;
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
