// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/patrol_test_helper.dart';

void main() {
  patrolTest(
    'E2E Journey 06: Settings Switches, Legal Modals & Permanent Account Deletion',
    ($) async {
      final container = await buildE2eContainer(
        onboardingCompleted: true,
        coins: 1000,
        totalEarned: 2000,
        streak: 5,
      );

      await pumpRbxApp($, container: container);

      // ─── 1. NAVIGATE TO PROFILE -> SETTINGS ───────────────────────────────
      final profileNav = $('Profile').first;
      await profileNav.tap();
      await settleApp($);

      final settingsTile = $('Settings');
      expect(settingsTile, findsOneWidget);
      await settingsTile.tap();
      await settleApp($);

      // Verify on Settings screen
      expect($('Privacy Policy'), findsWidgets);
      expect($('Delete Account & Data'), findsWidgets);

      // ─── 2. TEST SWITCH TOGGLES (SOUND, NOTIFICATIONS, HAPTICS) ───────────
      final switches = $(Switch);
      final switchCount = switches.evaluate().length;
      for (int i = 0; i < switchCount; i++) {
        await switches.at(i).tap();
        await settleApp($);
      }

      // ─── 3. TEST "CLEAR CACHE & TEMP FILES" TILE ───────────────────────────
      // Title in settings_screen.dart: 'Clear Cache & Temp Files'
      final clearCacheBtn = $(RegExp(r'Clear Cache|Tap to Clear|Clearing', caseSensitive: false));
      if (clearCacheBtn.exists) {
        await clearCacheBtn.first.tap();
        await settleApp($, iterations: 10);
        // SnackBar: 'Image & temporary cache cleared!'
        expect($(SnackBar), findsWidgets);
      }

      // ─── 4. TEST "RATE RBX REWARDS" TILE ───────────────────────────────
      final rateBtn = $('Rate RBX Rewards');
      if (rateBtn.exists) {
        await rateBtn.tap();
        await settleApp($);
        expect($(SnackBar), findsWidgets);
      }

      // ─── 5. TEST "DISCORD & COMMUNITY" TILE ─────────────────────────────
      final discordBtn = $('Discord & Community');
      if (discordBtn.exists) {
        await discordBtn.tap();
        await settleApp($);
      }

      // ─── 6. TEST "HELP CENTER & FAQ" TILE ──────────────────────────────
      final helpFaqBtn = $('Help Center & FAQ');
      if (helpFaqBtn.exists) {
        await helpFaqBtn.tap();
        await settleApp($);

        final closeHelp = $(RegExp(r'Close|Got It|Dismiss', caseSensitive: false));
        if (closeHelp.exists) {
          await closeHelp.first.tap();
          await settleApp($);
        } else {
          await $.tester.tapAt(const Offset(200, 100));
          await settleApp($);
        }
      }

      // ─── 7. TEST PRIVACY POLICY MODAL & CLOSE BUTTON ─────────────────────
      final privacyBtn = $('Privacy Policy');
      expect(privacyBtn, findsWidgets);
      await privacyBtn.first.tap();
      await settleApp($);

      expect($('Privacy Policy & Safety'), findsOneWidget);
      final closePrivacy = $('Close');
      expect(closePrivacy, findsWidgets);
      await closePrivacy.first.tap();
      await settleApp($);

      // ─── 8. TEST TERMS OF SERVICE MODAL & CLOSE BUTTON ───────────────────
      final termsBtn = $('Terms of Service');
      expect(termsBtn, findsWidgets);
      await termsBtn.first.tap();
      await settleApp($);

      expect($('Terms of Service & Rules'), findsOneWidget);
      final closeTerms = $('Close');
      expect(closeTerms, findsWidgets);
      await closeTerms.first.tap();
      await settleApp($);

      // ─── 9. TEST "ABOUT & DIAGNOSTICS" TILE ─────────────────────────────
      final aboutTile = $('About & Diagnostics');
      if (aboutTile.exists) {
        await aboutTile.tap();
        await settleApp($);

        final closeAbout = $(RegExp(r'Close|OK|Done', caseSensitive: false));
        if (closeAbout.exists) {
          await closeAbout.first.tap();
          await settleApp($);
        } else {
          await $.tester.tapAt(const Offset(200, 100));
          await settleApp($);
        }
      }

      // ─── 10. TEST "LOGOUT SESSION" BUTTON → CANCEL DIALOG ─────────────────
      final logoutBtn = $('Logout Session');
      if (logoutBtn.exists) {
        await logoutBtn.tap();
        await settleApp($);

        // Cancel to stay logged in
        final cancelLogout = $(RegExp(r'Cancel|No|Go Back', caseSensitive: false));
        if (cancelLogout.exists) {
          await cancelLogout.first.tap();
          await settleApp($);
        } else {
          await $.tester.tapAt(const Offset(200, 100));
          await settleApp($);
        }
      }


      // ─── 6. TEST DELETE ACCOUNT MODAL & "CANCEL" BUTTON ───────────────────
      final deleteMenu = $('Delete Account & Data');
      expect(deleteMenu, findsOneWidget);
      await deleteMenu.tap();
      await settleApp($);

      // Verify Delete Account Permanently dialog is displayed
      expect($('Delete Account Permanently'), findsOneWidget);
      expect($('Cancel'), findsOneWidget);
      expect($('Permanently Delete'), findsOneWidget);

      // Tap "Cancel" to verify it does not delete and returns to Settings
      await $('Cancel').tap();
      await settleApp($);
      expect($('Delete Account Permanently'), findsNothing);
      expect($('Delete Account & Data'), findsOneWidget);

      // ─── 7. TEST PERMANENT ACCOUNT DELETION & RESET TO ONBOARDING ─────────
      await $('Delete Account & Data').tap();
      await settleApp($);

      // Type confirmation text "DELETE ACCOUNT"
      await $(TextField).enterText('DELETE ACCOUNT');
      await settleApp($);

      // Tap "Permanently Delete"
      await $('Permanently Delete').tap();
      await settleApp($, iterations: 15);

      // ─── 8. VERIFY COMPLETE PURGE & RESET TO ONBOARDING SCREEN ────────────
      expect($('Step 1 of 3'), findsOneWidget);
      expect($('Get Started'), findsOneWidget);

      // Verify SharedPreferences reset
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isFalse);
    },
  );
}
