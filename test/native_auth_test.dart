import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rbx_rewards/business/auth_service.dart';
import 'package:rbx_rewards/data/secure_repository.dart';
import 'package:rbx_rewards/presentation/screens/settings_screen.dart';

class MockCanceledGoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signIn() async => null;
}

class MockFailingGoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signIn() async {
    throw Exception('Google Play Services connection error');
  }
}

class MockSignedOutGoogleSignIn extends Fake implements GoogleSignIn {
  bool didSignOut = false;

  @override
  Future<bool> isSignedIn() async => true;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    didSignOut = true;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Native Google Sign-In Tests', () {
    test('signInWithGoogle returns false when user dismisses/cancels native account picker', () async {
      final secure = SecureRepository();
      final mockGoogle = MockCanceledGoogleSignIn();
      final auth = AuthService(
        secure: secure,
        googleSignIn: mockGoogle,
      );

      final result = await auth.signInWithGoogle();
      expect(result, isFalse, reason: 'Dismissing native picker modal must return false without throwing');
    });

    test('signInWithGoogle rethrows unexpected errors', () async {
      final secure = SecureRepository();
      final mockGoogle = MockFailingGoogleSignIn();
      final auth = AuthService(
        secure: secure,
        googleSignIn: mockGoogle,
      );

      expect(
        () => auth.signInWithGoogle(),
        throwsA(isA<Exception>()),
      );
    });

    test('signOut also clears native Google sign-in session if active', () async {
      final secure = SecureRepository();
      final mockGoogle = MockSignedOutGoogleSignIn();
      final auth = AuthService(
        secure: secure,
        googleSignIn: mockGoogle,
      );

      // signOut calls GoogleSignIn.signOut() when user was signed in
      try {
        await auth.signOut();
      } catch (_) {
        // Supabase client might not be initialized in headless test
      }
      expect(mockGoogle.didSignOut, isTrue);
    });
  });

  group('Settings Screen Auth Configuration Tests', () {
    testWidgets('Settings screen does not show sign-in links and provides Logout option',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Verify sign in / link account options are NOT present
      expect(find.text('Cloud Save & Backup'), findsNothing);
      expect(find.text('Link Apple ID'), findsNothing);
      expect(find.text('Link Google Account'), findsNothing);

      // Verify Logout button is present
      final logoutFinder = find.textContaining('Logout');
      await tester.ensureVisible(logoutFinder);
      await tester.pumpAndSettle();
      expect(logoutFinder, findsOneWidget);
    });
  });
}
