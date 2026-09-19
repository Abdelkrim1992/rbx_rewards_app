// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/patrol_test_helper.dart';

void main() {
  patrolTest(
    'E2E Journey 05: Profile Screen, Gamer Passport, Menu Tiles & Settings Navigation',
    ($) async {
      final container = await buildE2eContainer(
        onboardingCompleted: true,
        coins: 1250,
        totalEarned: 2500,
        streak: 4,
      );

      await pumpRbxApp($, container: container);

      // ─── 1. NAVIGATE TO PROFILE TAB ───────────────────────────────────────
      final profileNav = $('Profile').first;
      await profileNav.tap();
      await settleApp($);

      // Profile screen title
      expect($('Gamer Profile'), findsWidgets);
      // Displays the E2E Tester display name
      expect($('E2E Tester'), findsWidgets);

      // ─── 2. TEST COPY PLAYER ID BUTTON (1-tap inline copy icon) ──────────
      final copyIdBtn = $(Icons.copy_rounded);
      if (copyIdBtn.exists) {
        await copyIdBtn.first.tap();
        await settleApp($);
        // SnackBar: "Player Account ID copied to clipboard!"
        expect($(SnackBar), findsWidgets);
      }

      // ─── 3. TEST VIP TIER BADGE → VIEW PERKS MODAL → CLOSE ───────────────
      // VIP badge displays "Bronze Rookie • Lvl 1" etc.
      final vipPill = $(RegExp(r'Lvl \d+', caseSensitive: false));
      if (vipPill.exists) {
        await vipPill.first.tap();
        await settleApp($);

        final closePerks = $(RegExp(r'Close|Got It', caseSensitive: false));
        if (closePerks.exists) {
          await closePerks.first.tap();
          await settleApp($);
        } else {
          // Tap outside to dismiss modal
          await $.tester.tapAt(const Offset(200, 100));
          await settleApp($);
        }
      }

      // ─── 4. TEST "MY REWARDS" MENU TILE → BOTTOM SHEET → BACK ────────────
      final myRewardsTile = $('My Rewards');
      if (myRewardsTile.exists) {
        await myRewardsTile.first.tap();
        await settleApp($);

        final closeRewards = $(RegExp(r'Close|Done|Dismiss', caseSensitive: false));
        if (closeRewards.exists) {
          await closeRewards.first.tap();
          await settleApp($);
        } else {
          await $.tester.tapAt(const Offset(200, 100));
          await settleApp($);
        }
      }

      // ─── 5. TEST "TRANSACTION HISTORY" MENU TILE → BOTTOM SHEET → BACK ───
      final txHistoryTile = $('Transaction History');
      if (txHistoryTile.exists) {
        await txHistoryTile.first.tap();
        await settleApp($);

        final closeHistory = $(RegExp(r'Close|Done|Dismiss', caseSensitive: false));
        if (closeHistory.exists) {
          await closeHistory.first.tap();
          await settleApp($);
        } else {
          await $.tester.tapAt(const Offset(200, 100));
          await settleApp($);
        }
      }

      // ─── 6. TEST "HELP & SUPPORT" MENU TILE → DIALOG → CLOSE ─────────────
      final helpTile = $('Help & Support');
      if (helpTile.exists) {
        await helpTile.tap();
        await settleApp($);

        final closeHelp = $(RegExp(r'Close|Got It|Dismiss', caseSensitive: false));
        if (closeHelp.exists) {
          await closeHelp.first.tap();
          await settleApp($);
        }
      }

      // ─── 7. TEST "EDIT PROFILE" PENCIL ICON BUTTON ────────────────────────
      final editBtn = $(Icons.edit_rounded);
      if (editBtn.exists) {
        await editBtn.first.tap();
        await settleApp($);

        final saveOrClose = $(RegExp(r'Save|Cancel|Close', caseSensitive: false));
        if (saveOrClose.exists) {
          await saveOrClose.first.tap();
          await settleApp($);
        } else {
          await $.tester.tapAt(const Offset(200, 100));
          await settleApp($);
        }
      }

      // ─── 8. TEST "SETTINGS" MENU TILE → NAVIGATE → BACK ──────────────────
      // Re-find settings tile after possible modal dismissals
      final settingsTile = $('Settings');
      expect(settingsTile, findsOneWidget);
      await settingsTile.tap();
      await settleApp($);

      // Verify on Settings screen (has Privacy Policy and Delete Account & Data)
      expect($('Privacy Policy'), findsWidgets);
      expect($('Delete Account & Data'), findsWidgets);

      // Settings AppBar uses Icons.arrow_back_rounded (not ios variant)
      final backIos = $(Icons.arrow_back_ios_new_rounded);
      final backGeneric = $(Icons.arrow_back_rounded);
      if (backIos.exists) {
        await backIos.tap();
      } else if (backGeneric.exists) {
        await backGeneric.tap();
      }
      await settleApp($);

      // Verify returned to Profile screen
      expect($('Gamer Profile'), findsWidgets);
    },
  );
}
