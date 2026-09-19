import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/supabase_repository.dart';
import '../models/referral_model.dart';
import 'anti_cheat_service.dart';
import 'coin_service.dart';

/// Production-ready Service handling viral referral code generation,
/// comprehensive remote verification against Supabase users, and dual-party reward distribution.
class ReferralService {
  final SupabaseRepository _remote;
  final AntiCheatService _antiCheat;
  final FlutterSecureStorage _storage;

  static const String _keyReferredBy = 'referral_referred_by';
  static const String _keyDeviceClaimed = 'referral_device_claimed_hash';
  static const String _keyInvitedCount = 'referral_invited_count';
  static const String _keyReferralEarnings = 'referral_total_earnings';

  static final RegExp _codePattern = RegExp(r'^RBX-[A-Z0-9]{4,10}$');

  ReferralService({
    required SupabaseRepository remote,
    CoinService? coinService,
    required AntiCheatService antiCheat,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  })  : _remote = remote,
        _antiCheat = antiCheat,
        _storage = storage;

  /// Normalizes user input: strips whitespace, converts to uppercase,
  /// and automatically attaches the 'RBX-' prefix if omitted by the user.
  String normalizeReferralCode(String rawInput) {
    String cleaned = rawInput.trim().toUpperCase();
    if (cleaned.isEmpty) return cleaned;
    if (!cleaned.startsWith('RBX-') && !cleaned.contains('-') && cleaned.length >= 4) {
      cleaned = 'RBX-$cleaned';
    }
    return cleaned;
  }

  /// Validates format of referral code. Returns error message if invalid, null if valid.
  String? validateCodeFormat(String code) {
    if (code.isEmpty) {
      return 'Please enter an invite code.';
    }
    if (code.length < 5) {
      return 'Invite code is too short.';
    }
    if (!_codePattern.hasMatch(code)) {
      return 'Invalid code format. Expected format: RBX-XXXXX';
    }
    return null;
  }

  /// Deterministically derives a unique 6-character uppercase referral code for the user
  String generateUserReferralCode(String? userId) {
    if (userId == null || userId.isEmpty) {
      return 'RBX-HERO';
    }
    final bytes = utf8.encode('rbx_ref_$userId');
    final hash = sha256.convert(bytes).toString().toUpperCase();
    return 'RBX-${hash.substring(0, 5)}';
  }

  /// Loads current referral statistics and redemption status.
  /// Syncs with remote Supabase database and persists to local secure storage.
  Future<ReferralState> getReferralState() async {
    final userId = _remote.currentUserId;
    final fallbackCode = generateUserReferralCode(userId);

    // Read local cache for immediate display
    final cachedReferredBy = await _storage.read(key: _keyReferredBy);
    final cachedCountStr = await _storage.read(key: _keyInvitedCount);
    final cachedEarningsStr = await _storage.read(key: _keyReferralEarnings);

    int totalInvited = int.tryParse(cachedCountStr ?? '0') ?? 0;
    int totalEarnings = int.tryParse(cachedEarningsStr ?? '0') ?? 0;
    String? referredBy = cachedReferredBy;
    String myCode = fallbackCode;

    // Fetch fresh stats from Supabase if online and authenticated
    if (userId != null && userId.isNotEmpty) {
      try {
        final stats = await _remote.getReferralStats();
        if (stats.isNotEmpty) {
          final remoteCode = stats['referral_code'] as String?;
          if (remoteCode != null && remoteCode.isNotEmpty) {
            myCode = remoteCode;
          }
          if (stats['referred_by_code'] != null) {
            referredBy = stats['referred_by_code'] as String;
            await _storage.write(key: _keyReferredBy, value: referredBy);
          }
          totalInvited = (stats['referral_count'] as int?) ?? totalInvited;
          totalEarnings = (stats['referral_earnings'] as int?) ?? totalEarnings;

          // Sync back to local storage
          await _storage.write(key: _keyInvitedCount, value: '$totalInvited');
          await _storage.write(key: _keyReferralEarnings, value: '$totalEarnings');
        }
      } catch (e) {
        debugPrint('ReferralService: Remote sync fallback: $e');
      }
    }

    return ReferralState(
      myReferralCode: myCode,
      referredByCode: referredBy,
      hasRedeemedCode: referredBy != null,
      totalFriendsInvited: totalInvited,
      totalCoinsEarned: totalEarnings,
    );
  }

  /// Redeems a friend's referral code with multi-layered verification:
  /// format check, anti-cheat, self-referral prevention, device binding, and remote DB validation.
  Future<ReferralRedeemResult> redeemCode(String rawInput) async {
    final code = normalizeReferralCode(rawInput);

    // 1. Code format validation
    final formatError = validateCodeFormat(code);
    if (formatError != null) {
      return ReferralRedeemResult(isSuccess: false, message: formatError);
    }

    // 2. Action frequency rate-limiting check
    final rateCheck = _antiCheat.validateActionFrequency('referral_redeem');
    if (!rateCheck.isValid) {
      return ReferralRedeemResult(isSuccess: false, message: rateCheck.message);
    }

    // 3. Prevent self-referral
    final myCode = generateUserReferralCode(_remote.currentUserId);
    if (code == myCode) {
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'You cannot enter your own invite code!',
      );
    }

    // 4. One redemption per account check (local fast path)
    final alreadyReferred = await _storage.read(key: _keyReferredBy);
    if (alreadyReferred != null) {
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'You have already redeemed an invite code.',
      );
    }

    // 5. Hardware device fingerprint binding (local fast path)
    final deviceFingerprint = await _antiCheat.getDeviceFingerprint();
    final isDeviceClaimed = await _storage.read(
      key: '$_keyDeviceClaimed:$deviceFingerprint',
    );
    if (isDeviceClaimed == 'true') {
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'This device has already claimed an invite bonus.',
      );
    }

    // 6. Execute atomic remote database validation & reward crediting
    return await _executeRemoteReferralCredit(code, deviceFingerprint);
  }

  Future<ReferralRedeemResult> _executeRemoteReferralCredit(
    String code,
    String deviceFingerprint,
  ) async {
    try {
      final remoteResult = await _remote.redeemReferralCode(
        code,
        deviceFingerprint,
      );

      if (remoteResult['success'] != true) {
        final errorMsg = remoteResult['error'] as String? ??
            'Invalid invite code. No user found with this code.';
        return ReferralRedeemResult(isSuccess: false, message: errorMsg);
      }

      final reward = (remoteResult['coins_awarded'] as int?) ??
          ReferralState.welcomeBonusCoins;
      final referrerName = remoteResult['referrer_name'] as String?;
      final balance = remoteResult['balance'] as int?;

      // Persist locally in encrypted storage
      await _storage.write(key: _keyReferredBy, value: code);
      await _storage.write(
        key: '$_keyDeviceClaimed:$deviceFingerprint',
        value: 'true',
      );

      return ReferralRedeemResult(
        isSuccess: true,
        message: 'Success! You received +$reward RBX Welcome Bonus! 🎉',
        coinsAwarded: reward,
        referrerName: referrerName,
        newBalance: balance,
      );
    } catch (e) {
      debugPrint('ReferralService credit error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') ||
          errorStr.contains('network') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('connection')) {
        return const ReferralRedeemResult(
          isSuccess: false,
          message: 'Network error. Please check your internet connection and try again.',
        );
      }
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'Invalid invite code. No user found with this code.',
      );
    }
  }

  /// Generates a friendly share message for social media / WhatsApp
  String buildShareMessage(String code) {
    return '🎁 Join me on RBX Rewards! Use my invite code $code to get an instant +200 RBX bonus! Download now: https://rbxrewards.page.link/invite';
  }
}
