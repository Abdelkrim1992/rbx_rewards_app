import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/models/reward_config.dart';

void main() {
  group('RewardConfig - Math Quiz / Trivia (ratio-based)', () {
    test('Fail: score below 40% returns 0', () {
      expect(RewardConfig.calculateMathQuizBaseReward(0, 5), 0);
      expect(RewardConfig.calculateMathQuizBaseReward(1, 5), 0);
      expect(RewardConfig.calculateMathQuizBaseReward(3, 10), 0); // 30%
    });

    test('Bronze: 40% - 59% returns 3', () {
      expect(RewardConfig.calculateMathQuizBaseReward(2, 5), 3); // 40%
      expect(RewardConfig.calculateMathQuizBaseReward(4, 10), 3); // 40%
      expect(RewardConfig.calculateMathQuizBaseReward(5, 10), 3); // 50%
    });

    test('Silver: 60% - 99% returns 7', () {
      expect(RewardConfig.calculateMathQuizBaseReward(3, 5), 7); // 60%
      expect(RewardConfig.calculateMathQuizBaseReward(4, 5), 7); // 80%
      expect(RewardConfig.calculateMathQuizBaseReward(6, 10), 7); // 60%
      expect(RewardConfig.calculateMathQuizBaseReward(9, 10), 7); // 90%
    });

    test('Gold: 100% perfect returns 12', () {
      expect(RewardConfig.calculateMathQuizBaseReward(5, 5), 12); // 100%
      expect(RewardConfig.calculateMathQuizBaseReward(10, 10), 12); // 100%
    });

    test('Premium multiplier: 12 base * 4 = 48', () {
      final base = RewardConfig.calculateMathQuizBaseReward(5, 5);
      expect(base * RewardConfig.miniGameMultiplier, 48);
    });

    test('Edge: 0 total questions returns 0', () {
      expect(RewardConfig.calculateMathQuizBaseReward(0, 0), 0);
    });
  });

  group('RewardConfig - Flappy Jump (score-based)', () {
    test('Fail: score < 3 returns 0 (Anti-AFK)', () {
      expect(RewardConfig.calculateFlappyBaseReward(0), 0);
      expect(RewardConfig.calculateFlappyBaseReward(2), 0);
    });

    test('Bronze: score 3-9 returns 3', () {
      expect(RewardConfig.calculateFlappyBaseReward(3), 3);
      expect(RewardConfig.calculateFlappyBaseReward(9), 3);
    });

    test('Silver: score 10-24 returns 7', () {
      expect(RewardConfig.calculateFlappyBaseReward(10), 7);
      expect(RewardConfig.calculateFlappyBaseReward(24), 7);
    });

    test('Gold: score 25+ returns 12', () {
      expect(RewardConfig.calculateFlappyBaseReward(25), 12);
      expect(RewardConfig.calculateFlappyBaseReward(100), 12);
    });

    test('Premium multiplier: 12 * 4 = 48', () {
      final base = RewardConfig.calculateFlappyBaseReward(25);
      expect(base * RewardConfig.miniGameMultiplier, 48);
    });
  });

  group('RewardConfig - Tap Tap Reflex (score-based)', () {
    test('Fail: score < 30 returns 0 (Anti-AFK)', () {
      expect(RewardConfig.calculateTapTapBaseReward(0, 0), 0);
      expect(RewardConfig.calculateTapTapBaseReward(29, 5), 0);
    });

    test('Bronze: score 30-70 returns 3', () {
      expect(RewardConfig.calculateTapTapBaseReward(30, 0), 3);
      expect(RewardConfig.calculateTapTapBaseReward(70, 10), 3);
    });

    test('Silver: score 71-140 returns 7', () {
      expect(RewardConfig.calculateTapTapBaseReward(71, 5), 7);
      expect(RewardConfig.calculateTapTapBaseReward(140, 20), 7);
    });

    test('Gold: score 141+ returns 12', () {
      expect(RewardConfig.calculateTapTapBaseReward(141, 30), 12);
      expect(RewardConfig.calculateTapTapBaseReward(500, 100), 12);
    });

    test('maxCombo does not affect tier (pure score tiers)', () {
      expect(
        RewardConfig.calculateTapTapBaseReward(100, 0),
        RewardConfig.calculateTapTapBaseReward(100, 999),
      );
    });

    test('Premium multiplier: 12 * 4 = 48', () {
      final base = RewardConfig.calculateTapTapBaseReward(141, 50);
      expect(base * RewardConfig.miniGameMultiplier, 48);
    });
  });

  group('RewardConfig - Flip Card Memory (matches + time)', () {
    test('Fail: < 2 matches returns 0', () {
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 0,
          timeLeftSeconds: 60,
          totalPairs: 6,
        ),
        0,
      );
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 1,
          timeLeftSeconds: 30,
          totalPairs: 6,
        ),
        0,
      );
    });

    test('Bronze: 2-5 matches (partial board) returns 4', () {
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 2,
          timeLeftSeconds: 40,
          totalPairs: 6,
        ),
        4,
      );
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 5,
          timeLeftSeconds: 20,
          totalPairs: 6,
        ),
        4,
      );
    });

    test('Silver: all 6 pairs matched with < 15s left returns 8', () {
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 6,
          timeLeftSeconds: 14,
          totalPairs: 6,
        ),
        8,
      );
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 6,
          timeLeftSeconds: 0,
          totalPairs: 6,
        ),
        8,
      );
    });

    test('Gold: all 6 pairs matched with >= 15s left returns 12', () {
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 6,
          timeLeftSeconds: 15,
          totalPairs: 6,
        ),
        12,
      );
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 6,
          timeLeftSeconds: 60,
          totalPairs: 6,
        ),
        12,
      );
    });

    test('Premium multiplier: 12 * 4 = 48', () {
      final base = RewardConfig.calculateFlipCardBaseReward(
        matchesFound: 6,
        timeLeftSeconds: 30,
        totalPairs: 6,
      );
      expect(base * RewardConfig.miniGameMultiplier, 48);
    });
  });

  group('RewardConfig - Economy Constraints', () {
    test('miniGameMaxBaseReward is 12', () {
      expect(RewardConfig.miniGameMaxBaseReward, 12);
    });

    test('miniGameMultiplier is 4', () {
      expect(RewardConfig.miniGameMultiplier, 4);
    });

    test('miniGameMaxPremiumReward is 48', () {
      expect(RewardConfig.miniGameMaxPremiumReward, 48);
    });

    test('No mini-game can exceed 12 base coins', () {
      expect(RewardConfig.calculateMathQuizBaseReward(100, 100),
          lessThanOrEqualTo(12));
      expect(RewardConfig.calculateFlappyBaseReward(10000),
          lessThanOrEqualTo(12));
      expect(RewardConfig.calculateTapTapBaseReward(10000, 10000),
          lessThanOrEqualTo(12));
      expect(
        RewardConfig.calculateFlipCardBaseReward(
          matchesFound: 100,
          timeLeftSeconds: 9999,
          totalPairs: 6,
        ),
        lessThanOrEqualTo(12),
      );
    });
  });
}
