import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/models/user_profile.dart';
import 'package:rbx_rewards/models/reward_config.dart';
import 'package:rbx_rewards/models/claim_result.dart';
import 'package:rbx_rewards/widgets/streak_saver_sheet.dart';

void main() {
  group('Streak Bonus & UserProfile Model Tests', () {
    test('UserProfile parses dailyRewardClaimedAt properly', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'test-uuid',
        'balance': 250,
        'total_earned': 500,
        'consecutive_days': 5,
        'games_played': 10,
        'offers_completed': 2,
        'display_name': 'WinnerPlayer',
        'daily_reward_claimed_at': now.toIso8601String(),
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'test-uuid');
      expect(profile.coins, 250);
      expect(profile.consecutiveDays, 5);
      expect(profile.dailyRewardClaimedAt, isNotNull);
      expect(
        profile.dailyRewardClaimedAt!.millisecondsSinceEpoch,
        closeTo(now.millisecondsSinceEpoch, 1000),
      );
    });

    test('UserProfile copyWith preserves or updates dailyRewardClaimedAt', () {
      final initialTime = DateTime(2026, 1, 1);
      final profile = UserProfile(
        id: 'u1',
        coins: 100,
        totalEarned: 100,
        consecutiveDays: 3,
        gamesPlayed: 5,
        offersCompleted: 1,
        displayName: 'Player',
        dailyRewardClaimedAt: initialTime,
      );

      final updatedTime = DateTime(2026, 1, 2);
      final updated = profile.copyWith(
        consecutiveDays: 4,
        dailyRewardClaimedAt: updatedTime,
      );

      expect(updated.consecutiveDays, 4);
      expect(updated.dailyRewardClaimedAt, updatedTime);

      final preserved = profile.copyWith(coins: 200);
      expect(preserved.dailyRewardClaimedAt, initialTime);
    });

    test('Daily streak escalating reward schedule (Days 1 to 7)', () {
      expect(RewardConfig.getDailyStreakBaseReward(1), 10);
      expect(RewardConfig.getDailyStreakBaseReward(2), 15);
      expect(RewardConfig.getDailyStreakBaseReward(3), 20);
      expect(RewardConfig.getDailyStreakBaseReward(4), 25);
      expect(RewardConfig.getDailyStreakBaseReward(5), 30);
      expect(RewardConfig.getDailyStreakBaseReward(6), 40);
      expect(RewardConfig.getDailyStreakBaseReward(7), 75);

      // Premium x3 schedule
      expect(RewardConfig.getDailyStreakPremiumReward(1), 30);
      expect(RewardConfig.getDailyStreakPremiumReward(2), 45);
      expect(RewardConfig.getDailyStreakPremiumReward(3), 60);
      expect(RewardConfig.getDailyStreakPremiumReward(4), 75);
      expect(RewardConfig.getDailyStreakPremiumReward(5), 90);
      expect(RewardConfig.getDailyStreakPremiumReward(6), 120);
      expect(RewardConfig.getDailyStreakPremiumReward(7), 225);
    });
  });

  group('StreakSaverSheet Widget Tests', () {
    testWidgets('Renders StreakSaverSheet with proper streak and actions', (tester) async {
      bool saveCalled = false;
      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakSaverSheet(
              currentStreak: 5,
              nextDay: 6,
              rewardAmount: 40,
              onSaveWithAd: () => saveCalled = true,
              onResetStreak: () => resetCalled = true,
            ),
          ),
        ),
      );

      // Verify title and streak text
      expect(find.text('Streak at Risk!'), findsOneWidget);
      expect(find.textContaining('5-Day Streak'), findsOneWidget);
      expect(find.text('Keep Day 5'), findsOneWidget);
      expect(find.text('Unlock Day 6 (+40)'), findsOneWidget);
      expect(find.text('Start Over'), findsOneWidget);
      expect(find.text('Day 1 (+10 RBX)'), findsOneWidget);

      // Tap Save Streak
      await tester.tap(find.text('Save Streak (Watch Video)'));
      await tester.pump();
      expect(saveCalled, isTrue);

      // Tap Reset Streak
      await tester.tap(find.text('No thanks, start over at Day 1'));
      await tester.pump();
      expect(resetCalled, isTrue);
    });
  });

  group('ClaimResult Parsing & Daily Reward Deduplication Tests', () {
    test('ClaimResult parses nested edge function response with newBalance', () {
      final edgeResponse = {
        'success': true,
        'amount': 10,
        'data': {
          'success': true,
          'amount': 10,
          'balance': 210,
          'consecutive_days': 2,
        },
      };

      final result = ClaimResult.fromMap(edgeResponse);
      expect(result.success, isTrue);
      expect(result.amount, 10);
      expect(result.newBalance, 210);
      expect(result.consecutiveDays, 2);
      expect(result.isOffline, isFalse);
    });

    test('ClaimResult parses flat response', () {
      final flatResponse = {
        'success': true,
        'amount': 30,
        'balance': 350,
        'consecutive_days': 4,
      };

      final result = ClaimResult.fromMap(flatResponse);
      expect(result.success, isTrue);
      expect(result.amount, 30);
      expect(result.newBalance, 350);
      expect(result.consecutiveDays, 4);
      expect(result.isOffline, isFalse);
    });

    test('ClaimResult.offlineClaim marks claim as isOffline', () {
      final offline = ClaimResult.offlineClaim(amount: 10);
      expect(offline.success, isTrue);
      expect(offline.amount, 10);
      expect(offline.isOffline, isTrue);
    });
  });
}
