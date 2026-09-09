import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbx_rewards/presentation/screens/rewards_screen.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/presentation/providers/data_providers.dart';
import 'package:rbx_rewards/models/user_profile.dart';

class MockCoinNotifier extends CoinNotifier {
  @override
  int build() => 0;
}

void main() {
  testWidgets(
      'Locked redeem reward notification disappears when browsing to another navigation menu',
      (WidgetTester tester) async {
    int tappedNavIndex = -1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinProvider.overrideWith(() => MockCoinNotifier()),
          rewardHistoryProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
          userProfileProvider.overrideWithValue(UserProfile(
            id: 'test_uid',
            coins: 0,
            totalEarned: 0,
            consecutiveDays: 0,
            gamesPlayed: 0,
            offersCompleted: 0,
            displayName: 'Test Player',
          )),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RewardsScreen(
              onNavTap: (index) {
                tappedNavIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Locked buttons exist
    final lockedButton = find.text('Locked').first;
    expect(lockedButton, findsOneWidget);

    // Tap the locked redeem button
    await tester.tap(lockedButton);
    await tester.pump();

    // Verify SnackBar notification is displayed
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('more RBX Coins to redeem'), findsOneWidget);

    // Tap on another navigation menu item (e.g., Home tab at index 0)
    final homeNav = find.text('Home');
    expect(homeNav, findsOneWidget);
    await tester.tap(homeNav);
    await tester.pump();

    // Verify nav tap callback was invoked
    expect(tappedNavIndex, 0);

    // Verify that the notification disappears / is cleared
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
