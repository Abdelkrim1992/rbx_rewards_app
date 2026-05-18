// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rbx_rewards_app/main.dart';

void main() {
  testWidgets('App onboarding and navigator smoke test',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RbxRewardsApp());

    // Verify that onboarding screen is displayed with the 'Get Started' button.
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Play Games'), findsOneWidget);

    // Tap the 'Get Started' button and trigger a frame.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify that we navigated to the home screen dashboard or another screen.
    expect(find.text('Get Started'), findsNothing);
  });
}
