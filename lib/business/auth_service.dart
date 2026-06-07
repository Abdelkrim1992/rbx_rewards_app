import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/secure_repository.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  final SecureRepository _secure;

  static const String _keyAppInstallId = 'app_install_id';

  AuthService({required SecureRepository secure}) : _secure = secure;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> checkFreshInstall() async {
    final prefs = await SharedPreferences.getInstance();
    final installId = prefs.getString(_keyAppInstallId);
    if (installId == null) {
      debugPrint('🔄 Fresh install detected – clearing Keychain data.');
      try {
        await signOut();
      } catch (_) {}
      await _secure.clearAll();
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_keyAppInstallId, newId);
    }
  }

  Future<User?> signInAnonymously() async {
    if (_client.auth.currentUser != null) {
      return _client.auth.currentUser;
    }
    try {
      final response = await _client.auth.signInAnonymously();
      return response.user;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
