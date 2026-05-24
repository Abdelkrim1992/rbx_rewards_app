import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pending_transaction_service.dart';

/// Service for game session submission, stats, and leaderboards.
class GameService {
  final SupabaseClient? _clientOverride;

  GameService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient? get _client {
    try {
      return _clientOverride ?? Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _userId => _client?.auth.currentUser?.id;

  /// Generate a unique UUID v4 session ID.
  String generateSessionId() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant bits per RFC 4122
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Submit a completed game session to the backend.
  /// This creates a game_session record and, if valid, credits coins + updates stats.
  /// If the device is offline the call is queued for automatic retry later.
  Future<Map<String, dynamic>> submitGameResult({
    required String gameName,
    required int score,
    required int durationSeconds,
    required String sessionId,
    int originalScore = 0,
    int multiplier = 1,
  }) async {
    if (_userId == null) {
      return {
        'success': false,
        'error': 'Not authenticated',
      };
    }
    try {
      final resp = await _client!.functions.invoke(
        'add-game-coins',
        body: {
          'amount': score,
          'gameName': gameName,
          'sessionId': sessionId,
          'durationSeconds': durationSeconds,
          if (originalScore > 0) 'originalScore': originalScore,
          if (multiplier > 1) 'multiplier': multiplier,
        },
      );

      if (resp.status != 200) {
        final error = resp.data['error'] ?? 'Failed to submit game result';
        throw Exception(error);
      }

      return resp.data as Map<String, dynamic>;
    } catch (e) {
      // Queue for later retry so the user never loses a game submission.
      await PendingTransactionService.enqueue({
        'type': 'game_result',
        'gameName': gameName,
        'score': score,
        'durationSeconds': durationSeconds,
        'sessionId': sessionId,
        'originalScore': originalScore,
        'multiplier': multiplier,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      // Return optimistic success so game UIs don't break.
      return {
        'success': true,
        'balance': 0,
        'coinsEarned': score,
        'queued': true,
      };
    }
  }

  /// Get leaderboard for a specific game, or weekly overall leaderboard if no gameName is provided.
  Future<List<Map<String, dynamic>>> getLeaderboard(
      {String? gameName, int limit = 50}) async {
    if (_client == null) return [];
    if (gameName != null) {
      final data = await _client!.rpc('get_leaderboard', params: {
        'p_game_name': gameName,
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(data);
    } else {
      final data = await _client!.rpc('get_weekly_leaderboard', params: {
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(data);
    }
  }

  /// Get personal stats for a specific game.
  Future<Map<String, dynamic>?> getPersonalStats(String gameName) async {
    final uid = _userId;
    if (uid == null) return null;

    final data = await _client!
        .from('game_stats')
        .select()
        .eq('user_id', uid)
        .eq('game_name', gameName)
        .maybeSingle();

    return data;
  }

  /// Get all personal stats across games.
  Future<List<Map<String, dynamic>>> getAllPersonalStats() async {
    final uid = _userId;
    if (uid == null) return [];

    final data = await _client!
        .from('game_stats')
        .select()
        .eq('user_id', uid)
        .order('last_played_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
}
