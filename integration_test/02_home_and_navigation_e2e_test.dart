// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/patrol_test_helper.dart';

void main() {
  patrolTest(
    'E2E Journey 02: Home Feed, Quick Actions, Referral Sheet & Bottom Nav',
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
      // Check for Daily Streak / Check-In button
      final claimStreakFinder = $(RegExp(r'Claim Day \d+|Claim.*Reward|Check In', caseSensitive: false));
      if (claimStreakFinder.exists) {
        await claimStreakFinder.tap();
        await settleApp($, iterations: 10);

        // If reward choice dialog appears (base vs 2x video), tap Base or Claim
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
      final referralCard = $('Invite & Earn');
      expect(referralCard, findsOneWidget);
      await referralCard.tap();
      await settleApp($);

      // Inside Referral Bottom Sheet:
      // Verify sheet elements exist
      expect($('Your Referral Code'), findsWidgets);

      // Tap Copy Code or Share button
      final copyBtn = $(Icons.copy_rounded);
      if (copyBtn.exists) {
        await copyBtn.tap();
        await settleApp($);
      }

      // Close the sheet via Close icon or tapping barrier
      final closeSheetBtn = $(Icons.close_rounded);
      if (closeSheetBtn.exists) {
        await closeSheetBtn.tap();
      } else {
        // Pop the modal sheet
        Navigator.of($.tester.element($('Your Referral Code').first)).pop();
      }
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
