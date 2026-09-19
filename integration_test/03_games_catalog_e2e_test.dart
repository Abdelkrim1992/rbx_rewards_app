// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/patrol_test_helper.dart';

void main() {
  patrolTest(
    'E2E Journey 03: Games Catalog, Categories, Leaderboard & Mini-Games',
    ($) async {
      final container = await buildE2eContainer(
        onboardingCompleted: true,
        coins: 500,
        totalEarned: 1000,
      );

      await pumpRbxApp($, container: container);

      // ─── 1. NAVIGATE TO GAMES TAB ─────────────────────────────────────────
      final gamesNav = $('Games').first;
      await gamesNav.tap();
      await settleApp($);

      expect($('Play & Earn'), findsOneWidget);
      expect($('🏆 Leaderboard'), findsOneWidget);

      // ─── 2. TEST LEADERBOARD MODAL/SCREEN & BACK BUTTON ───────────────────
      await $('🏆 Leaderboard').tap();
      await settleApp($);

      // Verify Leaderboard is open
      expect($('Daily'), findsWidgets);
      expect($('All Time'), findsWidgets);

      // Test All-Time tab button
      await $('All Time').tap();
      await settleApp($);

      // Test Daily tab button
      await $('Daily').tap();
      await settleApp($);

      // Tap Back button on Leaderboard
      final backBtn = $(Icons.arrow_back_ios_new_rounded);
      final genericBack = $(Icons.arrow_back_rounded);
      if (backBtn.exists) {
        await backBtn.tap();
      } else if (genericBack.exists) {
        await genericBack.tap();
      } else {
        await $(#backBtn).tap();
      }
      await settleApp($);

      // Verify back on Games Screen
      expect($('Play & Earn'), findsOneWidget);

      // ─── 3. TEST CATEGORY FILTER CHIPS ────────────────────────────────────
      final arcadeChip = $('Arcade');
      if (arcadeChip.exists) {
        await arcadeChip.tap();
        await settleApp($);
      }

      final brainChip = $('Brain');
      if (brainChip.exists) {
        await brainChip.tap();
        await settleApp($);
      }

      final instantChip = $('Instant');
      if (instantChip.exists) {
        await instantChip.tap();
        await settleApp($);
      }

      final allChip = $('All');
      if (allChip.exists) {
        await allChip.tap();
        await settleApp($);
      }

      // ─── 4. TEST SPOTLIGHT HERO "PLAY NOW" BUTTON ─────────────────────────
      final spotlightPlay = $(RegExp(r'Play Now|Play Free', caseSensitive: false));
      if (spotlightPlay.exists) {
        await spotlightPlay.first.tap();
        await settleApp($, iterations: 10);

        // Exit back to Games
        final exitGameBtn = $(Icons.arrow_back_ios_new_rounded);
        final closeGameBtn = $(Icons.close_rounded);
        if (exitGameBtn.exists) {
          await exitGameBtn.first.tap();
        } else if (closeGameBtn.exists) {
          await closeGameBtn.first.tap();
        }
        await settleApp($);
      }

      // ─── 5. TEST GAME PREVIEW SHEET & START BUTTON ────────────────────────
      final gameCards = $(RegExp(r'Flappy Jump|Tap Tap|Math Quiz|Flip Card|Scratch'));
      if (gameCards.exists) {
        await gameCards.first.tap();
        await settleApp($);

        // If preview sheet opened, tap "Play Now" / "Start Game"
        final startBtn = $(RegExp(r'Start Game|Play Game|Play Now', caseSensitive: false));
        if (startBtn.exists) {
          await startBtn.tap();
          await settleApp($, iterations: 10);

          // Tap back to return
          final backAfterPlay = $(Icons.arrow_back_ios_new_rounded);
          if (backAfterPlay.exists) {
            await backAfterPlay.first.tap();
            await settleApp($);
          }
        }
      }
    },
  );
}
