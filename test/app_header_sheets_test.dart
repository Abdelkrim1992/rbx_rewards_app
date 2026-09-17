import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/business/sound_service.dart';
import 'package:rbx_rewards/models/user_profile.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/widgets/app_header.dart';

class _FakeCoinNotifier extends CoinNotifier {
  final int initial;
  _FakeCoinNotifier(this.initial);

  @override
  int build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.testInstance(enabled: true);
  });

  group('RbxAppHeader Bottom Sheets Tests', () {
    testWidgets('Streak bottom sheet renders all 7 day roadmap rows and Keep It Up button without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final user = UserProfile(
        id: 'test-user-id',
        displayName: 'RobloxGamer',
        coins: 500,
        consecutiveDays: 3,
        totalEarned: 150,
        gamesPlayed: 0,
        offersCompleted: 0,
      );

      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => _FakeCoinNotifier(500)),
          userProfileProvider.overrideWithValue(user),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RbxAppHeader(),
            ),
          ),
        ),
      );

      // Tap the streak pill
      final streakPill = find.text('3');
      expect(streakPill, findsOneWidget);
      await tester.tap(streakPill);
      await tester.pumpAndSettle();

      // Verify streak modal content
      expect(find.text('3 Day Streak'), findsOneWidget);
      expect(find.text('7-Day Streak Roadmap'), findsOneWidget);
      expect(find.text('D1'), findsOneWidget);
      expect(find.text('D2'), findsOneWidget);
      expect(find.text('D3'), findsOneWidget);
      expect(find.text('D4'), findsOneWidget);
      expect(find.text('D5'), findsOneWidget);
      expect(find.text('D6'), findsOneWidget);
      expect(find.text('D7'), findsOneWidget);
      expect(find.text('Keep It Up!'), findsOneWidget);

      // Verify tapping Keep It Up closes modal
      await tester.tap(find.text('Keep It Up!'));
      await tester.pumpAndSettle();
      expect(find.text('7-Day Streak Roadmap'), findsNothing);
    });

    testWidgets('Balance bottom sheet renders all activity breakdown rows and Redeem button without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final user = UserProfile(
        id: 'test-user-id',
        displayName: 'RobloxGamer',
        coins: 750,
        consecutiveDays: 1,
        totalEarned: 200,
        gamesPlayed: 0,
        offersCompleted: 0,
      );

      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => _FakeCoinNotifier(750)),
          userProfileProvider.overrideWithValue(user),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RbxAppHeader(),
            ),
          ),
        ),
      );

      // Tap the coin balance badge
      final balanceBadge = find.text('750');
      expect(balanceBadge, findsOneWidget);
      await tester.tap(balanceBadge);
      await tester.pumpAndSettle();

      // Verify balance modal content
      expect(find.text('Coin Balance'), findsOneWidget);
      expect(find.text('750 RBX Coins'), findsOneWidget);
      expect(find.text('Daily Cap Left'), findsOneWidget);
      expect(find.text("Today's Activity Breakdown"), findsOneWidget);

      // Verify all activity rows
      expect(find.text('Daily Streak'), findsOneWidget);
      expect(find.text('Spin & Win'), findsOneWidget);
      expect(find.text('Scratch Cards'), findsOneWidget);
      expect(find.text('Arcade Mini-Games'), findsOneWidget);
      expect(find.text('Chests & Video Ads'), findsOneWidget);

      // Verify Redeem Robux button
      expect(find.text('Redeem Robux'), findsOneWidget);
    });

    testWidgets('Both bottom sheets render without overflow on compact 320x568 viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final user = UserProfile(
        id: 'test-user-id',
        displayName: 'RobloxGamer',
        coins: 900,
        consecutiveDays: 2,
        totalEarned: 300,
        gamesPlayed: 0,
        offersCompleted: 0,
      );

      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => _FakeCoinNotifier(900)),
          userProfileProvider.overrideWithValue(user),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RbxAppHeader(),
            ),
          ),
        ),
      );

      // Open streak sheet on 320x568
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(find.text('2 Day Streak'), findsOneWidget);
      expect(find.text('Keep It Up!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Close streak sheet
      await tester.tap(find.text('Keep It Up!'));
      await tester.pumpAndSettle();

      // Open balance sheet on 320x568
      await tester.tap(find.text('900'));
      await tester.pumpAndSettle();
      expect(find.text("Today's Activity Breakdown"), findsOneWidget);
      expect(find.text('Redeem Robux'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
