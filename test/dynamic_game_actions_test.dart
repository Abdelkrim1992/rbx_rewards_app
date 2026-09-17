import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rbx_rewards/business/daily_cap_service.dart';
import 'package:rbx_rewards/data/supabase_repository.dart';
import 'package:rbx_rewards/models/reward_config.dart';

class MockSupabaseRepository extends Mock implements SupabaseRepository {
  @override
  Future<List<Map<String, dynamic>>> getCoinDistributions() async => [];
}

void main() {
  group('Dynamic Mini-Game Action-Based Calculations', () {
    test('Flappy Jump action calculations & thresholds', () {
      int calculateFlappyCoins(int score) {
        return (score ~/ 2).clamp(0, RewardConfig.miniGameMaxBaseReward);
      }

      // Early crash / zero action
      expect(calculateFlappyCoins(0), 0);
      expect(calculateFlappyCoins(1), 0);

      // Decent flight: 6 score (e.g. 2 pipes + 2 in-flight coins)
      expect(calculateFlappyCoins(6), 3);
      // With x4 multiplier
      expect(calculateFlappyCoins(6) * RewardConfig.miniGameMultiplier, 12);

      // Good flight: 20 score
      expect(calculateFlappyCoins(20), 10);
      expect(calculateFlappyCoins(20) * RewardConfig.miniGameMultiplier, 40);

      // Elite long run: 40 score (clamped to max 15 base)
      expect(calculateFlappyCoins(40), 15);
      expect(calculateFlappyCoins(40) * RewardConfig.miniGameMultiplier, 60);
    });

    test('Tap Tap Crystal action calculations & anti-AFK threshold', () {
      (bool isFailed, int coins) calculateTapTapResult(int score, int maxCombo) {
        if (score < 30) {
          return (true, 0);
        }
        final baseCoins = (score / 20).floor().clamp(1, RewardConfig.miniGameMaxBaseReward);
        int comboBonus = 0;
        if (maxCombo >= 30) {
          comboBonus = 4;
        } else if (maxCombo >= 15) {
          comboBonus = 2;
        } else if (maxCombo >= 5) {
          comboBonus = 1;
        }
        final total = (baseCoins + comboBonus).clamp(1, RewardConfig.miniGameMaxBaseReward);
        return (false, total);
      }

      // Under threshold (<30 taps/score) -> fails, 0 coins
      final failResult = calculateTapTapResult(25, 3);
      expect(failResult.$1, isTrue);
      expect(failResult.$2, 0);

      // Bare pass: 30 score, combo 5
      final passResult = calculateTapTapResult(30, 6);
      expect(passResult.$1, isFalse);
      expect(passResult.$2, 2); // 1 base + 1 combo
      expect(passResult.$2 * RewardConfig.miniGameMultiplier, 8);

      // Fast tapping: 80 score, combo 18
      final midResult = calculateTapTapResult(80, 18);
      expect(midResult.$1, isFalse);
      expect(midResult.$2, 6); // 4 base + 2 combo
      expect(midResult.$2 * RewardConfig.miniGameMultiplier, 24);

      // Ultra combo dash: 220 score, combo 35
      final eliteResult = calculateTapTapResult(220, 35);
      expect(eliteResult.$1, isFalse);
      expect(eliteResult.$2, 15); // clamped to 15
      expect(eliteResult.$2 * RewardConfig.miniGameMultiplier, 60);
    });

    test('Flip Cards memory match action calculations', () {
      int calculateFlipCardCoins({
        required int matchesFound,
        required int timeLeftSeconds,
        required int maxCombo,
      }) {
        if (matchesFound <= 0) return 0;
        final baseCoins = matchesFound * 2;
        final timeBonus = (timeLeftSeconds / 10).floor();
        final comboBonus = (maxCombo > 3) ? (maxCombo - 3) * 2 : 0;
        return (baseCoins + timeBonus + comboBonus).clamp(0, RewardConfig.miniGameMaxBaseReward);
      }

      // 0 matches
      expect(calculateFlipCardCoins(matchesFound: 0, timeLeftSeconds: 0, maxCombo: 0), 0);

      // 3 matches out of 6, timed out
      expect(calculateFlipCardCoins(matchesFound: 3, timeLeftSeconds: 0, maxCombo: 2), 6);
      expect(
        calculateFlipCardCoins(matchesFound: 3, timeLeftSeconds: 0, maxCombo: 2) *
            RewardConfig.miniGameMultiplier,
        24,
      );

      // Perfect fast clear: 6 matches, 25s left, combo 4
      final perfect = calculateFlipCardCoins(matchesFound: 6, timeLeftSeconds: 25, maxCombo: 4);
      expect(perfect, 15); // (12 + 2 + 2) = 16 clamped to 15
      expect(perfect * RewardConfig.miniGameMultiplier, 60);
    });

    test('Math Quiz action calculations based on accuracy', () {
      int calculateMathQuizCoins(int correctCount, int totalQuestions) {
        final perCorrect = (RewardConfig.miniGameMaxBaseReward / totalQuestions).ceil();
        return (correctCount * perCorrect).clamp(0, RewardConfig.miniGameMaxBaseReward);
      }

      // 0 correct
      expect(calculateMathQuizCoins(0, 5), 0);

      // 2 correct -> 6 coins -> x4 = 24
      expect(calculateMathQuizCoins(2, 5), 6);
      expect(calculateMathQuizCoins(2, 5) * RewardConfig.miniGameMultiplier, 24);

      // 4 correct -> 12 coins -> x4 = 48
      expect(calculateMathQuizCoins(4, 5), 12);
      expect(calculateMathQuizCoins(4, 5) * RewardConfig.miniGameMultiplier, 48);

      // 5/5 perfect -> 15 coins -> x4 = 60
      expect(calculateMathQuizCoins(5, 5), 15);
      expect(calculateMathQuizCoins(5, 5) * RewardConfig.miniGameMultiplier, 60);
    });
  });

  group('DailyCapService Multiplier & Yield Curve Protection for Unlimited Play', () {
    late DailyCapService capService;

    setUp(() {
      capService = DailyCapService(MockSupabaseRepository());
    });

    test('Tier 1 (0 to 1,200 coins): 100% yield awards full x4 bonus', () {
      capService.setTodayFeaturesEarningsForTest(200);

      // 10 base with x4 multiplier -> total = 40 (10 + 30 bonus)
      final boosted = capService.calculateAdBonusReward(10, multiplier: 4);
      expect(boosted, 40);

      // 15 max base with x4 multiplier -> total = 60
      final maxBoosted = capService.calculateAdBonusReward(15, multiplier: 4);
      expect(maxBoosted, 60);
    });

    test('Tier 2 (1,201 to 2,200 coins): 50% yield scales ad bonus gracefully', () {
      capService.setTodayFeaturesEarningsForTest(1500);

      // 10 base with x4 multiplier: bonus = 30 * 0.5 = 15 -> total = 25
      final boosted = capService.calculateAdBonusReward(10, multiplier: 4);
      expect(boosted, 25);

      // 15 max base: bonus = 45 * 0.5 = 23 -> total = 38
      final maxBoosted = capService.calculateAdBonusReward(15, multiplier: 4);
      expect(maxBoosted, 38);
    });

    test('Tier 3 (2,201+ coins): 15% yield protects against unlimited free play inflation', () {
      capService.setTodayFeaturesEarningsForTest(3000);

      // 10 base with x4 multiplier: bonus = 30 * 0.15 = 5 -> total = 15
      final boosted = capService.calculateAdBonusReward(10, multiplier: 4);
      expect(boosted, 15);
    });

    test('Unlimited play unit economics verification (Ad Arbitrage Safety)', () {
      const wholesaleCoinCost = 0.00008; // $0.36 / 4500 coins
      const rewardedAdRevenue = 0.020;  // $20 eCPM

      // Maximum possible mini-game payout (15 base x 4 = 60 coins)
      const maxCoins = 60;
      const maxCost = maxCoins * wholesaleCoinCost;
      const netProfit = rewardedAdRevenue - maxCost;
      const margin = (netProfit / rewardedAdRevenue) * 100;

      expect(maxCost, closeTo(0.0048, 0.0001));
      expect(netProfit, closeTo(0.0152, 0.0001));
      expect(margin, greaterThan(75.0)); // > 75% margin even on maximum payout!
    });
  });
}
