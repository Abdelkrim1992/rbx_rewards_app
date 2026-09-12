import 'dart:convert';
import 'dart:math';
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
        if (!kIsWeb && Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id; // Usually a unique board/hardware ID
        } else if (!kIsWeb && Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor;
        } else if (kIsWeb) {
          final webInfo = await deviceInfo.webBrowserInfo;
          deviceId = webInfo.userAgent;
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
          
          final randomNum = Random().nextInt(9000000) + 1000000; // 7 digits
          final generatedUsername = 'player$randomNum';
          
          final signUpResponse = await _client.auth.signUp(
            email: email,
            password: password,
            data: {'display_name': generatedUsername},
          );
          
          // Clear any stale local data since this is a brand new account
          await _secure.clearAll();
          
          // Fail-safe: Ensure the users row is created in case the DB trigger missed it
          if (signUpResponse.user != null) {
            try {
              await _client.from('users').upsert({
                'id': signUpResponse.user!.id,
                'display_name': generatedUsername,
              });
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

  /// Returns true if the current user is logged in via temporary deterministic device auth
  bool get isDeviceAccount {
    final email = _client.auth.currentUser?.email;
    return email != null && email.endsWith('@rbxrewards.local');
  }

  /// Initiates Google OAuth Sign-In via Supabase
  Future<bool> signInWithGoogle() async {
    try {
      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.rbxrewards://login-callback/',
      );
      return result;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Links a Google ID to the current device user in Supabase
  Future<bool> linkGoogleAccount({
    required String googleId,
    required String email,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    try {
      await _client.from('users').update({
        'google_id': googleId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('linkGoogleAccount error: $e');
      return false;
    }
  }

  /// Retrieves linked account details from Supabase
  Future<Map<String, dynamic>?> getLinkedAccountInfo() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('users')
          .select('google_id, display_name, balance')
          .eq('id', user.id)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('getLinkedAccountInfo error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
