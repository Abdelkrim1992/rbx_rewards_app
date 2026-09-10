import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/main.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'First install displays 3-step OnboardingScreen, credits welcome bonus, then navigates to HomeScreen',
      (WidgetTester tester) async {
    // Set standard mobile screen size to avoid default 800x600 test layout overflow
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. Simulate fresh install with empty SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        userProfileStreamProvider.overrideWith((ref) => Stream.value(UserProfile(
              id: 'first_install_uid',
              coins: 0,
              totalEarned: 0,
              consecutiveDays: 0,
              gamesPlayed: 0,
              offersCompleted: 0,
              displayName: 'New Player',
            ))),
        onboardingCompletedProvider
            .overrideWith((ref) => OnboardingNotifier(prefs)),
      ],
    );

    // 2. Launch the app
    await tester.pumpWidget(RbxRewardsApp(container: container));
    await tester.pump();

    // 3. Step 1: Verify 'Earn RBX Rewards Daily' elements
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Play Games'), findsOneWidget);
    expect(find.text('Spin & Win'), findsOneWidget);
    expect(find.text('Unlock Rewards'), findsOneWidget);
    expect(find.byKey(const ValueKey('loading')), findsNothing);

    // 4. Tap 'Get Started' -> navigates to Step 2
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // 5. Step 2: Verify 'Play. Earn. Redeem.' elements
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Earn'), findsOneWidget);
    expect(find.text('Redeem'), findsOneWidget);

    // 6. Tap 'Continue' -> navigates to Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 7. Step 3: Verify 'Your first reward is waiting' & +50 bonus elements
    expect(find.text('Start Earning'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
    expect(find.text('Your first milestone'), findsOneWidget);

    // 8. Tap 'Start Earning' -> credits bonus, marks onboarding completed, transitions to HomeScreen
    await tester.tap(find.text('Start Earning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // 9. Verify transition to HomeScreen
    expect(find.text('Start Earning'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);

    // 10. Verify SharedPreferences has persisted completion and bonus claim
    expect(prefs.getBool('onboarding_completed'), true);
    expect(prefs.getBool('welcome_bonus_claimed'), true);
  });
}
