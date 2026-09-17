import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/presentation/providers/providers.dart';
import 'package:rbx_rewards/business/auth_service.dart';
import 'package:rbx_rewards/data/secure_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'device_account_version': 0});
    FlutterSecureStorage.setMockInitialValues({'balance': '1500'});
  });

  group('Account Deletion & Cache Wiping Tests', () {
    test('CoinNotifier.forceReset() unconditionally zeroes in-memory balance and storage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coinNotifier = container.read(coinProvider.notifier);
      coinNotifier.updateBalance(1500);
      expect(container.read(coinProvider), 1500);

      // Normal updateBalance(0) would be ignored due to the anti-wipe guard:
      coinNotifier.updateBalance(0);
      expect(container.read(coinProvider), 1500, reason: 'updateBalance(0) is guarded against stale 0');

      // forceReset() MUST unconditionally wipe to 0:
      coinNotifier.forceReset();
      expect(container.read(coinProvider), 0, reason: 'forceReset must unconditionally set in-memory state to 0');

      final cachedBalance = await container.read(secureRepositoryProvider).getBalance();
      expect(cachedBalance, 0, reason: 'forceReset must write 0 to local secure storage');
    });

    test('DailyCapService.resetAllEarnings() resets all in-memory daily earnings to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final capService = container.read(dailyCapServiceProvider);
      capService.addCoins(200, 'features');
      expect(capService.todayEarnings, greaterThan(0));

      capService.resetAllEarnings();
      expect(capService.todayEarnings, 0);
      expect(capService.todayDailyRewardEarnings, 0);
      expect(capService.todayChestEarnings, 0);
      expect(capService.todaySpinEarnings, 0);
    });

    test('deleteAccount advances device_account_version in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('device_account_version', 1);
      await prefs.setBool('onboarding_completed', true);
      await prefs.setString('some_cached_key', 'stale_val');

      final auth = AuthService(secure: SecureRepository());
      await auth.deleteAccount();

      final updatedPrefs = await SharedPreferences.getInstance();
      expect(updatedPrefs.getInt('device_account_version'), 2, reason: 'device_account_version must increment to ensure fresh device identity');
      expect(updatedPrefs.getBool('onboarding_completed'), isNull, reason: 'SharedPreferences should be purged of previous account data');
      expect(updatedPrefs.getString('some_cached_key'), isNull, reason: 'All cached device keys should be cleared');
    });
  });
}
