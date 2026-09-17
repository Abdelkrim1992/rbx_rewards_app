import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rbx_rewards/presentation/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({VoidCallback? onGetStarted}) {
    return ProviderScope(
      child: MaterialApp(
        home: OnboardingScreen(
          onGetStarted: onGetStarted ?? () {},
        ),
      ),
    );
  }

  group('OnboardingScreen Redesign Tests', () {
    testWidgets('Renders Step 1 with Get Started button and feature cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Play Games'), findsOneWidget);
      expect(find.text('Spin & Win'), findsOneWidget);
      expect(find.text('Unlock Rewards'), findsOneWidget);
      // Back button should not be visible on step 1
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('Navigates from Step 1 to Step 2 to Step 3 and allows going back',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Get Started -> Step 2
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Earn'), findsOneWidget);
      expect(find.text('Redeem'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      // Tap Back -> returns to Step 1
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Go forward to Step 3
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3 assertions
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('🎁 Welcome Gift'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('100% Secure • Cloud Save Enabled'), findsOneWidget);
    });

    testWidgets('Step 3 renders properly on compact devices without overflow',
        (WidgetTester tester) async {
      // Small screen test (e.g. compact Android screen)
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
