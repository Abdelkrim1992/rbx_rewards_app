import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/models/reward_config.dart';
import 'package:rbx_rewards/business/daily_cap_service.dart';
import 'package:rbx_rewards/data/supabase_repository.dart';

class FakeSupabaseRepository implements SupabaseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('RewardConfig - Non-Mini-Game Feature Economy Constraints', () {
    test('Spin Wheel: all base slices are <= 12 and 4x multiplier gives <= 48', () {
      expect(RewardConfig.spinWheelBaseSlices, equals([2, 4, 6, 8, 10, 12]));
      expect(RewardConfig.spinJackpotBase, equals(12));
      expect(RewardConfig.spinMultiplier, equals(4));

      for (final slice in RewardConfig.spinWheelBaseSlices) {
        final premium = slice * RewardConfig.spinMultiplier;
        expect(premium, lessThanOrEqualTo(48),
            reason: 'Slice $slice x 4 should never exceed 48 coins');
      }
      expect(RewardConfig.spinPremium, equals(48));
    });

    test('Scratch Cards: base range is 6 to 12 and 4x multiplier gives <= 48', () {
      expect(RewardConfig.scratchMinBase, equals(6));
      expect(RewardConfig.scratchMaxBase, equals(12));
      expect(RewardConfig.scratchMultiplier, equals(4));

      const minPremium = RewardConfig.scratchMinBase * RewardConfig.scratchMultiplier;
      const maxPremium = RewardConfig.scratchMaxBase * RewardConfig.scratchMultiplier;

      expect(minPremium, equals(24));
      expect(maxPremium, equals(48));
      expect(RewardConfig.scratchPremium, equals(48));
    });

    test('Mystery Chest: base range is 10 to 15 and 4x multiplier gives <= 60', () {
      expect(RewardConfig.chestMinBase, equals(10));
      expect(RewardConfig.chestMaxBase, equals(15));
      expect(RewardConfig.chestMultiplier, equals(4));

      const minPremium = RewardConfig.chestMinBase * RewardConfig.chestMultiplier;
      const maxPremium = RewardConfig.chestMaxBase * RewardConfig.chestMultiplier;

      expect(minPremium, equals(40));
      expect(maxPremium, equals(60));
      expect(RewardConfig.chestPremium, equals(60));
    });

    test('Watch Video: direct reward is 25 coins', () {
      expect(RewardConfig.watchVideoPremium, equals(25));
    });

    test('Mega Chest Milestone: 250 base and 500 double', () {
      expect(RewardConfig.megaChestBase, equals(250));
      expect(RewardConfig.megaChestPremium, equals(500));
    });

    test('Daily Streak Progression: escalation days 1 to 7', () {
      expect(RewardConfig.dailyStreakBaseRewards, equals([10, 15, 20, 25, 30, 40, 75]));
      expect(RewardConfig.dailyStreakPremiumRewards, equals([30, 45, 60, 75, 90, 120, 225]));

      for (int day = 1; day <= 7; day++) {
        final base = RewardConfig.getDailyStreakBaseReward(day);
        final premium = RewardConfig.getDailyStreakPremiumReward(day);
        expect(premium, equals(base * 3));
      }
    });
  });

  group('DailyCapService - Fallbacks and Dynamic Limit Ranges', () {
    late DailyCapService capService;
    late FakeSupabaseRepository mockRepo;

    setUp(() {
      mockRepo = FakeSupabaseRepository();
      capService = DailyCapService(mockRepo);
    });

    test('getRewardLimits returns harmonized defaults for chest, scratch, and spin', () {
      final chestLimits = capService.getRewardLimits('chest');
      expect(chestLimits.$1, equals(10));
      expect(chestLimits.$2, equals(15));

      final scratchLimits = capService.getRewardLimits('scratch');
      expect(scratchLimits.$1, equals(6));
      expect(scratchLimits.$2, equals(12));

      final spinLimits = capService.getRewardLimits('spin');
      expect(spinLimits.$1, equals(2));
      expect(spinLimits.$2, equals(12));
    });

    test('getBaseReward returns harmonized constants for fixed features', () {
      expect(capService.getBaseReward('ad'), equals(25));
      expect(capService.getBaseReward('chest'), equals(12));
      expect(capService.getBaseReward('scratch'), equals(9));
      expect(capService.getBaseReward('spin'), equals(6));
      expect(capService.getBaseReward('mega_chest'), equals(250));
    });

    test('getPremiumReward returns harmonized constants for fixed features', () {
      expect(capService.getPremiumReward('ad'), equals(25));
      expect(capService.getPremiumReward('chest'), equals(60));
      expect(capService.getPremiumReward('scratch'), equals(48));
      expect(capService.getPremiumReward('spin'), equals(48));
      expect(capService.getPremiumReward('mega_chest'), equals(500));
    });
  });
}
