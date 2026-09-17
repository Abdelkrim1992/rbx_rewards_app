import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/main.dart';
import 'package:rbx_rewards/business/auth_service.dart';
import 'package:rbx_rewards/presentation/providers/providers.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/models/user_profile.dart';

class _TestAuthService extends AuthService {
  _TestAuthService({required super.secure});

  @override
  Future<bool> signInWithGoogle() async => true;
}

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
        authServiceProvider.overrideWith(
          (ref) => _TestAuthService(secure: ref.watch(secureRepositoryProvider)),
        ),
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

    // 7. Step 3: Verify 'Your first reward is waiting' & +500 bonus elements
    expect(find.byKey(const ValueKey('google_btn')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
    expect(find.text('🎁 Welcome Gift'), findsOneWidget);

    // 8. Tap 'Continue with Google' -> shows welcome bonus overlay if enabled, then transitions to HomeScreen
    await tester.tap(find.byKey(const ValueKey('google_btn')));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    final claimOverlayBtn = find.textContaining('Claim My 500 Coins');
    if (claimOverlayBtn.evaluate().isNotEmpty) {
      await tester.tap(claimOverlayBtn);
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // 9. Verify transition to HomeScreen and immediate 500 coins balance
    expect(find.byKey(const ValueKey('google_btn')), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('500'), findsWidgets);
    expect(container.read(coinProvider), 500);

    // 10. Verify SharedPreferences has persisted completion and bonus claim
    expect(prefs.getBool('onboarding_completed'), true);
    expect(prefs.getBool('welcome_bonus_claimed'), true);
  });
}
