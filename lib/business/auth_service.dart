import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../data/secure_repository.dart';

class AuthService {
  SupabaseClient get _client => _customClient ?? Supabase.instance.client;
  final SupabaseClient? _customClient;
  final SecureRepository _secure;
  final GoogleSignIn? _googleSignIn;

  // Salt to prevent password guessing based on device ID alone
  static const String _authSalt = 'rbx_rewards_salt_v1';

  // Google OAuth Client IDs (can be configured via --dart-define)
  static const String _googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String _googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  AuthService({
    required SecureRepository secure,
    SupabaseClient? client,
    GoogleSignIn? googleSignIn,
  })  : _secure = secure,
        _customClient = client,
        _googleSignIn = googleSignIn;

  bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<AuthState> get authStateChanges {
    try {
      return _client.auth.onAuthStateChange;
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Signs in the user using a deterministic pseudo-email and password based on their
  /// hardware device ID. This ensures the user keeps the same account even if they
  /// uninstall and reinstall the app.
  Future<User?> signInWithDevice() async {
    if (!isInitialized) {
      debugPrint('ℹ️ Supabase not initialized, skipping device sign-in.');
      return null;
    }

    try {
      // If we're already logged in, just return the user
      if (currentUser != null) {
        return currentUser;
      }
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

      // 2. Read account version sequence (increments when user permanently deletes account)
      final prefs = await SharedPreferences.getInstance();
      final accountVersion = prefs.getInt('device_account_version') ?? 0;
      final versionSuffix = accountVersion > 0 ? '_v$accountVersion' : '';

      // 3. Generate a deterministic pseudo-email
      final email = 'device_${_hashString(deviceId + versionSuffix).substring(0, 20)}@rbxrewards.local';

      // 4. Generate a secure, deterministic password
      final password = _hashString(deviceId + versionSuffix + _authSalt);

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

  /// Returns true if the current user is a guest or temporary device account
  bool get isDeviceAccount {
    try {
      final user = currentUser;
      if (user == null) return true;
      final email = user.email;
      return email == null || email.endsWith('@rbxrewards.local');
    } catch (_) {
      return true;
    }
  }

  /// Returns true if the user is authenticated via an external social provider (Google or Apple)
  bool get isSocialAccount {
    try {
      final user = currentUser;
      if (user == null) return false;
      final email = user.email;
      return email != null && !email.endsWith('@rbxrewards.local');
    } catch (_) {
      return false;
    }
  }

  /// Initiates native Google Sign-In (in-app modal bottom sheet account chooser).
  /// Prompts the system Google Account picker modal without redirecting to a browser or website.
  Future<bool> signInWithGoogle() async {
    try {
      final webClientId = _googleWebClientId.trim();
      final iosClientId = _googleIosClientId.trim();
      debugPrint('ℹ️ Google Sign-In serverClientId: ${webClientId.isNotEmpty ? webClientId : "(none)"}');

      final googleSignIn = _googleSignIn ??
          GoogleSignIn(
            serverClientId: webClientId.isNotEmpty ? webClientId : null,
            clientId: iosClientId.isNotEmpty ? iosClientId : null,
            scopes: const ['email', 'profile'],
          );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User closed/dismissed the native account picker
        debugPrint('ℹ️ Google Sign-In modal dismissed by user');
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthException(
          'No Google ID token was returned. Ensure GOOGLE_WEB_CLIENT_ID matches your Google Cloud Web Client ID.',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        await _ensurePublicUserRow(
          response.user!,
          emailOverride: googleUser.email,
          nameOverride: googleUser.displayName,
        );
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('Native Google Sign-In PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'sign_in_failed' || (e.message != null && e.message!.contains('10'))) {
        throw Exception(
          'Google Sign-In configuration error: The SHA-1 certificate or Web Client ID is not registered in Google Cloud Console.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('Native Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Initiates native Apple Sign-In (iOS native modal bottom sheet with Face ID / Touch ID).
  /// Prompts the system Apple ID dialog without redirecting to a browser or website.
  Future<bool> signInWithApple() async {
    try {
      final rawNonce = _client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('No Apple ID token was returned.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.user != null) {
        String? appleName;
        if (credential.givenName != null || credential.familyName != null) {
          final parts = [credential.givenName, credential.familyName]
              .where((s) => s != null && s.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) {
            appleName = parts.join(' ');
          }
        }
        await _ensurePublicUserRow(
          response.user!,
          emailOverride: credential.email,
          nameOverride: appleName,
        );
        return true;
      }
      return false;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('ℹ️ Apple Sign-In dismissed by user');
        return false;
      }
      debugPrint('Native Apple Sign-In authorization error: $e');
      rethrow;
    } catch (e) {
      debugPrint('Native Apple Sign-In error: $e');
      rethrow;
    }
  }

  /// Fail-safe to ensure a public.users row exists for social auth users, saving their verified email
  Future<void> _ensurePublicUserRow(
    User user, {
    String? emailOverride,
    String? nameOverride,
  }) async {
    try {
      final email = (emailOverride != null && emailOverride.isNotEmpty)
          ? emailOverride
          : user.email;
      final displayName = nameOverride ??
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          email?.split('@').first ??
          'Player${Random().nextInt(900000) + 100000}';

      final Map<String, dynamic> rowData = {
        'id': user.id,
        'display_name': displayName,
      };
      if (email != null && email.isNotEmpty) {
        rowData['email'] = email;
      }

      await _client.from('users').upsert(rowData, onConflict: 'id');
      debugPrint('✅ Verified public.users row exists for user ${user.id} (email: $email)');
    } catch (e) {
      debugPrint('Fail-safe public.users upsert notice: $e');
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

  /// Links an Apple ID to the current device user in Supabase
  Future<bool> linkAppleAccount({
    required String appleId,
    required String email,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    try {
      await _client.from('users').update({
        'apple_id': appleId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('linkAppleAccount error: $e');
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

  /// Completely and permanently deletes the user account in compliance with Apple Guideline 5.1.1(v).
  /// Erases remote user records, wipes local secure storage, purges caches,
  /// and advances account version so a fresh new account is created if restarted.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user != null) {
      final userId = user.id;
      bool serverPermanentlyDeleted = false;

      // 1. Primary: Server-side atomic RPC delete_user_account (erases public.users & auth.users)
      try {
        await _client.rpc('delete_user_account');
        serverPermanentlyDeleted = true;
        debugPrint('✅ Server-side permanent deletion via delete_user_account RPC succeeded');
      } catch (rpcError) {
        debugPrint('delete_user_account RPC notice: $rpcError');
      }

      // 2. Secondary: Edge Function delete-account using service_role admin API
      if (!serverPermanentlyDeleted) {
        try {
          final res = await _client.functions.invoke('delete-account');
          if (res.status == 200) {
            serverPermanentlyDeleted = true;
            debugPrint('✅ Server-side permanent deletion via Edge Function succeeded');
          }
        } catch (efError) {
          debugPrint('delete-account Edge function notice: $efError');
        }
      }

      // 3. Fallback: Direct table-level hard DELETEs (NEVER soft-delete!)
      try {
        await _client.from('user_ad_stats').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _client.from('transactions').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _client.from('game_sessions').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _client.from('game_stats').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _client.from('redeemed_rewards').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _client.from('referrals').delete().or('referrer_id.eq.$userId,referee_id.eq.$userId');
      } catch (_) {}
      try {
        await _client.from('users').delete().eq('id', userId);
        debugPrint('✅ Direct public.users hard DELETE completed');
      } catch (delError) {
        debugPrint('Direct public.users delete notice: $delError');
      }
    }

    // 1. Sign out from Google if signed in
    try {
      final googleSignIn = _googleSignIn ?? GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign-out notice during deletion: $e');
    }

    // 2. Sign out from Supabase Auth
    if (isInitialized) {
      try {
        await _client.auth.signOut();
      } catch (e) {
        debugPrint('Sign out error during deletion: $e');
      }
    }

    // 3. Wipe local secure storage (AFTER signOut to avoid session re-write)
    try {
      await _secure.clearAll();
    } catch (e) {
      debugPrint('Secure storage clear notice: $e');
    }

    // 4. Wipe SharedPreferences and increment device_account_version for a fresh identity
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt('device_account_version') ?? 0;
      await prefs.clear();
      await prefs.setInt('device_account_version', currentVersion + 1);
    } catch (e) {
      debugPrint('SharedPreferences purge notice: $e');
    }

    // 5. Clear image cache
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }

  Future<void> signOut() async {
    try {
      final googleSignIn = _googleSignIn ?? GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign-out notice: $e');
    }
    if (isInitialized) {
      await _client.auth.signOut();
    }
  }
}
