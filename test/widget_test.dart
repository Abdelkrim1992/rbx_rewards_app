import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/main.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App onboarding and navigator smoke test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        userProfileStreamProvider.overrideWith((ref) => Stream.value(UserProfile(
              id: 'test_uid',
              coins: 0,
              totalEarned: 0,
              consecutiveDays: 0,
              gamesPlayed: 0,
              offersCompleted: 0,
              displayName: 'Test Player',
            ))),
        onboardingCompletedProvider
            .overrideWith((ref) => OnboardingNotifier(prefs)),
      ],
    );

    // Build our app with container to bypass background initialization timers
    await tester.pumpWidget(RbxRewardsApp(container: container));
    await tester.pump();

    // Verify that step 1 of onboarding is displayed
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Play Games'), findsOneWidget);

    // Step 1 -> Step 2
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify step 2
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Earn'), findsOneWidget);
    expect(find.text('Redeem'), findsOneWidget);

    // Step 2 -> Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify step 3
    expect(find.text('Start Earning'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);

    // Complete onboarding
    await tester.tap(find.text('Start Earning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Start Earning'), findsNothing);
  });
}
