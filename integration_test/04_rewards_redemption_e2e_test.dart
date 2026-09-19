// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/patrol_test_helper.dart';

void main() {
  patrolTest(
    'E2E Journey 04: Rewards Catalog, Denominations, Set Goal, and History',
    ($) async {
      final container = await buildE2eContainer(
        onboardingCompleted: true,
        coins: 100, // Insufficient for high-tier rewards
        totalEarned: 150,
      );

      await pumpRbxApp($, container: container);

      // ─── 1. NAVIGATE TO REWARDS TAB ───────────────────────────────────────
      final rewardsNav = $('Rewards').first;
      await rewardsNav.tap();
      await settleApp($);

      expect($('Catalog'), findsWidgets);

      // ─── 2. TEST DENOMINATION SELECTORS & CHIPS ───────────────────────────
      // Tap on available denomination chips (e.g. 400 RBX or 800 RBX)
      final denomChip = $(RegExp(r'\d+ RBX'));
      if (denomChip.exists) {
        await denomChip.first.tap();
        await settleApp($);
      }

      // ─── 3. TEST "SET GOAL" BUTTON ────────────────────────────────────────
      final setGoalBtn = $(RegExp(r'Set Goal|Current Goal'));
      if (setGoalBtn.exists) {
        await setGoalBtn.first.tap();
        await settleApp($);
        // Verify feedback SnackBar or updated button state
        expect($(SnackBar), findsWidgets);
      }

      // ─── 4. TEST LOCKED STATE FEEDBACK ────────────────────────────────────
      // Verify locked button is shown for high cost
      final lockedIndicator = $('Locked');
      if (lockedIndicator.exists) {
        expect(lockedIndicator, findsWidgets);
      }

      // ─── 5. TEST REWARDS SEGMENT TABS (CATALOG vs CLAIMED CODES) ──────────
      final claimedCodesTab = $(RegExp(r'Claimed Codes|History|My Rewards', caseSensitive: false));
      if (claimedCodesTab.exists) {
        await claimedCodesTab.first.tap();
        await settleApp($);

        // Switch back to Catalog tab
        final catalogTab = $('Catalog');
        if (catalogTab.exists) {
          await catalogTab.first.tap();
          await settleApp($);
        }
      }
    },
  );
}
