import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences for app settings only.
/// All game/coin state is now managed server-side via Supabase.
class GamePrefs {
  static const String _keyChestUnlockTime = 'chest_unlock_time';

  /// Returns the seconds remaining until the chest can be opened. 0 if it can be opened now.
  static Future<int> getChestSecondsRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockTimeString = prefs.getString(_keyChestUnlockTime);
    if (unlockTimeString == null) return 0;

    final unlockTime = DateTime.parse(unlockTimeString);
    final now = DateTime.now();
    if (unlockTime.isBefore(now)) {
      return 0;
    }
    return unlockTime.difference(now).inSeconds;
  }

  static Future<void> setChestUnlockTime(int durationSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    final unlockTime = DateTime.now().add(Duration(seconds: durationSeconds));
    await prefs.setString(_keyChestUnlockTime, unlockTime.toIso8601String());
  }

  // --- Local coin balance fallback (when Supabase is offline) ---
  static const String _keyLocalCoins = 'local_coins_balance';

  static Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLocalCoins) ?? 0;
  }

  static Future<void> saveCoins(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLocalCoins, value);
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
