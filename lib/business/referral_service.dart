import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../data/supabase_repository.dart';
import '../models/referral_model.dart';
import 'anti_cheat_service.dart';
import 'coin_service.dart';

/// Service handling viral referral code generation, validation, and reward claiming.
/// Protected by AntiCheatService against self-referral and device farming.
class ReferralService {
  final SupabaseRepository _remote;
  final CoinService _coinService;
  final AntiCheatService _antiCheat;
  static const _storage = FlutterSecureStorage();

  static const String _keyReferredBy = 'referral_referred_by';
  static const String _keyDeviceClaimed = 'referral_device_claimed_hash';
  static const String _keyInvitedCount = 'referral_invited_count';
  static const String _keyReferralEarnings = 'referral_total_earnings';

  ReferralService({
    required SupabaseRepository remote,
    required CoinService coinService,
    required AntiCheatService antiCheat,
  })  : _remote = remote,
        _coinService = coinService,
        _antiCheat = antiCheat;

  /// Deterministically derives a unique 6-character uppercase referral code for the user
  String generateUserReferralCode(String? userId) {
    if (userId == null || userId.isEmpty) {
      return 'RBX-HERO';
    }
    final bytes = utf8.encode('rbx_ref_$userId');
    final hash = sha256.convert(bytes).toString().toUpperCase();
    return 'RBX-${hash.substring(0, 5)}';
  }

  /// Loads current referral statistics and redemption status
  Future<ReferralState> getReferralState() async {
    final userId = _remote.currentUserId;
    final myCode = generateUserReferralCode(userId);

    final referredBy = await _storage.read(key: _keyReferredBy);
    final countStr = await _storage.read(key: _keyInvitedCount);
    final earningsStr = await _storage.read(key: _keyReferralEarnings);

    return ReferralState(
      myReferralCode: myCode,
      referredByCode: referredBy,
      hasRedeemedCode: referredBy != null,
      totalFriendsInvited: int.tryParse(countStr ?? '0') ?? 0,
      totalCoinsEarned: int.tryParse(earningsStr ?? '0') ?? 0,
    );
  }

  /// Redeems a friend's referral code with multi-layered anti-cheat verification
  Future<ReferralRedeemResult> redeemCode(String rawInput) async {
    final code = rawInput.trim().toUpperCase();

    // 1. Basic formatting check
    if (code.isEmpty || code.length < 5) {
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'Please enter a valid referral code.',
      );
    }

    // 2. Action rate-limiting check
    final rateCheck = _antiCheat.validateActionFrequency('referral_redeem');
    if (!rateCheck.isValid) {
      return ReferralRedeemResult(isSuccess: false, message: rateCheck.message);
    }

    // 3. Prevent self-referral
    final myCode = generateUserReferralCode(_remote.currentUserId);
    if (code == myCode) {
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'You cannot enter your own referral code!',
      );
    }

    // 4. One redemption per account check
    final alreadyReferred = await _storage.read(key: _keyReferredBy);
    if (alreadyReferred != null) {
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'You have already redeemed a referral code.',
      );
    }

    // 5. Hardware device fingerprint binding (1 welcome bonus per physical device)
    final deviceFingerprint = await _antiCheat.getDeviceFingerprint();
    final isDeviceClaimed = await _storage.read(key: '$_keyDeviceClaimed:$deviceFingerprint');
    if (isDeviceClaimed == 'true') {
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'This device has already claimed a welcome referral bonus.',
      );
    }

    // 6. Grant Welcome Bonus to referee
    return await _executeReferralCredit(code, deviceFingerprint);
  }

  Future<ReferralRedeemResult> _executeReferralCredit(
    String code,
    String deviceFingerprint,
  ) async {
    try {
      const reward = ReferralState.welcomeBonusCoins;
      final txId = const Uuid().v4();

      await _coinService.creditCoins(
        reward,
        source: 'referral_welcome_$code',
        txId: txId,
      );

      // Persist locally in encrypted storage
      await _storage.write(key: _keyReferredBy, value: code);
      await _storage.write(
        key: '$_keyDeviceClaimed:$deviceFingerprint',
        value: 'true',
      );

      return const ReferralRedeemResult(
        isSuccess: true,
        message: 'Success! You received +100 RBX Welcome Bonus! 🎉',
        coinsAwarded: reward,
      );
    } catch (e) {
      debugPrint('ReferralService credit error: $e');
      return const ReferralRedeemResult(
        isSuccess: false,
        message: 'Could not process referral reward. Please try again.',
      );
    }
  }

  /// Generates a friendly share message for social media / WhatsApp
  String buildShareMessage(String code) {
    return '🎁 Join me on RBX Rewards! Use my invite code $code to get an instant +100 RBX bonus! Download now: https://rbxrewards.page.link/invite';
  }
}
