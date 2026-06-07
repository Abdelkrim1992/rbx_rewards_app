import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for all coin-related operations.
/// Direct interface to Supabase balance, transactions, and spending.
class CoinService {
  final SupabaseClient? _clientOverride;

  CoinService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient? get _client {
    try {
      return _clientOverride ?? Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _userId => _client?.auth.currentUser?.id;

  Stream<Map<String, dynamic>>? _userDataStreamCache;
  String? _lastStreamUserId;

  // ── JWT-future retry helper ───────────────────────────────────────────────
  // PostgREST rejects JWTs whose `iat` is even a few milliseconds ahead of the
  // DB server clock (PGRST303 / "JWT issued at future"). We catch that specific
  // error, wait 1.5 s for the clocks to align, then retry once.
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

  /// Real-time stream of the current user's full record.
  Stream<Map<String, dynamic>> get userDataStream {
    final uid = _userId;
    if (uid == null) return Stream.value({});

    if (_userDataStreamCache == null || _lastStreamUserId != uid) {
      _lastStreamUserId = uid;
      _userDataStreamCache = _client!
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', uid)
          .map((rows) {
            if (rows.isEmpty) return <String, dynamic>{};
            return rows.first;
          })
          .asBroadcastStream();
    }
    
    return _userDataStreamCache!;
  }

  /// Get current balance (one-time fetch).
  Future<int> getBalance() async {
    final uid = _userId;
    if (uid == null) return 0;

    final data = await _retryOnJwtFuture(() => _client!
        .from('users')
        .select('balance')
        .eq('id', uid)
        .maybeSingle());
    return data?['balance'] as int? ?? 0;
  }

  /// Get full user record (one-time fetch).
  Future<Map<String, dynamic>> getUserData() async {
    final uid = _userId;
    if (uid == null) return {};

    final data = await _retryOnJwtFuture(
        () => _client!.from('users').select().eq('id', uid).maybeSingle());
    return data ?? {};
  }

  /// Credit coins generically via Edge Function (for chests, offers, manual rewards).
  /// Returns the new balance.
  Future<int> creditCoins(int amount,
      {required String source, required String txId}) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final resp = await _client!.functions.invoke(
      'credit-coins',
      body: {
        'amount': amount,
        'source': source,
        'txId': txId,
      },
    );

    if (resp.status != 200) {
      final error = resp.data['error'] ?? 'Failed to credit coins';
      throw Exception(error);
    }

    return resp.data['balance'] as int;
  }

  /// Spend coins atomically via Edge Function.
  /// Returns the new balance.
  Future<int> spendCoins(int amount,
      {required String rewardTitle, required String txId}) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final resp = await _client!.functions.invoke(
      'spend-coins',
      body: {
        'amount': amount,
        'rewardTitle': rewardTitle,
        'txId': txId,
      },
    );

    if (resp.status != 200) {
      final error = resp.data['error'] ?? 'Failed to spend coins';
      throw Exception(error);
    }

    debugPrint('spend-coins response: ${resp.data}');
    return resp.data['remaining'] as int;
  }

  /// Fetch transaction history for the current user.
  Future<List<Map<String, dynamic>>> getTransactionHistory(
      {int limit = 50}) async {
    final uid = _userId;
    if (uid == null) return [];

    final data = await _retryOnJwtFuture(() => _client!
        .from('transactions')
        .select()
        .eq('user_id', uid)
        .order('processed_at', ascending: false)
        .limit(limit));

    return List<Map<String, dynamic>>.from(data);
  }

  /// Get current spin state from server.
  Future<Map<String, dynamic>> getSpinState() async {
    final uid = _userId;
    if (uid == null) return {'spins_remaining': 0, 'cooldown_end': 0};

    final data = await _retryOnJwtFuture(() => _client!.rpc(
          'get_spin_state',
          params: {'p_user_id': uid},
        ));
    return data as Map<String, dynamic>;
  }

  /// Fetch redeemed rewards history for the current user.
  Future<List<Map<String, dynamic>>> getRedeemedRewards(
      {int limit = 50}) async {
    final uid = _userId;
    if (uid == null) return [];

    final data = await _retryOnJwtFuture(() => _client!
        .from('redeemed_rewards')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit));

    return List<Map<String, dynamic>>.from(data);
  }

  /// Check if a username is available (case-insensitive).
  Future<bool> isUsernameAvailable(String username) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final result = await _retryOnJwtFuture(() => _client!.rpc(
          'is_username_available',
          params: {
            'p_username': username,
            'p_exclude_user_id': uid,
          },
        ));

    return result as bool;
  }

  /// Update the user's display name.
  /// Throws exception if username is already taken.
  Future<void> updateDisplayName(String name) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    // Check if username is available
    final available = await isUsernameAvailable(name);
    if (!available) {
      throw Exception('This username already exists. Try another one.');
    }

    await _retryOnJwtFuture(() =>
        _client!.from('users').update({'display_name': name}).eq('id', uid));
  }

  /// Update the user's profile photo URL.
  Future<void> updateProfilePhoto(String? url) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');
    if (url == null) {
      await _retryOnJwtFuture(() => _client!
          .from('users')
          .update({'profile_photo_url': null}).eq('id', uid));
    } else {
      await _retryOnJwtFuture(() => _client!
          .from('users')
          .update({'profile_photo_url': url}).eq('id', uid));
    }
  }

  /// Consume one spin server-side.
  Future<Map<String, dynamic>> useSpin() async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final data = await _retryOnJwtFuture(() => _client!.rpc(
          'use_spin',
          params: {'p_user_id': uid},
        ));
    return data as Map<String, dynamic>;
  }

  /// Increment a user stat server-side.
  Future<void> incrementUserStat(String stat) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    await _retryOnJwtFuture(() => _client!.rpc(
          'increment_user_stat',
          params: {
            'p_user_id': uid,
            'p_stat': stat,
          },
        ));
  }
}
