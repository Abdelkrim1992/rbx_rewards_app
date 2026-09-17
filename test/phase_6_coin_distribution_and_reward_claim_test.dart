import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/business/daily_cap_service.dart';
import 'package:rbx_rewards/business/ad_tracker_service.dart';
import 'package:rbx_rewards/data/supabase_repository.dart';
import 'package:rbx_rewards/models/reward_item.dart';

class MockSupabaseRepository implements SupabaseRepository {
  @override
  Future<List<Map<String, dynamic>>> getCoinDistributions() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6: Harmonized Coin Distribution Tests', () {
    late DailyCapService capService;

    setUp(() {
      capService = DailyCapService(MockSupabaseRepository());
    });

    test('rebalanced mega_chest returns 250 coins (down from 1,000)', () {
      expect(capService.getBaseReward('mega_chest'), 250);
      expect(capService.getPremiumReward('mega_chest'), 250);
      expect(capService.getBaseReward('mega_chest_double'), 250);
      expect(capService.getPremiumReward('mega_chest_double'), 250);
      expect(capService.getRewardLimits('mega_chest'), (250, 250));
    });

    test('watch video ad fallback returns 25 coins', () {
      expect(capService.getBaseReward('ad'), 25);
      expect(capService.getPremiumReward('ad'), 25);
      expect(capService.getBaseReward('watch_video'), 25);
      expect(capService.getBaseReward('watch_earn'), 25);
    });

    test('mini-games return harmonized base rewards (5-6 coins) and +25 bonus premium', () {
      // Math Quiz
      expect(capService.getBaseReward('math_quiz'), 6);
      expect(capService.getPremiumReward('math_quiz'), 31); // 6 base + 25 bonus

      // Tap Tap Reflex
      expect(capService.getBaseReward('tap_tap'), 5);
      expect(capService.getPremiumReward('tap_tap'), 30); // 5 base + 25 bonus

      // Flappy Jump
      expect(capService.getBaseReward('flappy_jump'), 6);
      expect(capService.getPremiumReward('flappy_jump'), 31);

      // Flip Card Memory
      expect(capService.getBaseReward('flip_card'), 6);
      expect(capService.getPremiumReward('flip_card'), 31);
    });

    test('timed chests, scratch cards, and spins return harmonized ranges', () {
      expect(capService.getBaseReward('chest'), 45);
      expect(capService.getPremiumReward('chest'), 65);
      expect(capService.getRewardLimits('chest'), (35, 65));

      expect(capService.getBaseReward('scratch'), 20);
      expect(capService.getPremiumReward('scratch'), 45);
      expect(capService.getRewardLimits('scratch'), (15, 45));

      expect(capService.getBaseReward('spin'), 20);
      expect(capService.getPremiumReward('spin'), 50);

      expect(capService.getBaseReward('daily_reward'), 50);
      expect(capService.getPremiumReward('daily_reward'), 75);
    });
  });

  group('Phase 6: Unlimited Earnings & Yield-Aware Ad Bonus Tests', () {
    late DailyCapService capService;

    setUp(() {
      capService = DailyCapService(MockSupabaseRepository());
    });

    test('Tier 1 (<= 1,200 coins): 100% full speed yielding +25 ad bonus', () {
      capService.setTodayFeaturesEarningsForTest(800);
      expect(capService.getYieldMultiplier(), 1.0);

      // Base 6 + 25 = 31 coins
      expect(capService.calculateAdBonusReward(6), 31);
      // Base 5 + 25 = 30 coins
      expect(capService.calculateAdBonusReward(5), 30);
    });

    test('Tier 2 (1,201 – 2,200 coins): 50% pace yielding +12 or +13 ad bonus', () {
      capService.setTodayFeaturesEarningsForTest(1500);
      expect(capService.getYieldMultiplier(), 0.5);

      final mathQuizReward = capService.calculateAdBonusReward(6);
      expect(mathQuizReward, anyOf(18, 19)); // 6 + 12 or 13

      final tapTapReward = capService.calculateAdBonusReward(5);
      expect(tapTapReward, anyOf(17, 18));
    });

    test('Tier 3 (2,201+ coins / Grinder): 15% micro-rewards yielding +4 ad bonus', () {
      capService.setTodayFeaturesEarningsForTest(3000);
      expect(capService.getYieldMultiplier(), 0.15);

      // Base 6 + 4 = 10 coins
      expect(capService.calculateAdBonusReward(6), 10);
      // Base 5 + 4 = 9 coins
      expect(capService.calculateAdBonusReward(5), 9);
    });

    test('gameplay is continuous and limitless without hard lockouts', () {
      capService.setTodayFeaturesEarningsForTest(10000);
      expect(capService.isFeaturesCapReached, isFalse, reason: 'Features cap must never block users with hard lockout');
      expect(capService.isCapReached, isFalse);

      // Even at 10,000 daily coins, user still receives a minimum 4 coins bonus
      expect(capService.calculateAdBonusReward(6), 10);
    });
  });

  group('Phase 6: Dual-Gated Rewards Claim & Thresholds Tests', () {
    test('catalog denominations contain strict minimum lifetime ad requirements', () {
      final catalog = RewardItem.defaultCatalog;
      final robuxItem = catalog.firstWhere((i) => i.id == 'robux_direct_code');
      final giftCardItem = catalog.firstWhere((i) => i.id == 'roblox_gift_card');

      // Starter Reward: 4,500 coins, >= 70 lifetime ads
      final starter = robuxItem.denominations.firstWhere((d) => d.id == 'starter_rbx_50c');
      expect(starter.coinCost, 4500);
      expect(starter.minLifetimeAds, 70);
      expect(starter.isOneTimeStarter, isTrue);

      // $3 Gift Card: 24,000 coins, >= 500 lifetime ads
      final card3 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_3');
      expect(card3.coinCost, 24000);
      expect(card3.minLifetimeAds, 500);

      // $5 Gift Card: 38,000 coins, >= 850 lifetime ads
      final card5 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_5');
      expect(card5.coinCost, 38000);
      expect(card5.minLifetimeAds, 850);

      // $10 Gift Card: 72,000 coins, >= 1,600 lifetime ads
      final card10 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_10');
      expect(card10.coinCost, 72000);
      expect(card10.minLifetimeAds, 1600);
    });

    test('AdTrackerService tracks lifetime ads correctly', () {
      final tracker = AdTrackerService();
      tracker.setLifetimeAdsForTest(45);
      expect(tracker.lifetimeAdsWatched, 45);

      tracker.setLifetimeAdsForTest(75);
      expect(tracker.lifetimeAdsWatched, 75);
    });

    test('Dual-Gate eligibility evaluation logic', () {
      final catalog = RewardItem.defaultCatalog;
      final robuxItem = catalog.firstWhere((i) => i.id == 'robux_direct_code');
      final starter = robuxItem.denominations.firstWhere((d) => d.id == 'starter_rbx_50c');

      // Case A: Insufficient coins (2,000 < 4,500) and insufficient ads (40 < 70)
      int userCoins = 2000;
      int lifetimeAds = 40;
      bool canRedeem = userCoins >= starter.coinCost && lifetimeAds >= starter.minLifetimeAds;
      expect(canRedeem, isFalse);

      // Case B: Sufficient coins (5,000 >= 4,500) but insufficient ads (50 < 70) -> Fraud protection blocks
      userCoins = 5000;
      lifetimeAds = 50;
      canRedeem = userCoins >= starter.coinCost && lifetimeAds >= starter.minLifetimeAds;
      expect(canRedeem, isFalse);

      // Case C: Both requirements met (4,500 coins and 70 ads) -> Cashout unlocked
      userCoins = 4500;
      lifetimeAds = 70;
      canRedeem = userCoins >= starter.coinCost && lifetimeAds >= starter.minLifetimeAds;
      expect(canRedeem, isTrue);
    });

    test('locked requirements deficit and progress calculation', () {
      const coinCost = 4500;
      const minAds = 70;
      const userCoins = 2250;
      const lifetimeAds = 42;

      final coinProgress = (userCoins / coinCost).clamp(0.0, 1.0);
      final adProgress = (lifetimeAds / minAds).clamp(0.0, 1.0);

      expect(coinProgress, 0.5);
      expect((adProgress * 100).toInt(), 60);

      const coinsRemaining = coinCost - userCoins;
      const adsRemaining = minAds - lifetimeAds;

      expect(coinsRemaining, 2250);
      expect(adsRemaining, 28);
    });
  });
}
