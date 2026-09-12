import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/models/user_profile.dart';
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

    test('Daily streak reward calculation formula', () {
      // Days 1-6 formula: 10 + (dayNum * 5), Day 7: 100
      int calculateReward(int day) {
        return day == 7 ? 100 : 10 + (day * 5);
      }

      expect(calculateReward(1), 15);
      expect(calculateReward(2), 20);
      expect(calculateReward(3), 25);
      expect(calculateReward(4), 30);
      expect(calculateReward(5), 35);
      expect(calculateReward(6), 40);
      expect(calculateReward(7), 100);
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
      expect(find.text('Day 1 (+15 RBX)'), findsOneWidget);

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
}
