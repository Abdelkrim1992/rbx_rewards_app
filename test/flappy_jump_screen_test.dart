import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/presentation/screens/flappy_jump_game_screen.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';

class MockCoinNotifier extends CoinNotifier {
  final int initial;
  MockCoinNotifier(this.initial);

  @override
  int build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FlappyJumpGameScreen renders menu overlay and coins with ProviderScope',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinProvider.overrideWith(() => MockCoinNotifier(250)),
        ],
        child: const MaterialApp(
          home: FlappyJumpGameScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify screen title and UI elements render
    expect(find.text('FLAPPY JUMP'), findsOneWidget);
    expect(find.text('TAP TO PLAY'), findsOneWidget);

    // Verify coins balance is displayed and no error is thrown
    expect(find.text('250'), findsOneWidget);
    expect(find.textContaining('No ProviderScope found'), findsNothing);
  });

  testWidgets('FlappyJumpGameScreen gracefully renders fallback if mounted without ProviderScope',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlappyJumpGameScreen(),
      ),
    );

    await tester.pump();

    // Verify screen renders without throwing Bad state: No ProviderScope found
    expect(find.text('FLAPPY JUMP'), findsOneWidget);
    expect(find.text('TAP TO PLAY'), findsOneWidget);
    expect(find.textContaining('No ProviderScope found'), findsNothing);
  });
}
