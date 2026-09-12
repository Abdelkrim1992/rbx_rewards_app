import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Anti-cheat violation types
enum AntiCheatViolation {
  clockTampered,
  rateLimitExceeded,
  emulatorDetected,
  duplicateDeviceClaim,
  selfReferralAttempt,
}

/// Result of an anti-cheat validation
class AntiCheatResult {
  final bool isValid;
  final AntiCheatViolation? violation;
  final String message;

  const AntiCheatResult({
    required this.isValid,
    this.violation,
    required this.message,
  });

  static const AntiCheatResult valid = AntiCheatResult(
    isValid: true,
    message: 'Validation passed',
  );
}

/// Production-ready Security & Anti-Cheat Engine.
/// Protects against clock manipulation, multi-account farming, and bot scripts.
class AntiCheatService {
  final SupabaseClient? _supabase;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Action rate-limiting tracker: actionKey -> List of recent timestamps
  final Map<String, List<DateTime>> _actionHistory = {};

  // Device fingerprint cache
  String? _cachedDeviceFingerprint;

  // Last verified server time delta (Device Time - Server Time)
  Duration _serverTimeDelta = Duration.zero;
  bool _isServerTimeVerified = false;

  AntiCheatService([this._supabase]);

  /// Synchronize with remote server time to detect local clock tampering
  Future<void> syncServerTime() async {
    try {
      final client = _supabase ?? Supabase.instance.client;
      final start = DateTime.now();
      // Fast lightweight ping to Supabase to fetch server timestamp
      final response = await client
          .from('users')
          .select('created_at')
          .limit(1)
          .maybeSingle();

      if (response != null && response['created_at'] != null) {
        final latency = DateTime.now().difference(start) ~/ 2;
        final serverTime = DateTime.parse(response['created_at'] as String).toUtc();
        final localUtc = DateTime.now().toUtc().subtract(latency);
        _serverTimeDelta = localUtc.difference(serverTime);
        _isServerTimeVerified = true;
      }
    } catch (e) {
      debugPrint('AntiCheatService: Server time sync fallback: $e');
    }
  }

  /// Verify local device clock has not been manually altered into the future/past
  AntiCheatResult validateDeviceClock() {
    if (!_isServerTimeVerified) {
      return AntiCheatResult.valid;
    }

    // Allow up to 5 minutes of legitimate NTP drift
    const maxDriftTolerance = Duration(minutes: 5);
    if (_serverTimeDelta.abs() > maxDriftTolerance) {
      return const AntiCheatResult(
        isValid: false,
        violation: AntiCheatViolation.clockTampered,
        message: 'System clock discrepancy detected. Please verify your device date & time.',
      );
    }
    return AntiCheatResult.valid;
  }

  /// Token-bucket action rate limiter (prevents rapid-fire bot scripts)
  AntiCheatResult validateActionFrequency(
    String actionKey, {
    int maxAllowedInWindow = 5,
    Duration window = const Duration(seconds: 1),
  }) {
    final now = DateTime.now();
    final timestamps = _actionHistory.putIfAbsent(actionKey, () => []);

    // Evict timestamps outside current window
    timestamps.removeWhere((t) => now.difference(t) > window);

    if (timestamps.length >= maxAllowedInWindow) {
      return const AntiCheatResult(
        isValid: false,
        violation: AntiCheatViolation.rateLimitExceeded,
        message: 'Actions too fast. Please slow down.',
      );
    }

    timestamps.add(now);
    return AntiCheatResult.valid;
  }

  /// Generates a privacy-preserving, deterministic SHA-256 device fingerprint
  Future<String> getDeviceFingerprint() async {
    if (_cachedDeviceFingerprint != null) {
      return _cachedDeviceFingerprint!;
    }

    String rawSeed = 'generic_device_seed';
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        rawSeed = '${info.brand}_${info.model}_${info.hardware}_${info.id}';
      } else if (!kIsWeb && Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        rawSeed = '${info.name}_${info.model}_${info.identifierForVendor}';
      } else if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        rawSeed = '${info.browserName.name}_${info.userAgent}_${info.platform}';
      } else {
        rawSeed = 'desktop_platform_device';
      }
    } catch (e) {
      debugPrint('AntiCheatService: Device info error: $e');
    }

    // SHA-256 hash ensures one-way cryptographic binding
    final bytes = utf8.encode('rbx_device_$rawSeed');
    _cachedDeviceFingerprint = sha256.convert(bytes).toString();
    return _cachedDeviceFingerprint!;
  }

  /// Verify if the device is a physical hardware device (non-emulator)
  Future<bool> isPhysicalDevice() async {
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return info.isPhysicalDevice;
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.isPhysicalDevice;
      }
    } catch (_) {}
    return true;
  }
}
