import 'package:flutter/foundation.dart';

import '../models/player_progress.dart';
import 'backend_service.dart';

enum SyncWinner { local, remote }

class SyncResult {
  final PlayerProgress resolved;
  final SyncWinner winner;

  const SyncResult({required this.resolved, required this.winner});
}

class SyncService {
  SyncService({BackendService? backendService})
      : _backendService = backendService ?? BackendService.instance;

  final BackendService _backendService;
  static const Duration _cloudRequestTimeout = Duration(seconds: 6);

  String? _ensuredProfileUserId;

  bool get isAvailable => _backendService.isInitialized;
  String? get currentUserId => _backendService.currentUserId;

  Future<SyncResult?> syncProgress({
    required PlayerProgress localProgress,
    required bool forceUpload,
  }) async {
    if (!isAvailable) return null;
    final userId = currentUserId;
    if (userId == null) return null;

    // The progress row needs a profile row. Creating a missing one once per
    // user per session is enough; this ran on every sync (~20s) and reset
    // the player's chosen display name each time.
    if (_ensuredProfileUserId != userId) {
      await _backendService
          .ensureProfile(userId: userId)
          .timeout(_cloudRequestTimeout);
      _ensuredProfileUserId = userId;
    }
    final remoteProgress = await _backendService
        .fetchProgress(userId: userId)
        .timeout(_cloudRequestTimeout);
    final resolved = pickWinner(
      local: localProgress,
      remote: remoteProgress,
      forceUpload: forceUpload,
    );

    await _backendService
        .upsertProgress(resolved.resolved)
        .timeout(_cloudRequestTimeout);
    return resolved;
  }

  @visibleForTesting
  static SyncResult pickWinner({
    required PlayerProgress local,
    required PlayerProgress? remote,
    required bool forceUpload,
  }) {
    if (forceUpload || remote == null) {
      return SyncResult(resolved: local, winner: SyncWinner.local);
    }

    final mergedLowestLoss = remote.neuralLowestLoss < local.neuralLowestLoss
        ? remote.neuralLowestLoss
        : local.neuralLowestLoss;

    // Achievements and lifetime taps only ever grow, so both sides are
    // merged rather than letting the timestamp winner erase the other's.
    final mergedAchievements =
        ({...local.achievements, ...remote.achievements}.toList()..sort());
    final mergedClicks = local.lifetimeClicks > remote.lifetimeClicks
        ? local.lifetimeClicks
        : remote.lifetimeClicks;

    SyncResult buildResult(PlayerProgress base, SyncWinner winner) {
      // Always carry the lifetime-best lowestLoss across both sides — it's a
      // monotonic achievement, not a per-snapshot stat, so it shouldn't get
      // overwritten when the other side happens to win the timestamp race.
      return SyncResult(
        resolved: base.copyWith(
          neuralLowestLoss: mergedLowestLoss,
          achievements: mergedAchievements,
          lifetimeClicks: mergedClicks,
        ),
        winner: winner,
      );
    }

    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return buildResult(remote, SyncWinner.remote);
    }
    if (local.updatedAt.isAfter(remote.updatedAt)) {
      return buildResult(local, SyncWinner.local);
    }

    if (remote.normalizedHighestNumber > local.normalizedHighestNumber) {
      return buildResult(remote, SyncWinner.remote);
    }
    if (remote.normalizedHighestNumber < local.normalizedHighestNumber) {
      return buildResult(local, SyncWinner.local);
    }

    if (remote.progressScore > local.progressScore) {
      return buildResult(remote, SyncWinner.remote);
    }
    if (remote.progressScore < local.progressScore) {
      return buildResult(local, SyncWinner.local);
    }
    return buildResult(local, SyncWinner.local);
  }
}
