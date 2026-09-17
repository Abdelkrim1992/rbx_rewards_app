import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Captures a stable, hashed hardware device fingerprint to prevent
/// multi-account reward farming and invalid traffic abuse.
class DeviceFingerprint {
  static String? _cachedId;
  static const String _prefKey = 'app_device_fingerprint_v1';

  /// Returns a stable SHA-256 hashed hardware device ID.
  /// Persisted locally so that repeated calls on the same installation remain consistent.
  static Future<String> getDeviceId({DeviceInfoPlugin? pluginOverride}) async {
    if (_cachedId != null && _cachedId!.isNotEmpty) {
      return _cachedId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getString(_prefKey);
      if (persisted != null && persisted.isNotEmpty) {
        _cachedId = persisted;
        return persisted;
      }
    } catch (_) {
      // Best-effort cache read
    }

    final rawSeed = await _extractHardwareSeed(pluginOverride ?? DeviceInfoPlugin());
    final hashed = sha256.convert(utf8.encode('rbx_hw_$rawSeed')).toString();
    _cachedId = hashed;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, hashed);
    } catch (_) {
      // Best-effort cache write
    }

    return hashed;
  }

  static Future<String> _extractHardwareSeed(DeviceInfoPlugin deviceInfo) async {
    if (kIsWeb) {
      try {
        final info = await deviceInfo.webBrowserInfo;
        return 'web_${info.browserName.name}_${info.userAgent}_${info.platform}';
      } catch (_) {
        return 'web_unknown_${const Uuid().v4()}';
      }
    }

    if (Platform.isAndroid) {
      try {
        final info = await deviceInfo.androidInfo;
        return 'android_${info.id}_${info.brand}_${info.model}_${info.hardware}';
      } catch (_) {
        return 'android_fallback_${const Uuid().v4()}';
      }
    }

    if (Platform.isIOS) {
      try {
        final info = await deviceInfo.iosInfo;
        final vendorId = info.identifierForVendor ?? info.model;
        return 'ios_${info.name}_${info.model}_$vendorId';
      } catch (_) {
        return 'ios_fallback_${const Uuid().v4()}';
      }
    }

    if (Platform.isWindows) {
      try {
        final info = await deviceInfo.windowsInfo;
        return 'windows_${info.deviceId}_${info.computerName}';
      } catch (_) {
        return 'windows_fallback_${const Uuid().v4()}';
      }
    }

    if (Platform.isMacOS) {
      try {
        final info = await deviceInfo.macOsInfo;
        return 'macos_${info.systemGUID ?? info.computerName}_${info.model}';
      } catch (_) {
        return 'macos_fallback_${const Uuid().v4()}';
      }
    }

    if (Platform.isLinux) {
      try {
        final info = await deviceInfo.linuxInfo;
        return 'linux_${info.machineId ?? info.name}';
      } catch (_) {
        return 'linux_fallback_${const Uuid().v4()}';
      }
    }

    return 'fallback_${const Uuid().v4()}';
  }

  @visibleForTesting
  static void setMockDeviceId(String? id) {
    _cachedId = id;
  }
}
