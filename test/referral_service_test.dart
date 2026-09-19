import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/business/anti_cheat_service.dart';
import 'package:rbx_rewards/business/referral_service.dart';
import 'package:rbx_rewards/data/secure_repository.dart';
import 'package:rbx_rewards/data/supabase_repository.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/presentation/providers/providers.dart';
import 'package:rbx_rewards/presentation/providers/referral_provider.dart';

/// Fake SecureRepository for balance testing
class FakeSecureRepository extends Fake implements SecureRepository {
  int balance = 0;
  @override
  Future<int> getBalance() async => balance;
  @override
  Future<void> saveBalance(int newBalance) async {
    balance = newBalance;
  }
}

/// In-memory fake implementation of FlutterSecureStorage for testing
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future.value(_store[key]);
    }
    if (invocation.memberName == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        _store.remove(key);
      } else {
        _store[key] = value;
      }
      return Future.value();
    }
    if (invocation.memberName == #delete) {
      final key = invocation.namedArguments[#key] as String;
      _store.remove(key);
      return Future.value();
    }
    return super.noSuchMethod(invocation);
  }
}

/// Fake SupabaseRepository for controlled unit testing
class FakeSupabaseRepository extends Fake implements SupabaseRepository {
  String? fakeUserId = 'test-user-uuid-123';
  Map<String, dynamic>? mockRedeemResponse;
  Map<String, dynamic>? mockStatsResponse;
  Exception? throwOnRedeem;

  @override
  String? get currentUserId => fakeUserId;

  @override
  Future<Map<String, dynamic>> redeemReferralCode(
    String code,
    String deviceFingerprint,
  ) async {
    if (throwOnRedeem != null) {
      throw throwOnRedeem!;
    }
    return mockRedeemResponse ?? {'success': true, 'coins_awarded': 100};
  }

  @override
  Future<Map<String, dynamic>> getReferralStats() async {
    return mockStatsResponse ?? {};
  }
}

/// Fake AntiCheatService for predictable anti-cheat checks
class FakeAntiCheatService extends Fake implements AntiCheatService {
  bool allowRateLimit = true;
  String deviceFingerprint = 'test-device-fingerprint-abc';

  @override
  AntiCheatResult validateActionFrequency(
    String actionKey, {
    int maxAllowedInWindow = 5,
    Duration window = const Duration(seconds: 1),
  }) {
    if (!allowRateLimit) {
      return const AntiCheatResult(
        isValid: false,
        violation: AntiCheatViolation.rateLimitExceeded,
        message: 'Too many redemption attempts. Please wait.',
      );
    }
    return AntiCheatResult.valid;
  }

  @override
  Future<String> getDeviceFingerprint() async => deviceFingerprint;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterSecureStorage storage;
  late FakeSupabaseRepository remote;
  late FakeAntiCheatService antiCheat;
  late ReferralService service;

  setUp(() {
    storage = FakeFlutterSecureStorage();
    remote = FakeSupabaseRepository();
    antiCheat = FakeAntiCheatService();

    service = ReferralService(
      remote: remote,
      antiCheat: antiCheat,
      storage: storage,
    );
  });

  group('Referral Code Generation & Formatting Tests', () {
    test('generateUserReferralCode generates deterministic RBX- format', () {
      final code1 = service.generateUserReferralCode('user-alice');
      final code2 = service.generateUserReferralCode('user-alice');
      final codeBob = service.generateUserReferralCode('user-bob');

      expect(code1, startsWith('RBX-'));
      expect(code1.length, 9); // 'RBX-' (4) + 5 chars = 9
      expect(code1, equals(code2), reason: 'Deterministic for same user ID');
      expect(code1, isNot(equals(codeBob)), reason: 'Different users get different codes');
    });

    test('generateUserReferralCode returns fallback for null or empty user ID', () {
      expect(service.generateUserReferralCode(null), equals('RBX-HERO'));
      expect(service.generateUserReferralCode(''), equals('RBX-HERO'));
    });

    test('normalizeReferralCode trims whitespace and converts to uppercase', () {
      expect(service.normalizeReferralCode('  rbx-12345  '), equals('RBX-12345'));
      expect(service.normalizeReferralCode('rbx-abcde'), equals('RBX-ABCDE'));
    });

    test('normalizeReferralCode automatically attaches RBX- prefix if omitted', () {
      expect(service.normalizeReferralCode('abcde'), equals('RBX-ABCDE'));
      expect(service.normalizeReferralCode('4A9F1'), equals('RBX-4A9F1'));
      expect(service.normalizeReferralCode('RBX-4A9F1'), equals('RBX-4A9F1'));
    });

    test('validateCodeFormat validates length and pattern', () {
      expect(service.validateCodeFormat(''), equals('Please enter an invite code.'));
      expect(service.validateCodeFormat('AB'), equals('Invite code is too short.'));
      expect(
        service.validateCodeFormat('INVALID!@#'),
        equals('Invalid code format. Expected format: RBX-XXXXX'),
      );
      expect(service.validateCodeFormat('RBX-4A9F1'), isNull);
    });

    test('buildShareMessage contains invite code and promotion', () {
      final msg = service.buildShareMessage('RBX-99999');
      expect(msg, contains('RBX-99999'));
      expect(msg, contains('+200 RBX bonus'));
    });
  });

  group('Referral Redemption & Anti-Cheat Validation Tests', () {
    test('Self-referral is strictly prevented', () async {
      final myCode = service.generateUserReferralCode(remote.currentUserId);
      final result = await service.redeemCode(myCode);

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('cannot enter your own'));
    });

    test('Self-referral is prevented even if user omits prefix or uses lowercase', () async {
      final myCode = service.generateUserReferralCode(remote.currentUserId);
      final rawCode = myCode.replaceFirst('RBX-', '').toLowerCase();

      final result = await service.redeemCode(rawCode);

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('cannot enter your own'));
    });

    test('Action rate limiting blocks excessive redemption attempts', () async {
      antiCheat.allowRateLimit = false;

      final result = await service.redeemCode('RBX-FRIEND1');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Too many redemption attempts'));
    });

    test('Account cannot redeem twice (one-time redemption per user)', () async {
      await storage.write(key: 'referral_referred_by', value: 'RBX-ALREADY');

      final result = await service.redeemCode('RBX-NEWFRND');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('already redeemed an invite code'));
    });

    test('Hardware device fingerprint blocks multi-account farming on same device', () async {
      await storage.write(
        key: 'referral_device_claimed_hash:test-device-fingerprint-abc',
        value: 'true',
      );

      final result = await service.redeemCode('RBX-ANOTHER');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('already claimed an invite bonus'));
    });
  });

  group('Remote Validation Against Another User Tests', () {
    test('Non-existent referral code from another user is rejected with error', () async {
      remote.mockRedeemResponse = {
        'success': false,
        'error': 'Invalid invite code. No user found with this code.',
      };

      final result = await service.redeemCode('RBX-NONEXIST');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('No user found with this code'));
    });

    test('Valid referral code from another user is accepted and credits rewards', () async {
      remote.mockRedeemResponse = {
        'success': true,
        'coins_awarded': 200,
        'referrer_name': 'AlexDeveloper',
        'balance': 450,
      };

      final result = await service.redeemCode('RBX-ALEX99');

      expect(result.isSuccess, isTrue);
      expect(result.coinsAwarded, equals(200));
      expect(result.referrerName, equals('AlexDeveloper'));
      expect(result.newBalance, equals(450));
      expect(result.message, contains('+200 RBX Welcome Bonus'));

      // Verify encrypted storage was updated
      final savedCode = await storage.read(key: 'referral_referred_by');
      expect(savedCode, equals('RBX-ALEX99'));

      final deviceClaimed = await storage.read(
        key: 'referral_device_claimed_hash:test-device-fingerprint-abc',
      );
      expect(deviceClaimed, equals('true'));
    });

    test('Network error returns clear network connection message', () async {
      remote.throwOnRedeem = Exception('Failed host lookup: db.supabase.co');

      final result = await service.redeemCode('RBX-FRIEND1');

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('internet connection'));
    });
  });

  group('Referral State & Statistics Sync Tests', () {
    test('getReferralState synchronizes remote statistics into local cache', () async {
      remote.mockStatsResponse = {
        'referral_code': 'RBX-CUSTOM1',
        'referred_by_code': 'RBX-BOSS',
        'referral_count': 7,
        'referral_earnings': 1400,
        'has_redeemed': true,
      };

      final state = await service.getReferralState();

      expect(state.myReferralCode, equals('RBX-CUSTOM1'));
      expect(state.referredByCode, equals('RBX-BOSS'));
      expect(state.hasRedeemedCode, isTrue);
      expect(state.totalFriendsInvited, equals(7));
      expect(state.totalCoinsEarned, equals(1400));

      // Check persisted in storage
      final countStr = await storage.read(key: 'referral_invited_count');
      expect(countStr, equals('7'));

      final earnStr = await storage.read(key: 'referral_total_earnings');
      expect(earnStr, equals('1400'));
    });

    test('getReferralState falls back to local storage when remote fails', () async {
      await storage.write(key: 'referral_invited_count', value: '3');
      await storage.write(key: 'referral_total_earnings', value: '600');
      await storage.write(key: 'referral_referred_by', value: 'RBX-PREV');

      remote.mockStatsResponse = {}; // Empty / offline

      final state = await service.getReferralState();

      expect(state.hasRedeemedCode, isTrue);
      expect(state.referredByCode, equals('RBX-PREV'));
      expect(state.totalFriendsInvited, equals(3));
      expect(state.totalCoinsEarned, equals(600));
    });

    test('ReferralNotifier.redeemCode adds coins instantly to balance and does not reset to 0', () async {
      final fakeSecure = FakeSecureRepository()..balance = 250;
      remote.mockRedeemResponse = {
        'success': true,
        'coins_awarded': 200,
        'referrer_name': 'FriendAlice',
      };

      final container = ProviderContainer(
        overrides: [
          referralServiceProvider.overrideWithValue(service),
          secureRepositoryProvider.overrideWithValue(fakeSecure),
        ],
      );
      addTearDown(container.dispose);

      // Initialize coin balance to 250
      container.read(coinProvider.notifier).updateBalance(250);
      expect(container.read(coinProvider), equals(250));

      // Redeem code
      final result = await container.read(referralStateProvider.notifier).redeemCode('RBX-ALICE1');

      expect(result.isSuccess, isTrue);
      expect(result.coinsAwarded, equals(200));

      // Verify balance increased by 200 instantly to 450, NOT reset to 0
      expect(container.read(coinProvider), equals(450));
      expect(fakeSecure.balance, equals(450));
    });
  });
}
