import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rbx_rewards/presentation/screens/scratch_card_screen.dart';
import 'package:rbx_rewards/widgets/reward_claim_dialog.dart';
import 'package:rbx_rewards/widgets/quit_confirmation_dialog.dart';
import 'package:rbx_rewards/widgets/ad_reward_dialog.dart';
import 'package:rbx_rewards/models/ad_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'scratch_free_date': todayStr,
      'scratch_free_remaining': 3,
      'extra_scratches_date': todayStr,
      'extra_scratches_remaining': 8,
    });
  });

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ScratchCardScreen Responsiveness Tests', () {
    final testSizes = [
      const Size(320, 568), // Compact (iPhone SE 1st gen / narrow Android)
      const Size(360, 780), // Standard Android
      const Size(375, 667), // iPhone SE 2/3 / iPhone 8
      const Size(393, 852), // iPhone 14/15/16 Pro
      const Size(430, 932), // iPhone Pro Max / Plus / Galaxy Ultra
      const Size(768, 1024), // iPad / Tablet
    ];

    for (final size in testSizes) {
      testWidgets('ScratchCardScreen renders without overflow on ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: ScratchCardScreen(onBack: () {}),
          ),
        );
        await tester.pumpAndSettle();

        // Verify zero overflow errors
        expect(tester.takeException(), isNull);

        // Verify key widgets
        expect(find.text('Scratch & Win'), findsOneWidget);
        expect(find.text('Scratch below to reveal!'), findsOneWidget);
        expect(find.text('How to Play'), findsOneWidget);
        expect(find.text('Scratch the Card'), findsOneWidget);
      });
    }

    testWidgets('ScratchCardScreen renders countdown limit banner without overflow on 320x568',
        (WidgetTester tester) async {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      SharedPreferences.setMockInitialValues({
        'scratch_free_date': todayStr,
        'scratch_free_remaining': 0,
        'extra_scratches_date': todayStr,
        'extra_scratches_remaining': 0,
      });

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestWidget(
          child: ScratchCardScreen(onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Resets in'), findsOneWidget);
    });

    testWidgets('ScratchCardScreen renders 0 scratches / watch ad banner without overflow on 320x568',
        (WidgetTester tester) async {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      SharedPreferences.setMockInitialValues({
        'scratch_free_date': todayStr,
        'scratch_free_remaining': 0,
        'extra_scratches_date': todayStr,
        'extra_scratches_remaining': 5,
      });

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestWidget(
          child: ScratchCardScreen(onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('0 Scratches Left'), findsOneWidget);
    });
  });

  group('Scratch Card Alerts Responsiveness Tests', () {
    testWidgets('RewardClaimDialog renders responsively on compact screen (320x568) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => RewardClaimDialog(
                    title: 'Scratch Card Reward',
                    baseReward: 25,
                    adPlacement: AdPlacement.scratchCard,
                    onClaimCompleted: (_) async {},
                  ),
                );
              },
              child: const Text('Open Reward Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Reward Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('SCRATCH CARD REWARD'), findsOneWidget);
      expect(find.textContaining('50 RBX'), findsOneWidget);
      expect(find.textContaining('25 RBX'), findsWidgets);
    });

    testWidgets('QuitConfirmationDialog renders responsively on compact screen (320x568) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showQuitConfirmationDialog(
                  context,
                  title: 'Quit Scratching?',
                  message: 'You have an active scratch card. Are you sure you want to leave?',
                );
              },
              child: const Text('Open Quit Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Quit Dialog'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quit Scratching?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
    });

    testWidgets('AdRewardDialog renders responsively on compact screen (320x568) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AdRewardDialog(
                    onRewardGranted: () async {},
                  ),
                );
              },
              child: const Text('Open Ad Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Ad Dialog'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('REWARDED AD'), findsOneWidget);
      expect(find.text('WATCHING AD...'), findsOneWidget);
    });
  });
}
