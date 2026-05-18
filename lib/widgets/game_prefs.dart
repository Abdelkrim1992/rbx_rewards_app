import 'package:shared_preferences/shared_preferences.dart';

class GamePrefs {
  static const String _keyCoins = 'rbx_coins_balance';
  static const String _keyFlappyHighScore = 'flappy_jump_high_score';
  static const String _keyFlappyTotalPlayed = 'flappy_jump_total_played';
  static const String _keyTapTapHighScore = 'tap_tap_high_score';
  static const String _keyMegaChestClaimed = 'mega_chest_claimed';

  // Load coins balance. Defaults to 525 (the initial app balance).
  static Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCoins) ?? 525;
  }

  // Save coins balance
  static Future<void> saveCoins(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCoins, value);
  }

  static Future<int> addCoins(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final total = (prefs.getInt(_keyCoins) ?? 525) + value;
    await prefs.setInt(_keyCoins, total);
    return total;
  }

  static Future<bool> isMegaChestClaimed() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(_keyMegaChestClaimed);
    return value == true;
  }

  static Future<void> setMegaChestClaimed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMegaChestClaimed, value);
  }

  // Load Flappy Jump high score
  static Future<int> getFlappyHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFlappyHighScore) ?? 0;
  }

  // Save Flappy Jump high score
  static Future<void> saveFlappyHighScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getFlappyHighScore();
    if (value > current) {
      await prefs.setInt(_keyFlappyHighScore, value);
    }
  }

  // Increment total Flappy Jump plays
  static Future<int> incrementFlappyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final played = (prefs.getInt(_keyFlappyTotalPlayed) ?? 0) + 1;
    await prefs.setInt(_keyFlappyTotalPlayed, played);
    return played;
  }

  static Future<int> getFlappyTotalPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFlappyTotalPlayed) ?? 0;
  }

  static const String _keyMathQuizHighScore = 'math_quiz_high_score';
  static const String _keyMathQuizTotalPlayed = 'math_quiz_total_played';

  // Load Math Quiz high score
  static Future<int> getMathQuizHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMathQuizHighScore) ?? 0;
  }

  // Save Math Quiz high score
  static Future<void> saveMathQuizHighScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getMathQuizHighScore();
    if (value > current) {
      await prefs.setInt(_keyMathQuizHighScore, value);
    }
  }

  // Increment total Math Quiz plays
  static Future<int> incrementMathQuizPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final played = (prefs.getInt(_keyMathQuizTotalPlayed) ?? 0) + 1;
    await prefs.setInt(_keyMathQuizTotalPlayed, played);
    return played;
  }

  static Future<int> getMathQuizTotalPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMathQuizTotalPlayed) ?? 0;
  }

  static const String _keyFlipCardHighScore = 'flip_card_high_score';
  static const String _keyFlipCardTotalPlayed = 'flip_card_total_played';

  // Load Flip Card high score
  static Future<int> getFlipCardHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFlipCardHighScore) ?? 0;
  }

  // Save Flip Card high score
  static Future<void> saveFlipCardHighScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getFlipCardHighScore();
    if (value > current) {
      await prefs.setInt(_keyFlipCardHighScore, value);
    }
  }

  // Increment total Flip Card plays
  static Future<int> incrementFlipCardPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final played = (prefs.getInt(_keyFlipCardTotalPlayed) ?? 0) + 1;
    await prefs.setInt(_keyFlipCardTotalPlayed, played);
    return played;
  }

  static Future<int> getFlipCardTotalPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFlipCardTotalPlayed) ?? 0;
  }

  static const String _keyChestUnlockTime = 'chest_unlock_time';

  // Returns the seconds remaining until the chest can be opened. 0 if it can be opened now.
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
}
