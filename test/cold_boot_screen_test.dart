import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbx_rewards/presentation/screens/loading_screen.dart';
import 'package:rbx_rewards/widgets/circular_gradient_spinner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Boot & LoadingScreen Tests', () {
    testWidgets('LoadingScreen renders logo, CircularGradientSpinner, and Loading... text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingScreen(),
        ),
      );

      // Verify the loading indicator and text are visible
      expect(find.byType(CircularGradientSpinner), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);

      // Verify logo image is rendered
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('LoadingScreen invokes onBootstrap and onReady in cold boot flow',
        (WidgetTester tester) async {
      bool bootstrapCalled = false;
      bool readyCalled = false;
      ProviderContainer? readyContainer;

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
              readyContainer = container;
            },
          ),
        ),
      );

      // Allow post frame callbacks to run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bootstrapCalled, isTrue);
      expect(readyCalled, isTrue);
      expect(readyContainer, equals(testContainer));
    });

    testWidgets('CircularGradientSpinner animates without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularGradientSpinner(
              size: 48,
              label: 'Loading...',
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      // Advance frames to verify animation ticks smoothly
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularGradientSpinner), findsOneWidget);
    });
  });
}
