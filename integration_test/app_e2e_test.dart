import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/main.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/presentation/providers/data_providers.dart';
import 'package:rbx_rewards/models/user_profile.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RBX Rewards Real-Device End-to-End Suite', () {
    testWidgets('Complete End-to-End Journey: Onboarding, Home, Games, Rewards & Profile',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          userProfileStreamProvider.overrideWith((ref) => Stream.value(UserProfile(
                id: 'e2e_tester_uid',
                coins: 100,
                totalEarned: 150,
                consecutiveDays: 2,
                gamesPlayed: 5,
                offersCompleted: 1,
                displayName: 'Review Tester',
              ))),
          onboardingCompletedProvider
              .overrideWith((ref) => OnboardingNotifier(prefs)),
          rewardHistoryProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
        ],
      );

      // ─── STEP 1: LAUNCH APP & ONBOARDING ────────────────────────────
      await tester.pumpWidget(RbxRewardsApp(container: container));
      await tester.pumpAndSettle();

      // Verify Onboarding Step 1
      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Verify Onboarding Step 2
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify Onboarding Step 3 & Claim Bonus
      expect(find.text('Start Earning'), findsOneWidget);
      await tester.tap(find.text('Start Earning'));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      // If WelcomeBonusOverlay is displayed, tap claim
      final claimBonusBtn = find.textContaining('Claim My 50 Coins');
      if (claimBonusBtn.evaluate().isNotEmpty) {
        await tester.tap(claimBonusBtn);
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }
      await tester.pumpAndSettle();

      // ─── STEP 2: HOME SCREEN & NAVIGATION ───────────────────────────
      // Verify Bottom Navigation items exist
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Games'), findsWidgets);
      expect(find.text('Rewards'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);

      // Verify Referral Card is present and has no overflow
      expect(find.text('Invite & Earn'), findsOneWidget);

      // ─── STEP 3: GAMES SCREEN ───────────────────────────────────────
      // Tap on 'Games' tab in bottom navigation
      final gamesNav = find.text('Games').first;
      await tester.tap(gamesNav);
      await tester.pumpAndSettle();

      // Verify games catalog loaded
      expect(find.textContaining('Mini Games'), findsWidgets);

      // ─── STEP 4: REWARDS SCREEN & LOCKED BUTTON ─────────────────────
      // Tap on 'Rewards' tab in bottom navigation
      final rewardsNav = find.text('Rewards').first;
      await tester.tap(rewardsNav);
      await tester.pumpAndSettle();

      // Verify Catalog renders
      expect(find.textContaining('Rewards'), findsWidgets);

      // Tap 'Locked' button to verify interactive user feedback
      final lockedButtons = find.text('Locked');
      if (lockedButtons.evaluate().isNotEmpty) {
        await tester.tap(lockedButtons.first);
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('more RBX Coins to redeem'), findsOneWidget);
        await tester.pumpAndSettle();
      }

      // ─── STEP 5: PROFILE SCREEN & SETTINGS MODALS ───────────────────
      // Tap on 'Profile' tab in bottom navigation
      final profileNav = find.text('Profile').first;
      await tester.tap(profileNav);
      await tester.pumpAndSettle();

      // Open Settings from Profile menu
      final settingsMenu = find.text('Settings');
      expect(settingsMenu, findsOneWidget);
      await tester.tap(settingsMenu);
      await tester.pumpAndSettle();

      // Verify Settings options
      expect(find.text('Delete Account & Data'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);

      // Test Privacy Policy Dialog
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy & Safety'), findsOneWidget);
      final closeBtn = find.text('Close');
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn.first);
        await tester.pumpAndSettle();
      }

      // Test Delete Account Dialog (Apple Guideline 5.1.1v)
      await tester.tap(find.text('Delete Account & Data'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Account Permanently'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Permanently Delete'), findsOneWidget);

      // Cancel deletion to keep session intact
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Account Permanently'), findsNothing);
    });

    testWidgets('Account Deletion Complete Flow: Purges state and resets to Onboarding',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          userProfileStreamProvider.overrideWith((ref) => Stream.value(UserProfile(
                id: 'delete_tester_uid',
                coins: 50,
                totalEarned: 50,
                consecutiveDays: 1,
                gamesPlayed: 1,
                offersCompleted: 0,
                displayName: 'Delete Test',
              ))),
          onboardingCompletedProvider
              .overrideWith((ref) => OnboardingNotifier(prefs)),
        ],
      );

      await tester.pumpWidget(RbxRewardsApp(container: container));
      await tester.pumpAndSettle();

      // Navigate to Profile
      final profileNav = find.text('Profile').first;
      await tester.tap(profileNav);
      await tester.pumpAndSettle();

      // Open Settings
      final settingsMenu = find.text('Settings');
      expect(settingsMenu, findsOneWidget);
      await tester.tap(settingsMenu);
      await tester.pumpAndSettle();

      // Open Delete Account Dialog
      await tester.tap(find.text('Delete Account & Data'));
      await tester.pumpAndSettle();

      // Type DELETE ACCOUNT into confirmation field
      await tester.enterText(find.byType(TextField), 'DELETE ACCOUNT');
      await tester.pumpAndSettle();

      // Confirm permanent deletion
      await tester.tap(find.text('Permanently Delete'));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();

      // Verify app reset back to Onboarding Screen!
      expect(find.text('Get Started'), findsOneWidget);
    });
  });
}
