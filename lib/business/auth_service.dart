import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../data/secure_repository.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  final SecureRepository _secure;

  // Salt to prevent password guessing based on device ID alone
  static const String _authSalt = 'rbx_rewards_salt_v1';

  AuthService({required SecureRepository secure}) : _secure = secure;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Signs in the user using a deterministic pseudo-email and password based on their
  /// hardware device ID. This ensures the user keeps the same account even if they
  /// uninstall and reinstall the app.
  Future<User?> signInWithDevice() async {
    // If we're already logged in, just return the user
    if (_client.auth.currentUser != null) {
      return _client.auth.currentUser;
    }

    try {
      // 1. Get unique hardware ID using device_info_plus
      String? deviceId;
      final deviceInfo = DeviceInfoPlugin();
      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id; // Usually a unique board/hardware ID
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor;
        }
      } catch (e) {
        debugPrint('Could not get device info: $e');
      }
      deviceId ??= 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Generate a deterministic pseudo-email
      final email = 'device_${_hashString(deviceId).substring(0, 20)}@rbxrewards.local';

      // 3. Generate a secure, deterministic password
      final password = _hashString(deviceId + _authSalt);

      // 4. Try to sign in first
      try {
        final response = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        debugPrint('✅ Logged in successfully with Device ID');
        return response.user;
      } on AuthException catch (e) {
        // 5. If invalid credentials (doesn't exist), sign up!
        if (e.message.contains('Invalid login credentials')) {
          debugPrint('ℹ️ Device account not found. Creating a new one...');
          final signUpResponse = await _client.auth.signUp(
            email: email,
            password: password,
          );
          
          // Clear any stale local data since this is a brand new account
          await _secure.clearAll();
          
          // Fail-safe: Ensure the users row is created in case the DB trigger missed it
          if (signUpResponse.user != null) {
            try {
              await _client.from('users').upsert({'id': signUpResponse.user!.id});
            } catch (e) {
              debugPrint('Fail-safe users insert error: $e');
            }
          }
          
          debugPrint('✅ Signed up new user with Device ID');
          return signUpResponse.user;
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Device sign-in failed: $e');
      rethrow;
    }
  }

  /// Helper to hash a string cleanly
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
