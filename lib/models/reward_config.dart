/// Centralized reward values for the Phase-6 coin economy.
///
/// Features are divided into two clear categories:
/// 1. Fixed Features (Chest, Scratch, Spin, Daily Streak, Watch Video) with Base x3/4 model.
/// 2. Unlimited Mini-Games (Flappy Jump, Tap Tap, Flip Cards, Math Quiz, Trivia) with
///    dynamic action-based calculations and x4 premium ad multiplier.
class RewardConfig {
  // ---------------------------------------------------------------------------
  // Daily Streak Escalating Progression (Days 1 to 7)
  // ---------------------------------------------------------------------------
  static const List<int> dailyStreakBaseRewards = [10, 15, 20, 25, 30, 40, 75];
  static const List<int> dailyStreakPremiumRewards = [30, 45, 60, 75, 90, 120, 225];

  static int getDailyStreakBaseReward(int day) {
    if (day < 1) return dailyStreakBaseRewards.first;
    final index = (day - 1) % 7;
    return dailyStreakBaseRewards[index];
  }

  static int getDailyStreakPremiumReward(int day) {
    if (day < 1) return dailyStreakPremiumRewards.first;
    final index = (day - 1) % 7;
    return dailyStreakPremiumRewards[index];
  }

  // ---------------------------------------------------------------------------
  // Fixed Features (Base x3 / x4)
  // ---------------------------------------------------------------------------
  // Mystery Chest (Cooldown 3h)
  static const int chestMinBase = 10;
  static const int chestMaxBase = 15;
  static const int chestBase = 12; // Average default
  static const int chestPremium = 60; // 15 x 4
  static const int chestMultiplier = 4;

  // Scratch Cards (Limited daily tickets)
  static const int scratchMinBase = 6;
  static const int scratchMaxBase = 12;
  static const int scratchBase = 9; // Average default
  static const int scratchPremium = 48; // 12 x 4
  static const int scratchMultiplier = 4;

  // Spin & Win Wheel
  static const List<int> spinWheelBaseSlices = [2, 4, 6, 8, 10, 12];
  static const int spinJackpotBase = 12;
  static const int spinBase = 6;
  static const int spinPremium = 48; // 12 x 4
  static const int spinMultiplier = 4;

  // Watch Video Ad
  static const int watchVideoBase = 8;
  static const int watchVideoPremium = 25;
  static const int watchVideoMultiplier = 3;

  // Milestone Mega Chest (Unlocked every 10,000 coins earned)
  static const int megaChestBase = 250;
  static const int megaChestPremium = 500; // 2x double
  static const int megaChestReward = 250;

  // ---------------------------------------------------------------------------
  // Mini-Games Action-Based Parameters (4x Model)
  // ---------------------------------------------------------------------------
  static const int miniGameMaxBaseReward = 12;
  static const int miniGameMultiplier = 4;
  static const int miniGameMaxPremiumReward = 48; // 12 x 4 = 48 max

  /// Math Quiz & Trivia reward calculation
  static int calculateMathQuizBaseReward(int correctCount, int totalQuestions) {
    if (totalQuestions <= 0) return 0;
    final ratio = correctCount / totalQuestions;
    if (ratio < 0.4) return 0; // Fail threshold (< 40% correct)
    if (ratio < 0.6) return 3; // Bronze (40% - 59%)
    if (ratio < 1.0) return 7; // Silver (60% - 99%)
    return miniGameMaxBaseReward; // 12 coins Gold (100% perfect)
  }

  /// Flappy Jump reward calculation
  static int calculateFlappyBaseReward(int score) {
    if (score < 3) return 0; // Fail / early crash
    if (score < 10) return 3; // Bronze (3-9 score)
    if (score < 25) return 7; // Silver (10-24 score)
    return miniGameMaxBaseReward; // 12 coins Gold (25+ score)
  }

  /// Tap Tap Reflex reward calculation
  static int calculateTapTapBaseReward(int score, int maxCombo) {
    if (score < 30) return 0; // Anti-AFK Fail (< 30 taps)
    if (score < 71) return 3; // Bronze (30-70 taps)
    if (score < 141) return 7; // Silver (71-140 taps)
    return miniGameMaxBaseReward; // 12 coins Gold (141+ taps)
  }

  /// Flip Card Memory match reward calculation
  static int calculateFlipCardBaseReward({
    required int matchesFound,
    required int timeLeftSeconds,
    int totalPairs = 6,
  }) {
    if (matchesFound < 2) return 0; // Fail (< 2 pairs)
    if (matchesFound < totalPairs) return 4; // Bronze (2-5 pairs matched)
    if (timeLeftSeconds < 15) return 8; // Silver (Cleared with < 15s left)
    return miniGameMaxBaseReward; // 12 coins Gold (Speed clear with >= 15s left)
  }
}
