import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rbx_rewards/business/auth_service.dart';
import 'package:rbx_rewards/data/secure_repository.dart';
import 'package:rbx_rewards/models/user_profile.dart';
import 'package:rbx_rewards/presentation/providers/data_providers.dart';
import 'package:rbx_rewards/presentation/providers/providers.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/presentation/screens/profile_screen.dart';
import 'package:rbx_rewards/presentation/screens/settings_screen.dart';
import 'package:rbx_rewards/widgets/bottom_nav.dart';

class MockAuthService extends AuthService {
  final bool _isSocial;
  bool deleteAccountCalled = false;
  MockAuthService({bool isSocial = false})
      : _isSocial = isSocial,
        super(secure: SecureRepository());

  @override
  bool get isDeviceAccount => !_isSocial;

  @override
  bool get isSocialAccount => _isSocial;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserProfile mockUser;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pref_notifications_enabled': true,
      'pref_sound_enabled': true,
      'pref_haptics_enabled': true,
      'pref_language': 'English',
    });

    mockUser = UserProfile(
      id: 'usr_abc12345678',
      coins: 1500,
      totalEarned: 12500,
      consecutiveDays: 5,
      gamesPlayed: 14,
      offersCompleted: 2,
      displayName: 'ProGamer123',
      createdAt: DateTime(2026, 1, 15),
    );
  });

  Widget createTestWidget({
    required Widget child,
    bool isSocial = false,
    MockAuthService? authService,
    OnboardingNotifier? onboardingNotifier,
  }) {
    final mockAuth = authService ?? MockAuthService(isSocial: isSocial);
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuth),
        if (onboardingNotifier != null)
          onboardingCompletedProvider.overrideWith((ref) => onboardingNotifier),
        userProfileStreamProvider.overrideWith((ref) => Stream.value(mockUser)),
        rewardHistoryProvider.overrideWith(
          (ref) async => [
            {
              'reward_title': 'Roblox 100 Robux Card',
              'status': 'approved',
              'claim_code': 'RBX-TEST-CODE',
            },
            {
              'reward_title': 'Roblox 200 Robux Card',
              'status': 'pending',
              'claim_code': '',
            },
          ],
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ProfileScreen & SettingsScreen Architecture Tests', () {
    testWidgets('ProfileScreen renders Gamer Passport, 3 Quick Stats, and Navigation items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: ProfileScreen(onNavTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Gamer Passport Header
      expect(find.text('ProGamer123'), findsOneWidget);
      expect(find.textContaining('ID: #USR_ABC1'), findsOneWidget);
      expect(find.textContaining(RegExp(r'Level 3|LEVEL 3|Lvl 3')), findsWidgets);

      // 2. Verify 3 Quick Stats Pills
      expect(find.text('1,500'), findsOneWidget);
      expect(find.text('RBX Coins'), findsOneWidget);

      expect(find.text('5'), findsOneWidget);
      expect(find.text('Day Streak'), findsOneWidget);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Rewards'), findsWidgets);

      // 3. Verify Grouped Menu Card Portals
      expect(find.text('My Rewards'), findsOneWidget);
      expect(find.text('Transaction History'), findsOneWidget);
      expect(find.text('Redeem Promo Code'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);

      // 4. Verify RbxBottomNav is displayed
      expect(find.byType(RbxBottomNav), findsOneWidget);
    });

    testWidgets('Tapping Settings opens SettingsScreen with Preferences and Legal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          child: ProfileScreen(onNavTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Settings'
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify on SettingsScreen
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Sound Effects (SFX)'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);

      // Verify Account & Security Group
      expect(find.text('ACCOUNT & SECURITY'), findsOneWidget);
      expect(find.text('Cloud Save & Backup'), findsOneWidget);
      expect(find.text('Delete Account & Data'), findsOneWidget);

      // Verify Legal & Support Group
      expect(find.text('LEGAL & SUPPORT'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('About RBX Rewards'), findsOneWidget);

      // As guest user, Logout button must NOT be displayed
      expect(find.text('Logout'), findsNothing);
    });

    testWidgets('Logout button is displayed when user is signed in with Google or Apple',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Check ProfileScreen for social user
      await tester.pumpWidget(
        createTestWidget(
          child: ProfileScreen(onNavTap: (_) {}),
          isSocial: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logout'), findsOneWidget);

      // 2. Check SettingsScreen for social user
      await tester.pumpWidget(
        createTestWidget(
          child: const SettingsScreen(),
          isSocial: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('Logout button is strictly hidden for guest/device users',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Check ProfileScreen for guest user
      await tester.pumpWidget(
        createTestWidget(
          child: ProfileScreen(onNavTap: (_) {}),
          isSocial: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logout'), findsNothing);

      // 2. Check SettingsScreen for guest user
      await tester.pumpWidget(
        createTestWidget(
          child: const SettingsScreen(),
          isSocial: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logout'), findsNothing);
    });

    testWidgets('Settings dialogs open and close properly (Privacy, Terms, About)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Test Privacy Policy
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy & Safety'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy & Safety'), findsNothing);

      // Test Terms of Service
      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsWidgets);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Test About Dialog
      await tester.tap(find.text('About RBX Rewards'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Version 1.0.4'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Version 1.0.4'), findsNothing);
    });

    testWidgets('Cloud Save sheet renders responsively on small mobile screens without overflow',
        (WidgetTester tester) async {
      // Test on ultra-compact mobile screen (e.g. iPhone SE 1st Gen 320x568)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to and tap Cloud Save & Backup
      await tester.ensureVisible(find.text('Cloud Save & Backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cloud Save & Backup'));
      await tester.pumpAndSettle();

      // Verify Cloud Save sheet content renders cleanly without overflow
      expect(find.text('Cloud Save & Security'), findsOneWidget);
      expect(find.textContaining('Link your Google or Apple ID'), findsOneWidget);
      expect(find.text('Link Apple ID'), findsOneWidget);
      expect(find.text('Link Google Account'), findsOneWidget);

      // Verify tapping inside the card does NOT dismiss it
      await tester.tap(find.text('Cloud Save & Security'));
      await tester.pumpAndSettle();
      expect(find.text('Cloud Save & Security'), findsOneWidget);

      // Verify tapping outside the sheet (near the top of screen) dismisses it
      await tester.tapAt(const Offset(50, 30));
      await tester.pumpAndSettle();
      expect(find.text('Cloud Save & Security'), findsNothing);
    });

    testWidgets('Redeem Promo Code modal opens from ProfileScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          child: ProfileScreen(onNavTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Redeem Promo Code
      await tester.tap(find.text('Redeem Promo Code'));
      await tester.pumpAndSettle();

      expect(find.text('Redeem Promo Code'), findsWidgets);
      expect(find.text('Apply Code'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('My Rewards sheet opens from ProfileScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          child: ProfileScreen(onNavTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Tap My Rewards
      await tester.tap(find.text('My Rewards'));
      await tester.pumpAndSettle();

      expect(find.text('My Claimed Rewards'), findsOneWidget);
      expect(find.text('Roblox 100 Robux Card'), findsOneWidget);
    });

    testWidgets('Delete Account opens confirmation, verifies text, calls deleteAccount and navigates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockAuthService();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      final onboardingNotifier = OnboardingNotifier(prefs);

      await tester.pumpWidget(
        createTestWidget(
          child: const SettingsScreen(),
          authService: mockAuth,
          onboardingNotifier: onboardingNotifier,
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal Delete Account button if needed
      await tester.drag(find.byType(SettingsScreen), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap Delete Account & Data
      final deleteBtn = find.text('Delete Account & Data');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Verify Delete Account Dialog is shown
      expect(find.text('Delete Account Permanently'), findsOneWidget);
      expect(find.text('Permanently Delete'), findsOneWidget);

      // Verify button is disabled initially
      final permanentlyDeleteFinder = find.widgetWithText(ElevatedButton, 'Permanently Delete');
      final ElevatedButton initialBtn = tester.widget(permanentlyDeleteFinder);
      expect(initialBtn.onPressed, isNull);

      // Type DELETE ACCOUNT
      await tester.enterText(find.byType(TextField), 'DELETE ACCOUNT');
      await tester.pumpAndSettle();

      // Verify button is now enabled
      final ElevatedButton enabledBtn = tester.widget(permanentlyDeleteFinder);
      expect(enabledBtn.onPressed, isNotNull);

      // Tap Permanently Delete
      await tester.tap(permanentlyDeleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify authService.deleteAccount() was invoked
      expect(mockAuth.deleteAccountCalled, isTrue);

      // Verify onboarding was reset to false
      expect(onboardingNotifier.state, isFalse);
    });

    testWidgets('ProfileScreen renders without any overflow across multiple mobile device sizes (320px, 360px, 375px, 393px, 430px)',
        (WidgetTester tester) async {
      final testSizes = [
        const Size(320, 568), // Compact (iPhone SE 1st gen / narrow Android)
        const Size(360, 780), // Standard Android (where the 7px overflow previously occurred)
        const Size(375, 667), // iPhone SE 2/3 / iPhone 8
        const Size(393, 852), // iPhone 14/15/16 Pro
        const Size(430, 932), // iPhone Pro Max / Plus / Galaxy Ultra
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: ProfileScreen(onNavTap: (_) {}),
            isSocial: true,
          ),
        );
        await tester.pumpAndSettle();

        // Ensure no exception or overflow error was triggered
        expect(tester.takeException(), isNull);

        // Verify key widgets are present
        expect(find.text('ProGamer123'), findsOneWidget);
        expect(find.textContaining('ID: #USR_ABC1'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
