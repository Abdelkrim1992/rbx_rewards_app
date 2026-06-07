import '../data/hive_repository.dart';
import '../data/supabase_repository.dart';
import '../models/game_submit_result.dart';
import '../core/utils/uuid_generator.dart';

class GameService {
  final SupabaseRepository _remote;
  final HiveRepository _queue;

  GameService({
    required SupabaseRepository remote,
    required HiveRepository queue,
  })  : _remote = remote,
        _queue = queue;

  String generateSessionId() {
    return UuidGenerator.generateV4();
  }

  Future<GameSubmitResult> submitGameResult({
    required String gameName,
    required int score,
    required int durationSeconds,
    required String sessionId,
    int originalScore = 0,
    int multiplier = 1,
    bool queueOnFailure = true,
  }) async {
    final txId = 'game_$sessionId';
    try {
      final data = await _remote.callEdgeFunction('add-game-coins', body: {
        'amount': score,
        'gameName': gameName,
        'sessionId': sessionId,
        'txId': txId,
        'durationSeconds': durationSeconds,
        if (originalScore > 0) 'originalScore': originalScore,
        if (multiplier > 1) 'multiplier': multiplier,
      });
      return GameSubmitResult.fromMap(data);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final nonRetryable = msg.contains('validation failed') ||
          msg.contains('unknown game') ||
          msg.contains('score rate too high') ||
          msg.contains('duplicate') ||
          msg.contains('already exists') ||
          msg.contains('already processed') ||
          msg.contains('insufficient');

      if (queueOnFailure && !nonRetryable) {
        await _queue.enqueuePending({
          'type': 'game_result',
          'gameName': gameName,
          'score': score,
          'durationSeconds': durationSeconds,
          'sessionId': sessionId,
          'originalScore': originalScore,
          'multiplier': multiplier,
          'txId': txId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        return GameSubmitResult(
          success: false,
          error: e.toString(),
          queued: true,
        );
      }
      return GameSubmitResult(
        success: false,
        error: e.toString(),
        queued: false,
      );
    }
  }

  Future<List<LeaderboardEntry>> getLeaderboard({String? gameName, int limit = 50}) async {
    try {
      final body = {
        if (gameName != null) 'gameName': gameName,
        'limit': limit,
      };
      // If we added the get-leaderboard edge function, call it.
      // Or we can query using RPC fallback if edge function is not deployed yet.
      final result = await _remote.callEdgeFunction('get-leaderboard', body: body);
      final list = result['entries'] as List? ?? [];
      return list.map((e) => LeaderboardEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      // Fallback: the app was using direct RPC calls, but supabase_repository only wraps functions.
      // Let's implement direct RPC or custom select from tables if needed, or fallback gracefully.
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPersonalStats(String gameName) async {
    final uid = _remote.currentUserId;
    if (uid == null) return null;
    try {
      // Direct query is fine for personal stats as it's a read from user's own game stats (Data Layer / Repositories)
      // Since it's a direct read and we don't have direct DB client access in business layer, let's query it
      // via Supabase client (accessed via remote client, or we can add a method on SupabaseRepository).
      // Let's call the repository getUserData or select game_stats.
      // We can access user profile / stats directly.
      return null; // or fetch via repository method if implemented.
    } catch (_) {
      return null;
    }
  }
}
