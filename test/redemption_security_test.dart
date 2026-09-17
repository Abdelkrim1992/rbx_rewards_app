import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/core/utils/device_fingerprint.dart';
import 'package:rbx_rewards/models/reward_item.dart';
import 'package:rbx_rewards/models/game_submit_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DeviceFingerprint.setMockDeviceId(null);
  });

  group('Phase 3 Anti-Fraud: Catalog Safeguards & Ad View Thresholds', () {
    test('Starter Reward requires 70 lifetime ads and 4,500 coins', () {
      final catalog = RewardItem.defaultCatalog;
      final starterItem = catalog.firstWhere((item) => item.id == 'robux_direct_code');
      final starterDenom = starterItem.denominations.firstWhere((d) => d.id == 'starter_rbx_50c');

      expect(starterDenom.minLifetimeAds, equals(70));
      expect(starterDenom.coinCost, equals(4500));
      expect(starterDenom.isOneTimeStarter, isTrue);
    });

    test('\$3.00 Roblox Gift Card requires 500 lifetime ads and 24,000 coins', () {
      final catalog = RewardItem.defaultCatalog;
      final giftCardItem = catalog.firstWhere((item) => item.id == 'roblox_gift_card');
      final card3 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_3');

      expect(card3.minLifetimeAds, equals(500));
      expect(card3.coinCost, equals(24000));
    });

    test('\$5.00 Roblox Gift Card requires 850 lifetime ads and 38,000 coins', () {
      final catalog = RewardItem.defaultCatalog;
      final giftCardItem = catalog.firstWhere((item) => item.id == 'roblox_gift_card');
      final card5 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_5');

      expect(card5.minLifetimeAds, equals(850));
      expect(card5.coinCost, equals(38000));
    });

    test('\$10.00 Roblox Gift Card requires 1,600 lifetime ads and 72,000 coins', () {
      final catalog = RewardItem.defaultCatalog;
      final giftCardItem = catalog.firstWhere((item) => item.id == 'roblox_gift_card');
      final card10 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_10');

      expect(card10.minLifetimeAds, equals(1600));
      expect(card10.coinCost, equals(72000));
    });
  });

  group('Phase 3 Anti-Fraud: Hardware Device Fingerprint Capture', () {
    test('DeviceFingerprint generates a valid, stable 64-character SHA-256 hash', () async {
      final deviceId1 = await DeviceFingerprint.getDeviceId();
      expect(deviceId1, isNotEmpty);
      expect(deviceId1.length, equals(64)); // SHA-256 hex string is 64 characters

      final deviceId2 = await DeviceFingerprint.getDeviceId();
      expect(deviceId2, equals(deviceId1));
    });

    test('DeviceFingerprint respects testing mock overrides', () async {
      DeviceFingerprint.setMockDeviceId('mock_hw_test_fingerprint_123');
      final deviceId = await DeviceFingerprint.getDeviceId();
      expect(deviceId, equals('mock_hw_test_fingerprint_123'));
    });
  });

  group('Phase 3 Anti-Fraud: Spend-Coins Backend Logic Simulation', () {
    const minLifetimeAdsMap = <String, int>{
      'starter_rbx_50c': 70,
      'rbx_card_3': 500,
      'rbx_card_5': 850,
      'rbx_card_10': 1600,
      'rbx_card_25': 3600,
      'robux_code_400': 850,
      'robux_code_800': 1600,
      'robux_code_2000': 3200,
      'robux_code_4500': 6000,
    };

    // Simulated spend-coins anti-fraud verification function
    Map<String, dynamic> simulateSpendCoins({
      required String userId,
      required int userLifetimeAds,
      required int userBalance,
      required String denomId,
      required int amount,
      required String deviceId,
      required Set<String> claimedDeviceIds,
      required Set<String> claimedUserIds,
    }) {
      if (userBalance < amount) {
        return {'success': false, 'error': 'Insufficient balance', 'status': 400};
      }

      // 1. Proof-of-engagement: Check lifetime ads
      final requiredAds = minLifetimeAdsMap[denomId] ?? 0;
      if (userLifetimeAds < requiredAds) {
        return {
          'success': false,
          'error': 'Please complete more game sessions before claiming this reward',
          'status': 403,
        };
      }

      // 2. Hardware device lock: Starter Voucher
      if (denomId == 'starter_rbx_50c' || amount == 4500) {
        if (claimedUserIds.contains(userId)) {
          return {
            'success': false,
            'error': 'The Starter Reward can only be redeemed once per account',
            'status': 403,
          };
        }
        if (claimedDeviceIds.contains(deviceId)) {
          return {
            'success': false,
            'error': 'The Starter Reward can only be redeemed once per physical device',
            'status': 403,
          };
        }
      }

      // 3. Success -> pending_review status with 48h buffer
      return {
        'success': true,
        'status': 'pending_review',
        'remaining': userBalance - amount,
        'estimatedDeliveryHours': 48,
      };
    }

    test('Starter Card fails if lifetime ads < 70', () {
      final res = simulateSpendCoins(
        userId: 'user_1',
        userLifetimeAds: 45, // < 70
        userBalance: 5000,
        denomId: 'starter_rbx_50c',
        amount: 4500,
        deviceId: 'device_abc',
        claimedDeviceIds: {},
        claimedUserIds: {},
      );

      expect(res['success'], isFalse);
      expect(res['status'], equals(403));
      expect(res['error'], contains('Please complete more game sessions'));
    });

    test('Starter Card fails on second attempt with same deviceId (even with different userId)', () {
      final claimedDevices = <String>{'device_locked_777'};
      final claimedUsers = <String>{'user_original'};

      final res = simulateSpendCoins(
        userId: 'user_different_email',
        userLifetimeAds: 100,
        userBalance: 6000,
        denomId: 'starter_rbx_50c',
        amount: 4500,
        deviceId: 'device_locked_777', // Same hardware
        claimedDeviceIds: claimedDevices,
        claimedUserIds: claimedUsers,
      );

      expect(res['success'], isFalse);
      expect(res['status'], equals(403));
      expect(res['error'], contains('once per physical device'));
    });

    test('\$3.00 Card fails if lifetime ads < 500', () {
      final res = simulateSpendCoins(
        userId: 'user_2',
        userLifetimeAds: 380, // < 500
        userBalance: 30000,
        denomId: 'rbx_card_3',
        amount: 24000,
        deviceId: 'device_xyz',
        claimedDeviceIds: {},
        claimedUserIds: {},
      );

      expect(res['success'], isFalse);
      expect(res['status'], equals(403));
      expect(res['error'], contains('Please complete more game sessions'));
    });

    test('Legitimate user with 520 lifetime ads passes and receives pending_review status', () {
      final res = simulateSpendCoins(
        userId: 'user_legit',
        userLifetimeAds: 520, // >= 500
        userBalance: 30000,
        denomId: 'rbx_card_3',
        amount: 24000,
        deviceId: 'device_legit_1',
        claimedDeviceIds: {},
        claimedUserIds: {},
      );

      expect(res['success'], isTrue);
      expect(res['status'], equals('pending_review'));
      expect(res['remaining'], equals(6000));
      expect(res['estimatedDeliveryHours'], equals(48));
    });
  });

  group('Phase 3 Anti-Fraud: Mini-Game Non-Credit on Failure', () {
    test('GameSubmitResult with success: false does not credit user balance', () {
      final failedResult = GameSubmitResult(
        success: false,
        error: 'daily_cap_reached: 120 coin limit reached',
        coinsEarned: 0,
      );

      int currentBalance = 1000;
      if (failedResult.success && failedResult.coinsEarned > 0) {
        currentBalance += failedResult.coinsEarned;
      }

      expect(currentBalance, equals(1000));
      expect(failedResult.error?.toLowerCase().contains('cap'), isTrue);
    });
  });
}
