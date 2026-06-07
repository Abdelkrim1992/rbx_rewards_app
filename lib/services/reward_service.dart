import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for daily rewards and spin mechanics.
class RewardService {
  final SupabaseClient? _clientOverride;

  RewardService({SupabaseClient? client}) : _clientOverride = client;

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

  /// Claim daily reward via Edge Function.
  /// [amount] specifies the reward amount (default 100).
  Future<Map<String, dynamic>> claimDailyReward({int amount = 100}) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final resp = await _client!.functions.invoke(
      'claim-daily-reward',
      body: {'amount': amount},
    );

    if (resp.status != 200) {
      final error = resp.data['error'] ?? 'Failed to claim daily reward';
      throw Exception(error);
    }

    return resp.data as Map<String, dynamic>;
  }

  /// Check if daily reward is available.
  Future<bool> isDailyRewardAvailable() async {
    final uid = _userId;
    if (uid == null) return false;

    final data = await _retryOnJwtFuture(() => _client!
        .from('users')
        .select('daily_reward_claimed_at')
        .eq('id', uid)
        .maybeSingle());

    final claimedAt = data?['daily_reward_claimed_at'];
    if (claimedAt == null) return true;

    final lastClaimed = DateTime.parse(claimedAt as String);
    final cooldownEnd = lastClaimed.add(const Duration(hours: 24));
    return DateTime.now().isAfter(cooldownEnd);
  }

  /// Get remaining daily reward cooldown.
  Future<Duration> getDailyRewardCooldown() async {
    final uid = _userId;
    if (uid == null) return Duration.zero;

    final data = await _retryOnJwtFuture(() => _client!
        .from('users')
        .select('daily_reward_claimed_at')
        .eq('id', uid)
        .maybeSingle());

    final claimedAt = data?['daily_reward_claimed_at'];
    if (claimedAt == null) return Duration.zero;

    final lastClaimed = DateTime.parse(claimedAt as String);
    final cooldownEnd = lastClaimed.add(const Duration(hours: 24));
    final remaining = cooldownEnd.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
