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
  static const int chestBase = 15;
  static const int chestPremium = 60; // x4
  static const int chestMultiplier = 4;

  static const int scratchBase = 12;
  static const int scratchPremium = 48; // x4
  static const int scratchMultiplier = 4;

  static const int spinBase = 10;
  static const int spinPremium = 40; // x4
  static const int spinMultiplier = 4;

  static const int watchVideoBase = 8;
  static const int watchVideoPremium = 25; // x3
  static const int watchVideoMultiplier = 3;

  static const int megaChestReward = 250;

  // ---------------------------------------------------------------------------
  // Mini-Games Action-Based Parameters
  // ---------------------------------------------------------------------------
  static const int miniGameMaxBaseReward = 15;
  static const int miniGameMultiplier = 4;
  static const int miniGameMaxPremiumReward = 60; // 15 x 4
}
