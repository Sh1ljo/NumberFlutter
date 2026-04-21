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

  bool get isAvailable => _supabaseService.isInitialized;
  String? get currentUserId => _supabaseService.currentUser?.id;

  Future<SyncResult?> syncProgress({
    required PlayerProgress localProgress,
    required bool forceUpload,
  }) async {
    if (!isAvailable) return null;
    final userId = currentUserId;
    if (userId == null) return null;

    await _supabaseService.upsertProfile(userId: userId);
    final remoteProgress = await _supabaseService.fetchProgress(userId: userId);
    final resolved = _pickWinner(
      local: localProgress,
      remote: remoteProgress,
      forceUpload: forceUpload,
    );

    await _supabaseService.upsertProgress(resolved.resolved);
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

    if (remote.progressScore > local.progressScore) {
      return SyncResult(resolved: remote, winner: SyncWinner.remote);
    }
    if (remote.progressScore < local.progressScore) {
      return SyncResult(resolved: local, winner: SyncWinner.local);
    }

    if (remote.normalizedHighestNumber > local.normalizedHighestNumber) {
      return SyncResult(resolved: remote, winner: SyncWinner.remote);
    }
    if (remote.normalizedHighestNumber < local.normalizedHighestNumber) {
      return SyncResult(resolved: local, winner: SyncWinner.local);
    }

    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return SyncResult(resolved: remote, winner: SyncWinner.remote);
    }
    return SyncResult(resolved: local, winner: SyncWinner.local);
  }
}
