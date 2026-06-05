import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences for app settings only.
/// All game/coin state is now managed server-side via Supabase.
class GamePrefs {
  static const _secureStorage = FlutterSecureStorage();
  static const String _keyChestUnlockTime = 'chest_unlock_time';

  /// Returns the seconds remaining until the chest can be opened. 0 if it can be opened now.
  static Future<int> getChestSecondsRemaining() async {
    final unlockTimeString = await _secureStorage.read(key: _keyChestUnlockTime);
    if (unlockTimeString == null) return 0;

    final unlockTime = DateTime.parse(unlockTimeString);
    final now = DateTime.now();
    if (unlockTime.isBefore(now)) {
      return 0;
    }
    return unlockTime.difference(now).inSeconds;
  }

  static Future<void> setChestUnlockTime(int durationSeconds) async {
    final unlockTime = DateTime.now().add(Duration(seconds: durationSeconds));
    await _secureStorage.write(key: _keyChestUnlockTime, value: unlockTime.toIso8601String());
  }

  // --- Local coin balance fallback (when Supabase is offline) ---
  static const String _keyLocalCoins = 'local_coins_balance';

  static Future<int> getCoins() async {
    final valueStr = await _secureStorage.read(key: _keyLocalCoins);
    if (valueStr == null) return 0;
    return int.tryParse(valueStr) ?? 0;
  }

  static Future<void> saveCoins(int value) async {
    await _secureStorage.write(key: _keyLocalCoins, value: value.toString());
  }

  static Future<void> addCoins(int value) async {
    final current = await getCoins();
    await saveCoins(current + value);
  }

  // --- Local profile photo URL fallback ---
  static const String _keyProfilePhotoUrl = 'profile_photo_url';

  static Future<String?> getProfilePhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfilePhotoUrl);
  }

  static Future<void> saveProfilePhotoUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_keyProfilePhotoUrl);
    } else {
      await prefs.setString(_keyProfilePhotoUrl, url);
    }
  }
}
