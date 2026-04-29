import '../models/player_progress.dart';
import 'supabase_service.dart';

enum SyncWinner { local, remote }

class SyncResult {
  final PlayerProgress resolved;
  final SyncWinner winner;

  const SyncResult({required this.resolved, required this.winner});
}

class SyncService {
  SyncService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  final SupabaseService _supabaseService;
  static const Duration _cloudRequestTimeout = Duration(seconds: 6);

  bool get isAvailable => _supabaseService.isInitialized;
  String? get currentUserId => _supabaseService.currentUser?.id;

  Future<SyncResult?> syncProgress({
    required PlayerProgress localProgress,
    required bool forceUpload,
  }) async {
    if (!isAvailable) return null;
    final userId = currentUserId;
    if (userId == null) return null;

    await _supabaseService
        .upsertProfile(userId: userId)
        .timeout(_cloudRequestTimeout);
    final remoteProgress = await _supabaseService
        .fetchProgress(userId: userId)
        .timeout(_cloudRequestTimeout);
    final resolved = _pickWinner(
      local: localProgress,
      remote: remoteProgress,
      forceUpload: forceUpload,
    );

    await _supabaseService
        .upsertProgress(resolved.resolved)
        .timeout(_cloudRequestTimeout);
    return resolved;
  }

  SyncResult _pickWinner({
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

    SyncResult buildResult(PlayerProgress base, SyncWinner winner) {
      // Always carry the lifetime-best lowestLoss across both sides — it's a
      // monotonic achievement, not a per-snapshot stat, so it shouldn't get
      // overwritten when the other side happens to win the timestamp race.
      return SyncResult(
        resolved: base.copyWith(neuralLowestLoss: mergedLowestLoss),
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
