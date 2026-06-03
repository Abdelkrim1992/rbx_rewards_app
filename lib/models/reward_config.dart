/// Centralized reward values for the coin economy rebalancing.
/// Base rewards are reduced by 80% from original values.
/// Forced ad rewards match the original values.
/// Optional ad rewards are 5x the reduced base values.
class RewardConfig {
  // Daily Reward
  static const int dailyBase = 20;           // reduced from 100
  static const int dailyForced = 100;       // original
  static const int dailyOptional = 100;       // 5x base = 100

  // Chest
  static const int chestBase = 100;          // reduced from 500
  static const int chestForced = 500;       // original

  // Spin - forced ad maintains current spin rewards
  static const int spinForced = 50;         // min spin reward

  // Mini-games
  static const int miniGameBase = 40;       // reduced from 200
  static const int miniGameForced = 200;    // original
  static const int miniGameOptional = 200;   // 5x base = 200

  // Scratch cards - forced ad maintains current rewards
  static const int scratchMin = 150;
  static const int scratchMax = 350;

  // Daily earnings cap
  static const int dailyEarningsCap = 5000;

  // First redemption target
  static const int firstRedemptionTarget = 2500;
}
