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

  // --- Daily Scratch Card Limit ---
  static const String _keyScratchDate = 'scratch_date';
  static const String _keyScratchesRemaining = 'scratches_remaining';
  static const int maxScratchesPerDay = 10;

  static Future<int> getScratchesRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_keyScratchDate);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

    if (lastDateStr != todayStr) {
      // New day, reset the count
      await prefs.setString(_keyScratchDate, todayStr);
      await prefs.setInt(_keyScratchesRemaining, maxScratchesPerDay);
      return maxScratchesPerDay;
    }

    return prefs.getInt(_keyScratchesRemaining) ?? maxScratchesPerDay;
  }

  static Future<void> decrementScratchesRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = await getScratchesRemaining();
    if (remaining > 0) {
      await prefs.setInt(_keyScratchesRemaining, remaining - 1);
    }
  }

  // --- Game Play Count for Quick Reward Ad Throttling ---
  static const String _keyGamePlayCountPrefix = 'game_play_count_';

  static Future<int> getGamePlayCount(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyGamePlayCountPrefix$gameName') ?? 0;
  }

  static Future<void> incrementGamePlayCount(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getGamePlayCount(gameName);
    await prefs.setInt('$_keyGamePlayCountPrefix$gameName', current + 1);
  }

  // --- Daily Extra Spins Limit (Ad-funded spins) ---
  static const String _keyExtraSpinsDate = 'extra_spins_date';
  static const String _keyExtraSpinsRemaining = 'extra_spins_remaining';
  static const int maxExtraSpinsPerDay = 8;

  static Future<int> getExtraSpinsRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_keyExtraSpinsDate);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

    if (lastDateStr != todayStr) {
      // New day, reset the count
      await prefs.setString(_keyExtraSpinsDate, todayStr);
      await prefs.setInt(_keyExtraSpinsRemaining, maxExtraSpinsPerDay);
      return maxExtraSpinsPerDay;
    }

    return prefs.getInt(_keyExtraSpinsRemaining) ?? maxExtraSpinsPerDay;
  }

  static Future<void> decrementExtraSpinsRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = await getExtraSpinsRemaining();
    if (remaining > 0) {
      await prefs.setInt(_keyExtraSpinsRemaining, remaining - 1);
    }
  }

  // --- Game High / Best Scores ---
  static const String _keyBestScorePrefix = 'best_score_';

  static Future<int> getBestScore(String gameKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyBestScorePrefix$gameKey') ?? 0;
  }

  static Future<void> saveBestScore(String gameKey, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('$_keyBestScorePrefix$gameKey') ?? 0;
    if (score > current) {
      await prefs.setInt('$_keyBestScorePrefix$gameKey', score);
    }
  }

  static Future<int> getFlappyBestScore() => getBestScore('flappy_jump');
  static Future<void> saveFlappyBestScore(int score) => saveBestScore('flappy_jump', score);
}
