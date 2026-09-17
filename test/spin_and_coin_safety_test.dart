import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/presentation/providers/providers.dart';
import 'package:rbx_rewards/presentation/providers/spin_provider.dart';
import 'package:rbx_rewards/business/spin_service.dart';
import 'package:rbx_rewards/business/coin_service.dart';
import 'package:rbx_rewards/business/daily_cap_service.dart';
import 'package:rbx_rewards/business/connectivity_service.dart';
import 'package:rbx_rewards/data/secure_repository.dart';
import 'package:rbx_rewards/data/supabase_repository.dart';
import 'package:rbx_rewards/data/hive_repository.dart';

class MockSupabaseRepository extends Mock implements SupabaseRepository {
  @override
  Future<int> creditCoinsViaEdge(int? amount, String? source, String? txId) async {
    // Simulate backend returning lower balance or failing
    return 0;
  }

  @override
  Future<Map<String, dynamic>> callEdgeFunction(String? name, {Map<String, dynamic>? body}) async {
    throw Exception('Simulated network error in edge function');
  }

  @override
  Future<Map<String, dynamic>> getUserStats() async {
    return {'balance': 10, 'coins': 10};
  }
}

class MockSecureRepository extends Mock implements SecureRepository {
  int _balance = 100;
  int _spins = 3;
  int? _cooldown;

  @override
  Future<int> getBalance() async => _balance;

  @override
  Future<void> saveBalance(int balance) async {
    _balance = balance;
  }

  @override
  Future<int> getSpinFreeSpins() async => _spins;

  @override
  Future<void> saveSpinState(int spins, int? cooldownEndMs) async {
    _spins = spins;
    _cooldown = cooldownEndMs;
  }

  @override
  Future<int?> getSpinCooldownEnd() async => _cooldown;
}

class MockConnectivityService extends Mock implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;
}

class MockHiveRepository extends Mock implements HiveRepository {
  @override
  Future<void> enqueuePending(Map<String, dynamic> item) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Coin Balance Safety Tests', () {
    late ProviderContainer container;
    late MockSupabaseRepository mockRemote;
    late MockSecureRepository mockSecure;
    late MockConnectivityService mockConnectivity;
    late MockHiveRepository mockHive;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      mockRemote = MockSupabaseRepository();
      mockSecure = MockSecureRepository();
      mockConnectivity = MockConnectivityService();
      mockHive = MockHiveRepository();

      container = ProviderContainer(
        overrides: [
          supabaseRepositoryProvider.overrideWithValue(mockRemote),
          secureRepositoryProvider.overrideWithValue(mockSecure),
          connectivityServiceProvider.overrideWithValue(mockConnectivity),
          hiveRepositoryProvider.overrideWithValue(mockHive),
          coinServiceProvider.overrideWithValue(
            CoinService(
              remote: mockRemote,
              queue: mockHive,
              secure: mockSecure,
              connectivity: mockConnectivity,
            ),
          ),
          dailyCapServiceProvider.overrideWith(
            (ref) => DailyCapService(mockRemote),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('credit() optimistically increases balance and never reduces even if backend returns 0', () async {
      final notifier = container.read(coinProvider.notifier);
      notifier.updateBalance(100);
      expect(container.read(coinProvider), equals(100));

      // Crediting 20 coins
      final resultingBalance = await notifier.credit(20, 'spin');

      // Allowed amount should be credited and balance should be at least 120
      expect(resultingBalance, greaterThanOrEqualTo(120));
      expect(container.read(coinProvider), greaterThanOrEqualTo(120));
    });

    test('updateBalance() does not overwrite higher balance with stale lower balance', () {
      final notifier = container.read(coinProvider.notifier);
      notifier.updateBalance(250);
      expect(container.read(coinProvider), equals(250));

      // Stale external update with lower balance
      notifier.updateBalance(50);
      expect(container.read(coinProvider), equals(250));
    });

    test('SpinService useSpin() gracefully decrements spins even when remote edge function throws', () async {
      final spinService = SpinService(
        remote: mockRemote,
        secure: mockSecure,
        connectivity: mockConnectivity,
      );

      final result = await spinService.useSpin();
      expect(result.spinsRemaining, equals(2));
      expect(await mockSecure.getSpinFreeSpins(), equals(2));
    });
  });
}
