import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../../integration_test/helpers/patrol_test_helper.dart';

void main() {
  patrolWidgetTest(
    'E2E Suite 02: Home Feed, Daily Retention Hub, Referral Sheet & Bottom Nav',
    ($) async {
      final container = await buildE2eContainer(
        onboardingCompleted: true,
        coins: 250,
        totalEarned: 500,
        streak: 2,
      );

      await pumpRbxApp($, container: container);

      // ─── 1. VERIFY HOME SCREEN HEADER BUTTONS ──────────────────────────────
      expect($('Home'), findsWidgets);
      expect($('250'), findsWidgets); // Coin balance in header

      // Test notifications bell icon button
      final notifBell = $(Icons.notifications_outlined);
      if (notifBell.exists) {
        await notifBell.tap();
        await settleApp($);
      }

      // ─── 2. TEST DAILY RETENTION HUB & STREAK CLAIM ────────────────────────
      final claimStreakFinder = $(RegExp(r'Claim Day \d+|Claim.*Reward|Check In', caseSensitive: false));
      if (claimStreakFinder.exists) {
        await claimStreakFinder.first.tap();
        await settleApp($, iterations: 10);

        final claimBase = $('Claim Base');
        final claimRegular = $('Claim');
        if (claimBase.exists) {
          await claimBase.tap();
          await settleApp($);
        } else if (claimRegular.exists) {
          await claimRegular.tap();
          await settleApp($);
        }
      }

      // ─── 3. TEST "INVITE & EARN" REFERRAL CARD & BOTTOM SHEET ─────────────
      await $.tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await settleApp($);
      final referralCard = $('Invite & Earn');
      expect(referralCard, findsOneWidget);
      await referralCard.tap();
      await settleApp($, iterations: 12);

      // Inside Referral Bottom Sheet:
      expect($('Invite Friends & Earn'), findsWidgets);

      // Tap Copy Code button if present
      final copyBtn = $(Icons.copy_rounded);
      if (copyBtn.exists) {
        await copyBtn.first.tap();
        await settleApp($);
      }

      // Dismiss the bottom sheet
      Navigator.of($.tester.element($('Invite Friends & Earn').first)).pop();
      await settleApp($);

      // ─── 4. TEST BOTTOM NAVIGATION BAR (EVERY TAB BUTTON) ─────────────────
      // Tab 1: Games
      final gamesNav = $('Games').first;
      await gamesNav.tap();
      await settleApp($);
      expect($('Mini Games'), findsWidgets);

      // Tab 2: Rewards
      final rewardsNav = $('Rewards').first;
      await rewardsNav.tap();
      await settleApp($);
      expect($('Catalog'), findsWidgets);

      // Tab 3: Profile
      final profileNav = $('Profile').first;
      await profileNav.tap();
      await settleApp($);
      expect($('Settings'), findsWidgets);

      // Tab 0: Back to Home
      final homeNav = $('Home').first;
      await homeNav.tap();
      await settleApp($);
      expect($('Invite & Earn'), findsOneWidget);
    },
  );
}
