import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      if (_isJwtFutureError(e)) {
        debugPrint('⏱ JWT issued-at-future detected in repository – retrying in 1.5 s…');
        await Future.delayed(const Duration(milliseconds: 1500));
        return await fn();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> callEdgeFunction(String name, {Map<String, dynamic>? body}) async {
    return _call(() async {
      final resp = await _client.functions.invoke(name, body: body);
      if (resp.status != 200) {
        final errorMsg = resp.data is Map ? (resp.data['error'] ?? resp.data['message']) : null;
        throw Exception(errorMsg ?? '$name failed with status ${resp.status}');
      }
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
      return <String, dynamic>{};
    });
  }

  Future<int> creditCoinsViaEdge(int amount, String source, String txId) async {
    final data = await callEdgeFunction('credit-coins', body: {'amount': amount, 'source': source, 'txId': txId});
    return data['balance'] as int? ?? data['new_balance'] as int? ?? 0;
  }

  Future<int> spendCoinsViaEdge(int amount, String rewardTitle, String txId) async {
    final data = await callEdgeFunction('spend-coins', body: {'amount': amount, 'rewardTitle': rewardTitle, 'txId': txId});
    return data['remaining'] as int? ?? data['balance'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> getUserData() {
    final uid = currentUserId;
    if (uid == null) return Future.value(<String, dynamic>{});
    return _call(() async {
      final data = await _client.from('users').select().eq('id', uid).maybeSingle();
      return data != null ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    });
  }

  Future<Duration> getDailyRewardCooldown() async {
    final uid = currentUserId;
    if (uid == null) return Duration.zero;
    final data = await getUserData();
    final claimedAt = data['daily_reward_claimed_at'];
    if (claimedAt == null) return Duration.zero;

    final lastClaimed = DateTime.parse(claimedAt as String);
    final cooldownEnd = lastClaimed.add(const Duration(hours: 24));
    final remaining = cooldownEnd.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<List<Map<String, dynamic>>> getRedeemedRewards({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return [];
    return _call(() async {
      final data = await _client
          .from('redeemed_rewards')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(data as List);
    });
  }

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
}
