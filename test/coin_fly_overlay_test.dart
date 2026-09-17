import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/business/sound_service.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/widgets/app_header.dart';
import 'package:rbx_rewards/widgets/coin_fly_overlay.dart';

class _FakeCoinNotifier extends CoinNotifier {
  final int initial;
  _FakeCoinNotifier(this.initial);

  @override
  int build() => initial;

  void setCoins(int value) {
    state = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.testInstance(enabled: true);
  });

  group('CoinFlyOverlay Tests', () {
    testWidgets('Spawns overlay and renders coin particles', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      CoinFlyOverlay.spawn(
                        context,
                        fromPosition: const Offset(200, 400),
                        coinCount: 8,
                        onComplete: () {
                          completed = true;
                        },
                      );
                    },
                    child: const Text('Spawn Coins'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Tap to spawn
      await tester.tap(find.text('Spawn Coins'));
      await tester.pump(); // insert overlay

      expect(find.byType(CoinFlyOverlay), findsOneWidget);

      // Advance animation halfway
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CoinFlyOverlay), findsOneWidget);

      // Advance animation to completion
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(find.byType(CoinFlyOverlay), findsNothing);
    });

    testWidgets('RbxAppHeader renders balance and rolls counter smoothly', (tester) async {
      final fakeNotifier = _FakeCoinNotifier(1000);
      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => fakeNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RbxAppHeader(),
            ),
          ),
        ),
      );

      expect(find.text('1,000'), findsOneWidget);
      expect(find.byKey(RbxAppHeader.balanceBadgeKey!), findsOneWidget);

      // Update coin balance to trigger roll counter and pulse
      fakeNotifier.setCoins(1250);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('1,250'), findsOneWidget);
    });

    testWidgets('RbxAppHeader pulses badge when pulseBadge is triggered', (tester) async {
      final fakeNotifier = _FakeCoinNotifier(500);
      final container = ProviderContainer(
        overrides: [
          coinProvider.overrideWith(() => fakeNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RbxAppHeader(),
            ),
          ),
        ),
      );

      expect(find.text('500'), findsOneWidget);

      // Trigger static pulse
      RbxAppHeader.pulseBadge();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('500'), findsOneWidget);
    });
  });
}
