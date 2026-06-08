import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
void main() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  final client = Supabase.instance.client;
  // sign in anonymously to create a new user and test it
  await client.auth.signInAnonymously();
  final uid = client.auth.currentUser!.id;
  
  // Call add-game-coins
  print('--- CALLING add-game-coins ---');
  final gameRes = await client.functions.invoke('add-game-coins', body: {
    'amount': 15,
    'gameName': 'tap_tap',
    'sessionId': 'test_session_123',
    'durationSeconds': 10
  });
  print(gameRes.data);

  final res = await client.functions.invoke('get-user-stats');
  print('--- GET USER STATS ---');
  print(res.data);
  exit(0);
}
