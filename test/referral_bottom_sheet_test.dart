import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/models/referral_model.dart';
import 'package:rbx_rewards/presentation/providers/referral_provider.dart';
import 'package:rbx_rewards/widgets/referral_bottom_sheet.dart';

class MockReferralNotifier extends StateNotifier<AsyncValue<ReferralState>>
    implements ReferralNotifier {
  MockReferralNotifier(ReferralState initialState)
      : super(AsyncValue.data(initialState));

  String? lastRedeemedCode;
  ReferralRedeemResult nextResult = const ReferralRedeemResult(
    isSuccess: true,
    message: 'Success! You received +100 RBX Welcome Bonus! 🎉',
    coinsAwarded: 100,
  );

  @override
  Future<void> load() async {}

  @override
  Future<ReferralRedeemResult> redeemCode(String code) async {
    lastRedeemedCode = code;
    return nextResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const unredeemedState = ReferralState(
    myReferralCode: 'RBX-ALICE1',
    referredByCode: null,
    hasRedeemedCode: false,
    totalFriendsInvited: 4,
    totalCoinsEarned: 800,
  );

  const redeemedState = ReferralState(
    myReferralCode: 'RBX-ALICE1',
    referredByCode: 'RBX-BOB99',
    hasRedeemedCode: true,
    totalFriendsInvited: 2,
    totalCoinsEarned: 400,
  );

  Widget createTestWidget(MockReferralNotifier notifier) {
    return ProviderScope(
      overrides: [
        referralStateProvider.overrideWith((ref) => notifier),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ReferralBottomSheet(),
        ),
      ),
    );
  }

  group('ReferralBottomSheet Widget Tests', () {
    testWidgets('Renders header, invite code card, redeem section, and stats', (tester) async {
      final notifier = MockReferralNotifier(unredeemedState);

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Invite Friends & Earn'), findsOneWidget);
      expect(find.textContaining('Give a friend +100 RBX'), findsOneWidget);

      // Check User's Invite Code
      expect(find.text('YOUR INVITE CODE'), findsOneWidget);
      expect(find.text('RBX-ALICE1'), findsOneWidget);
      expect(find.text('Copy Invite Code'), findsOneWidget);

      // Check Redeem Section (unredeemed)
      expect(find.text("Have a Friend's Invite Code?"), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Claim +100'), findsOneWidget);

      // Check Stats
      expect(find.text('Friends Invited'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Total Earned'), findsOneWidget);
      expect(find.text('+800 RBX'), findsOneWidget);
    });

    testWidgets('Renders redeemed badge and hides input when user has already redeemed', (tester) async {
      final notifier = MockReferralNotifier(redeemedState);

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Should show redeemed badge with inviter's code
      expect(find.text('Redeemed code: RBX-BOB99'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Should NOT show redeem input field
      expect(find.byType(TextField), findsNothing);
      expect(find.text("Have a Friend's Invite Code?"), findsNothing);
    });

    testWidgets('Empty input displays validation error message', (tester) async {
      final notifier = MockReferralNotifier(unredeemedState);

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Tap Claim +100 with empty input
      await tester.tap(find.text('Claim +100'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter an invite code.'), findsOneWidget);
      expect(notifier.lastRedeemedCode, isNull);
    });

    testWidgets('Submitting valid code calls notifier and shows success message', (tester) async {
      final notifier = MockReferralNotifier(unredeemedState);

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Enter code in textfield
      await tester.enterText(find.byType(TextField), 'RBX-SUPER1');
      await tester.pumpAndSettle();

      // Tap Claim +100
      await tester.tap(find.text('Claim +100'));
      await tester.pumpAndSettle();

      expect(notifier.lastRedeemedCode, equals('RBX-SUPER1'));
      expect(find.text('Success! You received +100 RBX Welcome Bonus! 🎉'), findsOneWidget);
    });

    testWidgets('Submitting invalid code displays error message from backend', (tester) async {
      final notifier = MockReferralNotifier(unredeemedState);
      notifier.nextResult = const ReferralRedeemResult(
        isSuccess: false,
        message: 'Invalid invite code. No user found with this code.',
      );

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'RBX-FAKE99');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claim +100'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid invite code. No user found with this code.'), findsOneWidget);
    });

    testWidgets('Tapping Copy Invite Code displays SnackBar confirmation', (tester) async {
      final notifier = MockReferralNotifier(unredeemedState);

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Invite Code'));
      await tester.pumpAndSettle();

      expect(find.text('Invite code copied to clipboard!'), findsOneWidget);
    });

    testWidgets('Renders responsively on compact device (320x568) with keyboard insets without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = MockReferralNotifier(unredeemedState);

      await tester.pumpWidget(createTestWidget(notifier));
      await tester.pumpAndSettle();

      // Verify all components render cleanly without RenderFlex overflow
      expect(find.text('Invite Friends & Earn'), findsOneWidget);
      expect(find.text('YOUR INVITE CODE'), findsOneWidget);
      expect(find.text('RBX-ALICE1'), findsOneWidget);
      expect(find.text('Copy Invite Code'), findsOneWidget);
      expect(find.text("Have a Friend's Invite Code?"), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Claim +100'), findsOneWidget);
      expect(find.text('Friends Invited'), findsOneWidget);
      expect(find.text('Total Earned'), findsOneWidget);
    });

    testWidgets('Tapping outside popup dismisses it, while tapping inside does not', (tester) async {
      final notifier = MockReferralNotifier(unredeemedState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            referralStateProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ReferralBottomSheet.show(context),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Invite Friends & Earn'), findsOneWidget);

      // Tap inside the sheet (e.g. on the title)
      await tester.tap(find.text('Invite Friends & Earn'));
      await tester.pumpAndSettle();

      // Sheet should still be open
      expect(find.text('Invite Friends & Earn'), findsOneWidget);

      // Tap outside the sheet near the top of the screen
      await tester.tapAt(const Offset(50, 30));
      await tester.pumpAndSettle();

      // Sheet should now be dismissed
      expect(find.text('Invite Friends & Earn'), findsNothing);
    });
  });
}
