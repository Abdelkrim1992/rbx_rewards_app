import 'package:shared_preferences/shared_preferences.dart';

class GamePrefs {
  static const String _keyCoins = 'rbx_coins_balance';
  static const String _keyFlappyHighScore = 'flappy_jump_high_score';
  static const String _keyFlappyTotalPlayed = 'flappy_jump_total_played';
  static const String _keyTapTapHighScore = 'tap_tap_high_score';

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
}
