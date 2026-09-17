import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbx_rewards/business/daily_cap_service.dart';
import 'package:rbx_rewards/data/supabase_repository.dart';
import 'package:rbx_rewards/widgets/interactive_button.dart';
import 'package:rbx_rewards/widgets/congratulations_dialog.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';

class FakeSupabaseRepository implements SupabaseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeCoinNotifier extends CoinNotifier {
  @override
  int build() => 150;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('DailyCapService Video Ad Tests', () {
    late DailyCapService capService;
    late FakeSupabaseRepository mockRepo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      mockRepo = FakeSupabaseRepository();
      capService = DailyCapService(mockRepo);
    });

    test('Initial category cap for ad and watch_video is configured properly', () {
      expect(capService.getCategoryCap('ad'), 500);
      expect(capService.getCategoryCap('watch_video'), 500);
      expect(capService.getCategoryCap('video'), 500);
      expect(capService.getCategoryCap('watch_earn'), 500);
    });

    test('addCoins correctly adds coins for ad source and respects diminishing tier remaining cap', () {
      final added1 = capService.addCoins(50, 'ad');
      expect(added1, 50);
      expect(capService.todayWatchVideoEarnings, 50);
      expect(capService.getEarnedToday('ad'), 50);
      expect(capService.getRemainingCap('ad'), 1150); // Tier 1 (1200 - 50)

      final added2 = capService.addCoins(50, 'watch_video');
      expect(added2, 50);
      expect(capService.todayWatchVideoEarnings, 100);
      expect(capService.getRemainingCap('watch_video'), 1100); // Tier 1 (1200 - 100)
    });

    test('mega_chest and dynamic sources are not capped at 0', () {
      final added = capService.addCoins(1000, 'mega_chest');
      expect(added, 1000);
    });
  });

  group('InteractiveButton & CongratulationsDialog Widget Tests', () {
    testWidgets('InteractiveButton responds to standard tap gestures reliably', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveButton(
                text: 'Claim +50 RBX',
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Claim +50 RBX'), findsOneWidget);
      await tester.tap(find.text('Claim +50 RBX'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('CongratulationsDialog renders claim button and triggers onClaim callback', (tester) async {
      bool claimed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coinProvider.overrideWith(() => FakeCoinNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => CongratulationsDialog(
                        earnedCoins: 50,
                        title: 'Video Reward',
                        buttonText: 'Claim 50 Coins',
                        onClaim: () async {
                          claimed = true;
                        },
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('VIDEO REWARD'), findsOneWidget);
      expect(find.text('Claim 50 Coins'), findsOneWidget);

      // Coins must NOT have been credited yet — only after pressing claim
      expect(claimed, isFalse);

      await tester.tap(find.text('Claim 50 Coins'));
      await tester.pumpAndSettle();

      expect(claimed, isTrue);
      expect(find.text('VIDEO REWARD'), findsNothing);
    });

    testWidgets('CongratulationsDialog X button dismisses without crediting coins', (tester) async {
      bool claimed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coinProvider.overrideWith(() => FakeCoinNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => CongratulationsDialog(
                        earnedCoins: 50,
                        title: 'Video Reward',
                        buttonText: 'Claim 50 Coins',
                        onClaim: () async {
                          claimed = true;
                        },
                        onDismiss: () {},
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('VIDEO REWARD'), findsOneWidget);

      // Tap the X button (close)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Dialog dismissed, coins never credited
      expect(claimed, isFalse);
      expect(find.text('VIDEO REWARD'), findsNothing);
    });
  });
}
