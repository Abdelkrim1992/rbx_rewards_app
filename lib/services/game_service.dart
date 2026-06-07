import 'dart:math';
import 'package:flutter/foundation.dart';
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

  // ── JWT-future retry helper ───────────────────────────────────────────────
  bool _isJwtFutureError(Object e) {
    final msg = e.toString().toLowerCase();
    if (e is PostgrestException) {
      return e.code == 'PGRST303' ||
          msg.contains('jwt issued at future') ||
          msg.contains('jwt issued in the future');
    }
    return msg.contains('jwt issued at future') ||
        msg.contains('jwt issued in the future') ||
        msg.contains('pgrst303');
  }

  Future<T> _retryOnJwtFuture<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      if (_isJwtFutureError(e)) {
        debugPrint('⏱ JWT issued-at-future detected – retrying in 1.5 s…');
        await Future.delayed(const Duration(milliseconds: 1500));
        return await fn();
      }
      rethrow;
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  String _extractErrorMessage(dynamic data, String fallback) {
    if (data is Map) {
      final error = data['error'] ?? data['message'];
      if (error is String && error.isNotEmpty) return error;
    }
    if (data is String && data.isNotEmpty) return data;
    return fallback;
  }

  Future<Map<String, dynamic>> _creditGameCoins({
    required int amount,
    required String txId,
  }) async {
    final resp = await _client!.functions.invoke(
      'credit-coins',
      body: {
        'amount': amount,
        'source': 'game',
        'txId': txId,
      },
    );

    if (resp.status != 200) {
      return {
        'success': false,
        'error': _extractErrorMessage(resp.data, 'Failed to credit game coins'),
        'retryable': resp.status >= 500 || resp.status == 429,
      };
    }

    if (resp.data is Map<String, dynamic>) {
      final data = Map<String, dynamic>.from(resp.data as Map<String, dynamic>);
      data['credited'] = amount;
      return data;
    }
    if (resp.data is Map) {
      final data = Map<String, dynamic>.from(resp.data as Map);
      data['credited'] = amount;
      return data;
    }
    return {'success': true, 'credited': amount};
  }

  /// Generate a unique UUID v4 session ID.
  String generateSessionId() {
    final random = Random.secure();
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
    bool queueOnFailure = true,
  }) async {
    if (_userId == null) {
      return {
        'success': false,
        'error': 'Not authenticated',
      };
    }
    final txId = 'game_$sessionId';
    try {
      final resp = await _client!.functions.invoke(
        'add-game-coins',
        body: {
          'amount': score,
          'gameName': gameName,
          'sessionId': sessionId,
          'txId': txId,
          'durationSeconds': durationSeconds,
          if (originalScore > 0) 'originalScore': originalScore,
          if (multiplier > 1) 'multiplier': multiplier,
        },
      );

      if (resp.status != 200) {
        final error = _extractErrorMessage(
          resp.data,
          'Failed to submit game result',
        );
        final status = resp.status;
        final retryable = status >= 500 || status == 429;

        if (queueOnFailure && retryable) {
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
          return {
            'success': false,
            'error': error,
            'queued': true,
            'retryable': true,
          };
        }

        final fallback = await _creditGameCoins(amount: score, txId: txId);
        if (fallback['success'] == true) {
          // Best-effort insert so leaderboard/session metadata isn't lost
          try {
            await _client!.from('game_sessions').insert({
              'id': sessionId,
              'user_id': _userId!,
              'game_name': gameName,
              'score': score,
              'duration_seconds': durationSeconds,
              'validated': false,
            });
          } catch (_) {}
          return fallback;
        }

        return {
          'success': false,
          'error': fallback['error'] ?? error,
          'queued': false,
          'retryable': fallback['retryable'] ?? retryable,
        };
      }

      if (resp.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(resp.data as Map<String, dynamic>);
      }
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
      return {'success': true};
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
      }
      return {
        'success': false,
        'error': e.toString(),
        'queued': queueOnFailure && !nonRetryable,
        'retryable': !nonRetryable,
      };
    }
  }

  /// Get leaderboard for a specific game, or weekly overall leaderboard if no gameName is provided.
  Future<List<Map<String, dynamic>>> getLeaderboard(
      {String? gameName, int limit = 50}) async {
    if (_client == null) return [];
    if (gameName != null) {
      final data = await _retryOnJwtFuture(() => _client!.rpc(
            'get_leaderboard',
            params: {
              'p_game_name': gameName,
              'p_limit': limit,
            },
          ));
      return List<Map<String, dynamic>>.from(data);
    } else {
      final data = await _retryOnJwtFuture(() => _client!.rpc(
            'get_weekly_leaderboard',
            params: {'p_limit': limit},
          ));
      return List<Map<String, dynamic>>.from(data);
    }
  }

  /// Get personal stats for a specific game.
  Future<Map<String, dynamic>?> getPersonalStats(String gameName) async {
    final uid = _userId;
    if (uid == null) return null;

    final data = await _retryOnJwtFuture(() => _client!
        .from('game_stats')
        .select()
        .eq('user_id', uid)
        .eq('game_name', gameName)
        .maybeSingle());

    return data;
  }

  /// Get all personal stats across games.
  Future<List<Map<String, dynamic>>> getAllPersonalStats() async {
    final uid = _userId;
    if (uid == null) return [];

    final data = await _retryOnJwtFuture(() => _client!
        .from('game_stats')
        .select()
        .eq('user_id', uid)
        .order('last_played_at', ascending: false));

    return List<Map<String, dynamic>>.from(data);
  }
}
