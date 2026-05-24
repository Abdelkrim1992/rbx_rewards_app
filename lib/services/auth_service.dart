import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized auth service for anonymous sign-in and user state.
class AuthService {
  final SupabaseClient? _clientOverride;

  AuthService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient? get _client {
    try {
      return _clientOverride ?? Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  /// Ensure the user is signed in anonymously.
  Future<User?> signInAnonymously() async {
    final client = _client;
    if (client == null) return null;

    if (client.auth.currentUser != null) {
      return client.auth.currentUser;
    }

    try {
      final response = await client.auth.signInAnonymously();
      return response.user;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }
}
