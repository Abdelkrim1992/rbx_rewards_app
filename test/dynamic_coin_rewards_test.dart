import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/business/daily_cap_service.dart';
import 'package:rbx_rewards/data/supabase_repository.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/presentation/providers/mega_chest_provider.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/presentation/screens/home/widgets/home_quick_actions_grid.dart';

class MockSupabaseRepository implements SupabaseRepository {
  List<Map<String, dynamic>> mockDistributions = [];

  @override
  Future<List<Map<String, dynamic>>> getCoinDistributions() async {
    return mockDistributions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCoinNotifier extends CoinNotifier {
  int creditedAmount = 0;
  String? creditedSource;

  @override
  int build() => 100;

  @override
  Future<int> credit(int amount, String source) async {
    creditedAmount += amount;
    creditedSource = source;
    state += amount;
    return state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyCapService Dynamic Reward & Limits Tests', () {
    late DailyCapService capService;
    late MockSupabaseRepository mockRepo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      mockRepo = MockSupabaseRepository();
      capService = DailyCapService(mockRepo);
    });

    test('Default fallback rewards are returned when DB is not yet fetched', () {
      expect(capService.getBaseReward('ad'), 50);
      expect(capService.getBaseReward('watch_earn'), 50);
      expect(capService.getBaseReward('watch_video'), 50);
      expect(capService.getBaseReward('video'), 50);
      expect(capService.getBaseReward('chest'), 15);
      expect(capService.getBaseReward('scratch'), 5);
      expect(capService.getBaseReward('spin'), 5);
      expect(capService.getBaseReward('quiz'), 2);
      expect(capService.getBaseReward('quizzes'), 2);
      expect(capService.getBaseReward('math_quiz'), 2);
      expect(capService.getBaseReward('tap_tap'), 1);
      expect(capService.getBaseReward('flip_card'), 15);
      expect(capService.getBaseReward('mega_chest'), 1000);

      expect(capService.getPremiumReward('ad'), 50);
      expect(capService.getPremiumReward('chest'), 45);
      expect(capService.getPremiumReward('scratch'), 50);
      expect(capService.getPremiumReward('spin'), 25);
      expect(capService.getPremiumReward('quiz'), 4);
      expect(capService.getPremiumReward('flip_card'), 30);
    });

    test('refreshLimits fetches coin_distributions and updates values & notifies listeners', () async {
      bool notified = false;
      capService.addListener(() {
        notified = true;
      });

      // Simulate admin changing values in Supabase coin_distributions table
      mockRepo.mockDistributions = [
        {
          'id': 'ad',
          'daily_cap': 800,
          'base_reward': 120,
          'premium_reward': 240,
        },
        {
          'id': 'quiz',
          'daily_cap': 200,
          'base_reward': 5,
          'premium_reward': 50,
        },
        {
          'id': 'tap_tap',
          'daily_cap': 300,
          'base_reward': 25,
          'premium_reward': 50,
        },
        {
          'id': 'spin',
          'daily_cap': 250,
          'base_reward': 10,
          'premium_reward': 75,
        },
        {
          'id': 'mega_chest',
          'daily_cap': 2000,
          'base_reward': 1500,
          'premium_reward': 3000,
        },
      ];

      await capService.refreshLimits();

      expect(notified, isTrue);

      // Verify dynamic base and premium rewards
      expect(capService.getBaseReward('ad'), 120);
      expect(capService.getBaseReward('watch_earn'), 120); // alias
      expect(capService.getBaseReward('watch_video'), 120); // alias
      expect(capService.getPremiumReward('ad'), 240);

      expect(capService.getBaseReward('quiz'), 5);
      expect(capService.getBaseReward('quizzes'), 5); // alias
      expect(capService.getPremiumReward('quiz'), 50);

      expect(capService.getBaseReward('tap_tap'), 25);
      expect(capService.getPremiumReward('spin'), 75);
      expect(capService.getBaseReward('mega_chest'), 1500);

      // Verify dynamic category caps
      expect(capService.getCategoryCap('ad'), 800);
      expect(capService.getCategoryCap('watch_earn'), 800);
      expect(capService.getCategoryCap('quiz'), 200);
      expect(capService.getCategoryCap('tap_tap'), 300);
      expect(capService.getCategoryCap('spin'), 250);
    });

    test('addCoins triggers notifyListeners for dynamic progress bars', () {
      int notifyCount = 0;
      capService.addListener(() {
        notifyCount++;
      });

      capService.addCoins(50, 'ad');
      expect(notifyCount, 1);
      expect(capService.getEarnedToday('ad'), 50);

      capService.addCoins(25, 'spin');
      expect(notifyCount, 2);
      expect(capService.getEarnedToday('spin'), 25);
    });

    test('load restores cached dynamic limits from secure storage on restart', () async {
      FlutterSecureStorage.setMockInitialValues({
        'cap_limit_ad': '750',
        'reward_base_ad': '85',
        'reward_premium_ad': '170',
        'reward_base_spin': '12',
        'reward_premium_spin': '60',
      });

      final newCapService = DailyCapService(mockRepo);
      await newCapService.load();

      expect(newCapService.getCategoryCap('ad'), 750);
      expect(newCapService.getBaseReward('ad'), 85);
      expect(newCapService.getBaseReward('watch_earn'), 85);
      expect(newCapService.getPremiumReward('ad'), 170);
      expect(newCapService.getPremiumReward('spin'), 60);
    });

    test('getYieldMultiplier returns 1.0 below 1,200 coins, 0.5 between 1,200-2,200, and 0.15 above 2,200', () {
      capService.setTodayFeaturesEarningsForTest(0);
      expect(capService.getYieldMultiplier(), 1.0);

      capService.setTodayFeaturesEarningsForTest(1200);
      expect(capService.getYieldMultiplier(), 1.0);

      capService.setTodayFeaturesEarningsForTest(1201);
      expect(capService.getYieldMultiplier(), 0.5);

      capService.setTodayFeaturesEarningsForTest(1500);
      expect(capService.getYieldMultiplier(), 0.5);

      capService.setTodayFeaturesEarningsForTest(2200);
      expect(capService.getYieldMultiplier(), 0.5);

      capService.setTodayFeaturesEarningsForTest(2201);
      expect(capService.getYieldMultiplier(), 0.15);

      capService.setTodayFeaturesEarningsForTest(3000);
      expect(capService.getYieldMultiplier(), 0.15);
    });

    test('addCoins scales reward by 0.5 when user has earned 1,500 coins today (30 becomes 15)', () {
      capService.setTodayFeaturesEarningsForTest(1500);
      final added = capService.addCoins(30, 'ad');
      expect(added, 15);
      expect(capService.todayFeaturesEarnings, 1515);
    });

    test('addCoins scales reward by 0.15 when user has earned 2,500 coins today (30 becomes 5)', () {
      capService.setTodayFeaturesEarningsForTest(2500);
      final added = capService.addCoins(30, 'game');
      expect(added, 5); // 30 * 0.15 = 4.5 -> round to 5
      expect(capService.todayFeaturesEarnings, 2505);
    });

    test('addCoins guarantees minimum 1 coin even in Tier 3 for micro-rewards', () {
      capService.setTodayFeaturesEarningsForTest(2500);
      final added = capService.addCoins(2, 'math_quiz');
      expect(added, 1); // 2 * 0.15 = 0.3 -> floor of at least 1 coin
    });

    test('isFeaturesCapReached and isCapReached are false, allowing continuous grinder play', () {
      capService.setTodayFeaturesEarningsForTest(5000);
      expect(capService.isFeaturesCapReached, isFalse);
      expect(capService.isCapReached, isFalse);
      expect(capService.isCapReachedFor('game'), isFalse);
      expect(capService.isCapReachedFor('ad'), isFalse);
      expect(capService.getRemainingCap('game'), 999);
    });
  });

  group('MegaChestMilestoneNotifier Dynamic Reward Tests', () {
    test('claimReward credits dynamic baseReward amount', () async {
      SharedPreferences.setMockInitialValues({});
      final testCoinNotifier = TestCoinNotifier();

      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => testCoinNotifier),
        ],
      );

      final notifier = container.read(megaChestMilestoneProvider.notifier);

      // Claim with dynamic baseReward of 1500
      final result = await notifier.claimReward(baseReward: 1500);

      expect(result, isTrue);
      expect(testCoinNotifier.creditedAmount, 1500);
      expect(testCoinNotifier.creditedSource, 'mega_chest');

      container.dispose();
    });

    test('claimReward defaults to 1000 when no baseReward specified', () async {
      SharedPreferences.setMockInitialValues({});
      final testCoinNotifier = TestCoinNotifier();

      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => testCoinNotifier),
        ],
      );

      final notifier = container.read(megaChestMilestoneProvider.notifier);

      final result = await notifier.claimReward();

      expect(result, isTrue);
      expect(testCoinNotifier.creditedAmount, 1000);
      expect(testCoinNotifier.creditedSource, 'mega_chest');

      container.dispose();
    });
  });

  group('HomeQuickActionsGrid Dynamic Display Widget Tests', () {
    testWidgets('Displays dynamic +120 RBX badge when watchEarnCoins is 120', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeQuickActionsGrid(
              watchEarnCoins: 120,
              isWatchEarnCapped: false,
              onChestTap: () {},
              onSpinTap: () {},
              onScratchTap: () {},
              onWatchAdTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('+120 RBX'), findsOneWidget);
      expect(find.text('Capped'), findsNothing);
    });

    testWidgets('Displays Capped badge and disables action when isWatchEarnCapped is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeQuickActionsGrid(
              watchEarnCoins: 120,
              isWatchEarnCapped: true,
              onChestTap: () {},
              onSpinTap: () {},
              onScratchTap: () {},
              onWatchAdTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Capped'), findsOneWidget);
      expect(find.text('+120 RBX'), findsNothing);

      await tester.tap(find.text('Capped'));
      await tester.pump();

      expect(tapped, isFalse);
    });
  });

  group('UserProfile Balance Stability Tests', () {
    test('userProfileProvider preserves positive coin balance when profile stream emits empty data', () {
      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => TestCoinNotifier()),
        ],
      );

      final profile = container.read(userProfileProvider);
      // TestCoinNotifier has initial 100 coins
      expect(profile.coins, 100);
      container.dispose();
    });
  });
}
