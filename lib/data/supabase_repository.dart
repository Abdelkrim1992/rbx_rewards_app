import 'dart:convert';
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

  /// Credits coins by pushing to database through resilient multi-layer strategy:
  /// 1. Edge function (credit-coins)
  /// 2. Direct RPC fallback (credit_user_coins)
  /// 3. Direct DB update fallback (public.users + public.transactions)
  Future<int> creditCoinsViaEdge(int amount, String source, String txId) async {
    final uid = currentUserId;

    // Layer 1: Call Edge Function
    try {
      final data = await callEdgeFunction('credit-coins', body: {
        'amount': amount,
        'source': source,
        'txId': txId,
      });
      final balance = data['balance'] as int? ?? data['new_balance'] as int?;
      if (balance != null) {
        return balance;
      }
    } catch (e) {
      debugPrint('credit-coins Edge Function error ($e), trying direct RPC fallback...');
    }

    // Layer 2: Direct Database RPC fallback
    if (uid != null) {
      try {
        final rpcRes = await _client.rpc('credit_user_coins', params: {
          'p_user_id': uid,
          'p_amount': amount,
          'p_source': source,
          'p_tx_id': txId,
        });
        if (rpcRes is num) {
          debugPrint('✅ Coins credited directly via RPC: $rpcRes');
          return rpcRes.toInt();
        }
      } catch (rpcErr) {
        debugPrint('credit_user_coins RPC error ($rpcErr), trying direct database update...');
      }

      // Layer 3: Direct database update on public.users & public.transactions
      return _call(() async {
        final userRow = await _client.from('users').select('balance').eq('id', uid).maybeSingle();
        final curBal = (userRow?['balance'] as int?) ?? 0;
        final newBal = curBal + amount;

        try {
          await _client.from('transactions').insert({
            'user_id': uid,
            'amount': amount,
            'source': source,
            'tx_id': txId,
            'processed_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}

        await _client.from('users').update({
          'balance': newBal,
          'total_earned': newBal,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', uid);

        debugPrint('✅ Coins credited directly via database table: $newBal');
        return newBal;
      });
    }

    throw Exception('User is not authenticated');
  }

  Future<int> spendCoinsViaEdge(
    int amount,
    String rewardTitle,
    String txId, {
    String? denomId,
    String? deviceId,
  }) async {
    final data = await callEdgeFunction('spend-coins', body: {
      'amount': amount,
      'rewardTitle': rewardTitle,
      'txId': txId,
      if (denomId != null) 'denomId': denomId,
      if (deviceId != null) 'deviceId': deviceId,
    });
    return data['remaining'] as int? ?? data['balance'] as int? ?? 0;
  }

  /// Process game session directly via database RPC if Edge Function is unreachable
  Future<Map<String, dynamic>?> processGameSessionRpc({
    required String sessionId,
    required String userId,
    required String gameName,
    required int score,
    required int durationSeconds,
    required String txId,
    int dailyCap = 1200,
  }) async {
    return _call(() async {
      final res = await _client.rpc('process_game_session', params: {
        'p_session_id': sessionId,
        'p_user_id': userId,
        'p_game_name': gameName,
        'p_score': score,
        'p_duration_seconds': durationSeconds,
        'p_tx_id': txId,
        'p_daily_cap': dailyCap,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      } else if (res is String) {
        return Map<String, dynamic>.from(jsonDecode(res) as Map);
      }
      return null;
    });
  }

  /// Fetches user profile. Tries Edge Function first, then falls back directly
  /// to public.users table in Supabase PostgreSQL for verified real-time balance.
  Future<Map<String, dynamic>> getUserStats() async {
    final uid = currentUserId;
    if (uid == null) return <String, dynamic>{};
    try {
      final stats = await callEdgeFunction('get-user-stats');
      if (stats.isNotEmpty && (stats['balance'] != null || stats['coins'] != null)) {
        return stats;
      }
    } catch (e) {
      debugPrint('getUserStats edge function notice: $e');
    }

    // Direct PostgreSQL query fallback
    try {
      final row = await _client.from('users').select().eq('id', uid).maybeSingle();
      if (row != null) {
        return Map<String, dynamic>.from(row);
      }
    } catch (dbErr) {
      debugPrint('getUserStats DB fallback error: $dbErr');
    }
    return <String, dynamic>{};
  }

  Future<void> addFreeSpin() async {
    final uid = currentUserId;
    if (uid == null) return;
    return _call(() async {
      final data = await _client.from('users').select('spin_free_spins').eq('id', uid).maybeSingle();
      final currentSpins = data != null ? (data['spin_free_spins'] as int? ?? 0) : 0;
      await _client.from('users').update({
        'spin_free_spins': currentSpins + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    });
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
    try {
      final data = await callEdgeFunction('get-reward-history', body: {'limit': limit});
      
      if (data.containsKey('history') && data['history'] is List) {
        return (data['history'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('get-reward-history error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getQuizzes() async {
    try {
      final resp = await _client.functions.invoke('get-quizzes');
      if (resp.status == 200 && resp.data is List) {
        return List<Map<String, dynamic>>.from(resp.data as List);
      }
      return [];
    } catch (e) {
      debugPrint('get-quizzes error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCoinDistributions() async {
    return _call(() async {
      final data = await _client.from('coin_distributions').select();
      return List<Map<String, dynamic>>.from(data);
    });
  }

  Future<Map<String, dynamic>> claimWelcomeBonus() async {
    final uid = currentUserId;
    if (uid == null) {
      return {'success': false, 'error': 'Unauthorized'};
    }
    return _call(() async {
      // 1. Ensure user row exists in public.users first without overwriting existing data
      try {
        await _client.from('users').upsert({
          'id': uid,
        }, onConflict: 'id', ignoreDuplicates: true);
      } catch (e) {
        debugPrint('ensure user in claimWelcomeBonus notice: $e');
      }

      // 2. Attempt atomic claim via database RPC
      try {
        final resp = await _client.rpc('claim_welcome_bonus');
        if (resp is Map) {
          final map = Map<String, dynamic>.from(resp);
          if (map['success'] == true) {
            debugPrint('✅ Welcome bonus claimed via RPC: ${map['balance']}');
            return map;
          }
          debugPrint('claim_welcome_bonus RPC returned non-success: $map');
        } else {
          return {'success': true, 'claimed': true, 'amount': 500};
        }
      } catch (e) {
        debugPrint('claim_welcome_bonus RPC error, attempting direct fallback: $e');
      }

      // 3. Fallback: Direct database upsert
      try {
        final userRow = await _client
            .from('users')
            .select('welcome_bonus_claimed, balance')
            .eq('id', uid)
            .maybeSingle();
        final alreadyClaimed = userRow != null &&
            (userRow['welcome_bonus_claimed'] as bool? ?? false);
        if (alreadyClaimed) {
          return {
            'success': false,
            'error': 'Welcome bonus already claimed',
            'balance': userRow['balance'] ?? 500
          };
        }
        final currentBal = (userRow?['balance'] as int?) ?? 0;
        final newBal = currentBal + 500;
        await _client.from('users').upsert({
          'id': uid,
          'balance': newBal,
          'total_earned': newBal,
          'welcome_bonus_claimed': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'id');

        try {
          await _client.from('transactions').insert({
            'user_id': uid,
            'amount': 500,
            'source': 'welcome_bonus',
            'tx_id': 'welcome_${DateTime.now().millisecondsSinceEpoch}',
            'processed_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}

        debugPrint('✅ Welcome bonus saved directly to database: $newBal');
        return {
          'success': true,
          'claimed': true,
          'balance': newBal,
          'amount': 500
        };
      } catch (directError) {
        debugPrint('Direct welcome bonus database save error: $directError');
        return {
          'success': false,
          'error': directError.toString(),
          'balance': 500,
        };
      }
    });
  }

  Future<bool> hasClaimedWelcomeBonus() async {
    final uid = currentUserId;
    if (uid == null) return false;
    try {
      final data = await _client
          .from('users')
          .select('welcome_bonus_claimed')
          .eq('id', uid)
          .maybeSingle();
      return (data?['welcome_bonus_claimed'] as bool?) ?? false;
    } catch (e) {
      debugPrint('hasClaimedWelcomeBonus error: $e');
      return false;
    }
  }

  /// Redeems a friend's referral code atomically via Supabase RPC or Edge Function
  Future<Map<String, dynamic>> redeemReferralCode(
    String code,
    String deviceFingerprint,
  ) async {
    final uid = currentUserId;
    if (uid == null) {
      return {'success': false, 'error': 'Unauthorized. Please sign in.'};
    }
    return _call(() async {
      try {
        final resp = await _client.rpc('redeem_referral_code', params: {
          'p_code': code,
          'p_device_fingerprint': deviceFingerprint,
        });
        if (resp is Map) {
          return Map<String, dynamic>.from(resp);
        }
        return {'success': false, 'error': 'Invalid response from server.'};
      } catch (e) {
        debugPrint('redeem_referral_code RPC error, trying edge function fallback: $e');
        try {
          return await callEdgeFunction('redeem-referral', body: {
            'code': code,
            'deviceFingerprint': deviceFingerprint,
          });
        } catch (edgeErr) {
          debugPrint('redeem-referral edge fallback error: $edgeErr');
          rethrow;
        }
      }
    });
  }

  /// Fetches referral statistics (invite count, earnings, code, referred by) from Supabase
  Future<Map<String, dynamic>> getReferralStats() async {
    final uid = currentUserId;
    if (uid == null) return <String, dynamic>{};
    return _call(() async {
      final data = await _client
          .from('users')
          .select('referral_code, referred_by, referral_count, referral_earnings')
          .eq('id', uid)
          .maybeSingle();
      if (data == null) return <String, dynamic>{};

      String? referredByCode;
      if (data['referred_by'] != null) {
        final refUser = await _client
            .from('users')
            .select('referral_code')
            .eq('id', data['referred_by'])
            .maybeSingle();
        referredByCode = refUser?['referral_code'] as String?;
      }

      return {
        'referral_code': data['referral_code'],
        'referred_by_code': referredByCode,
        'referral_count': (data['referral_count'] as int?) ?? 0,
        'referral_earnings': (data['referral_earnings'] as int?) ?? 0,
        'has_redeemed': data['referred_by'] != null,
      };
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
