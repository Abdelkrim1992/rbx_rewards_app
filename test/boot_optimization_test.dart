import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbx_rewards/theme/app_theme.dart';
import 'package:rbx_rewards/utils/image_precache_helper.dart';
import 'package:rbx_rewards/widgets/deferred_game_loader.dart';
import 'package:rbx_rewards/widgets/circular_gradient_spinner.dart';
import 'package:rbx_rewards/presentation/screens/loading_screen.dart';
import 'package:rbx_rewards/business/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Boot & Startup Optimization Tests', () {
    test('AppAssets defines lightweight bootPrecacheAssets (< 4 items)', () {
      expect(AppAssets.bootPrecacheAssets.length, lessThanOrEqualTo(3));
      expect(AppAssets.bootPrecacheAssets, contains(AppAssets.rbxLogo));
      expect(AppAssets.bootPrecacheAssets, contains(AppAssets.appIcon));
      // Mini-games and reward cards should NOT be in the boot list
      expect(AppAssets.bootPrecacheAssets, isNot(contains(AppAssets.flappyJumpGame)));
      expect(AppAssets.bootPrecacheAssets, isNot(contains(AppAssets.tapTapGame)));
      expect(AppAssets.bootPrecacheAssets, isNot(contains(AppAssets.roblox10UsdCard)));
    });

    test('AppAssets uses WebP for watchEarnIcon', () {
      expect(AppAssets.watchEarnIcon.endsWith('.webp'), isTrue);
    });

    testWidgets('DeferredGameLoader shows spinner then renders game once library loads',
        (WidgetTester tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: DeferredGameLoader(
            title: 'Flappy Jump',
            loadLibrary: () => completer.future,
            builder: () => const Scaffold(body: Text('Flappy Game Loaded')),
          ),
        ),
      );

      // Initially should show loading state with game title
      expect(find.byType(CircularGradientSpinner), findsOneWidget);
      expect(find.text('Loading Flappy Jump...'), findsOneWidget);
      expect(find.text('Flappy Game Loaded'), findsNothing);

      // Complete library load
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Now game screen should be visible
      expect(find.text('Flappy Game Loaded'), findsOneWidget);
      expect(find.byType(CircularGradientSpinner), findsNothing);
    });

    testWidgets('DeferredGameLoader displays retry UI on load failure',
        (WidgetTester tester) async {
      bool shouldFail = true;

      await tester.pumpWidget(
        MaterialApp(
          home: DeferredGameLoader(
            title: 'Scratch Card',
            loadLibrary: () async {
              if (shouldFail) {
                throw Exception('Network error loading library fragment');
              }
            },
            builder: () => const Scaffold(body: Text('Scratch Game Loaded')),
          ),
        ),
      );

      // Allow async load to reject
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify error state
      expect(find.text('Could not load Scratch Card'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Click retry with success
      shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify recovery
      expect(find.text('Scratch Game Loaded'), findsOneWidget);
    });

    testWidgets('LoadingScreen boot sequence completes smoothly without hanging',
        (WidgetTester tester) async {
      bool bootstrapCalled = false;
      bool readyCalled = false;
      final testContainer = ProviderContainer();

      await tester.pumpWidget(
        MaterialApp(
          home: LoadingScreen(
            onBootstrap: () async {
              bootstrapCalled = true;
              return testContainer;
            },
            onReady: (container) {
              readyCalled = true;
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(bootstrapCalled, isTrue);
      expect(readyCalled, isTrue);
    });

    testWidgets('ImagePrecacheHelper precacheBootAssets and precacheBackground run safely',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await ImagePrecacheHelper.precacheBootAssets(context);
                  await ImagePrecacheHelper.precacheBackground(context);
                  await ImagePrecacheHelper.precacheAll(context);
                },
                child: const Text('Precache'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Precache'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Precache'), findsOneWidget);
    });

    test('SoundService is lazy-safe when play methods are called before init', () async {
      final service = SoundService.testInstance(enabled: false);
      expect(service.isSoundEnabled, isFalse);

      // Calling play methods when sound is disabled or not pre-initialized should not throw
      await expectLater(service.playCoin(), completes);
      await expectLater(service.playButton(), completes);
      await expectLater(service.playBubble(), completes);
      await expectLater(service.playWheelTick(), completes);
      await expectLater(service.stopAll(), completes);
    });
  });
}
