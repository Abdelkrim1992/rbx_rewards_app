import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase connection test', () async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    expect(url.isNotEmpty, isTrue,
        reason:
            'SUPABASE_URL not provided — pass --dart-define=SUPABASE_URL=...');
    expect(anonKey.isNotEmpty, isTrue,
        reason:
            'SUPABASE_ANON_KEY not provided — pass --dart-define=SUPABASE_ANON_KEY=...');

    // Initialize Supabase with in-memory storage (avoids shared_preferences in tests)
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );

    final client = Supabase.instance.client;

    // Test 1: Check auth is reachable (anonymous sign-in)
    final authResponse = await client.auth.signInAnonymously();
    expect(authResponse.user, isNotNull,
        reason: 'Anonymous sign-in failed — check URL/key');

    // Test 2: Try a simple query to verify DB access
    final userId = authResponse.user!.id;
    final profile =
        await client.from('users').select().eq('id', userId).maybeSingle();

    print('User ID: $userId');
    print('Profile: $profile');
    print('Supabase connection successful!');

    // Cleanup
    await client.auth.signOut();
  });
}
