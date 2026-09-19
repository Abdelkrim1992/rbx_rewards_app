import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rbx_rewards/presentation/screens/onboarding_screen.dart';
import '../../integration_test/helpers/patrol_test_helper.dart';

void main() {
  patrolWidgetTest(
    'E2E Suite 01: Complete Onboarding & Welcome Bonus Flow',
    ($) async {
      final container = await buildE2eContainer(
        onboardingCompleted: false,
        coins: 0,
      );

      await pumpRbxApp($, container: container);

      // ─── 1. VERIFY INITIAL STEP 1 ──────────────────────────────────────────
      expect($('Step 1 of 3'), findsOneWidget);
      expect($('Get Started'), findsOneWidget);
      expect($('Sign In'), findsOneWidget);

      // Back button should NOT exist on Step 1
      expect($(Icons.arrow_back_ios_new_rounded), findsNothing);

      // ─── 2. TEST "SIGN IN" SHORTCUT & BACK NAVIGATION ─────────────────────
      await $('Sign In').tap();
      await settleApp($);

      // Should have jumped to Step 3
      expect($('Step 3 of 3'), findsOneWidget);
      expect($(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      // Tap Back button on Step 3
      await $(Icons.arrow_back_ios_new_rounded).tap();
      await settleApp($);

      // Back to Step 2
      expect($('Step 2 of 3'), findsOneWidget);
      expect($('Continue'), findsOneWidget);

      // Tap Back button on Step 2
      await $(Icons.arrow_back_ios_new_rounded).tap();
      await settleApp($);

      // Back to Step 1
      expect($('Step 1 of 3'), findsOneWidget);

      // ─── 3. TEST STEP-BY-STEP PROGRESSION ─────────────────────────────────
      // Step 1: Tap "Get Started"
      await $('Get Started').tap();
      await settleApp($);
      expect($('Step 2 of 3'), findsOneWidget);

      // Step 2: Tap "Continue"
      await $('Continue').tap();
      await settleApp($);
      expect($('Step 3 of 3'), findsOneWidget);

      // ─── 4. TEST SIGN-IN BUTTONS (GOOGLE & APPLE) ─────────────────────────
      expect($('Continue with Google'), findsOneWidget);
      expect($('Continue with Apple'), findsOneWidget);

      // Tap "Continue with Google"
      await $('Continue with Google').tap();
      await settleApp($, iterations: 12);

      // ─── 5. TEST WELCOME BONUS OVERLAY CLAIM BUTTON ────────────────────────
      final claimBonusFinder = $(RegExp(r'Claim My \d+ Coins', caseSensitive: false));
      expect(claimBonusFinder, findsOneWidget);

      // Tap the celebratory Claim button
      await claimBonusFinder.tap();
      await settleApp($, iterations: 15);

      // ─── 6. VERIFY TRANSITION TO HOME SCREEN & BOTTOM NAV ─────────────────
      expect($('Home'), findsWidgets);
      expect($('Games'), findsWidgets);
      expect($('Rewards'), findsWidgets);
      expect($('Profile'), findsWidgets);

      // Verify onboarding is now marked complete in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    },
  );
}
