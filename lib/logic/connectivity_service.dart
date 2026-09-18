import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around [Connectivity] that collapses its results down to a
/// simple online/offline signal. Every call is guarded because the platform
/// channel can be unavailable in tests or on unsupported hosts — callers
/// should never crash just because we couldn't ask the OS about the network.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// One-off check, used at boot before the stream has emitted anything.
  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _hasConnection(result);
    } catch (_) {
      // No platform support (or channel not ready) — assume online and let
      // the actual network call succeed or fail on its own merits.
      return true;
    }
  }

  /// Emits the online/offline flag only on actual transitions.
  Stream<bool> get onStatusChange {
    late final StreamController<bool> controller;
    StreamSubscription<List<ConnectivityResult>>? sub;
    bool? lastStatus;

    controller = StreamController<bool>.broadcast(
      onListen: () {
        try {
          sub = _connectivity.onConnectivityChanged.listen((results) {
            final online = _hasConnection(results);
            if (online != lastStatus) {
              lastStatus = online;
              controller.add(online);
            }
          }, onError: (_) {});
        } catch (_) {
          // Platform channel unavailable — the stream simply stays quiet.
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}
