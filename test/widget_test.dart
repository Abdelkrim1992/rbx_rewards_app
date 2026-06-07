import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbx_rewards_app/main.dart';
import 'package:rbx_rewards_app/presentation/providers/user_provider.dart';
import 'package:rbx_rewards_app/models/user_profile.dart';

class OnboardingNotifierMock extends OnboardingNotifier {
  OnboardingNotifierMock(bool initialValue) {
    state = initialValue;
  }

  @override
  Future<void> _load() async {
    // Sync loading bypassed
  }

  @override
  Future<void> setCompleted(bool completed) async {
    state = completed;
  }
}

void main() {
  testWidgets('App onboarding and navigator smoke test',
      (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override userProfileStreamProvider to bypass Supabase loading/auth
          userProfileStreamProvider.overrideWith((ref) => Stream.value(UserProfile(
            id: 'test_uid',
            coins: 0,
            totalEarned: 0,
            consecutiveDays: 0,
            gamesPlayed: 0,
            offersCompleted: 0,
            displayName: 'Test Player',
          ))),
          // Override onboardingCompletedProvider with mock notifier
          onboardingCompletedProvider.overrideWith((ref) => OnboardingNotifierMock(false)),
        ],
        child: const RbxRewardsApp(),
      ),
    );

    // Initial load/render
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify that onboarding screen is displayed with the 'Get Started' button.
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Play Games'), findsOneWidget);

    // Tap the 'Get Started' button and trigger a frame.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the home screen dashboard.
    expect(find.text('Get Started'), findsNothing);
  });
}
