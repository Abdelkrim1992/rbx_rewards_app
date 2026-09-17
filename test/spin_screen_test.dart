import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:rbx_rewards/presentation/screens/spin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'spin_free_date': todayStr,
      'spin_free_spins': 3,
      'extra_spins_date': todayStr,
      'extra_spins_remaining': 5,
    });
  });

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('SpinScreen Responsiveness Tests', () {
    final testSizes = [
      const Size(320, 568), // Compact (iPhone SE 1st gen / narrow Android)
      const Size(360, 780), // Standard Android
      const Size(375, 667), // iPhone SE 2/3 / iPhone 8
      const Size(393, 852), // iPhone 14/15/16 Pro
      const Size(430, 932), // iPhone Pro Max / Plus / Galaxy Ultra
      const Size(768, 1024), // iPad / Tablet
    ];

    for (final size in testSizes) {
      testWidgets('SpinScreen renders without overflow on ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            child: SpinScreen(onBack: () {}),
          ),
        );
        await tester.pumpAndSettle();

        // Verify zero overflow errors
        expect(tester.takeException(), isNull);

        // Verify key widgets
        expect(find.text('Spin & Win'), findsOneWidget);
        expect(find.text('Daily Spins'), findsOneWidget);
        expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
        expect(find.textContaining('SPIN WHEEL'), findsOneWidget);
      });
    }

    testWidgets('SpinScreen opens How to Play bottom sheet when (?) icon is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: SpinScreen(onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('How to Play Spin & Win'), findsOneWidget);
      expect(find.text('Daily Free Spins'), findsOneWidget);
      expect(find.text('Hit the Jackpot'), findsOneWidget);
      expect(find.text('Got It!'), findsOneWidget);

      await tester.tap(find.text('Got It!'));
      await tester.pumpAndSettle();

      expect(find.text('How to Play Spin & Win'), findsNothing);
    });
  });
}
