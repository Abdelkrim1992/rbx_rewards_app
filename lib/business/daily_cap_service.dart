import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/supabase_repository.dart';

/// Tracks daily coin earnings and enforces in-app feature level daily caps.
/// Extends [ChangeNotifier] so any [ref.watch(dailyCapServiceProvider)]
/// automatically rebuilds UI when fresh database limits arrive.
class DailyCapService extends ChangeNotifier {
  final SupabaseRepository _repository;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  static const _secureStorage = FlutterSecureStorage();

  // Storage Keys
  static const String _earningsDateKey = 'earnings_date';
  static const String _featuresEarningsKey = 'daily_features_earnings';
  static const String _offerwallsEarningsKey = 'daily_offerwalls_earnings';

  static const String _dailyRewardEarningsKey = 'daily_reward_earnings';
  static const String _chestEarningsKey = 'daily_chest_earnings';
  static const String _spinEarningsKey = 'daily_spin_earnings';
  static const String _scratchEarningsKey = 'daily_scratch_earnings';
  static const String _quizEarningsKey = 'daily_quiz_earnings';
  static const String _gameMathQuizEarningsKey = 'daily_game_math_quiz_earnings';
  static const String _gameFlappyEarningsKey = 'daily_game_flappy_earnings';
  static const String _gameTapTapEarningsKey = 'daily_game_tap_tap_earnings';
  static const String _gameFlipCardEarningsKey = 'daily_game_flip_card_earnings';
  static const String _watchVideoEarningsKey = 'daily_watch_video_earnings';

  // Static Fallback Caps (defaults)
  static const int featuresCap = 1000;
  static const int offerwallsCap = 1000;

  static const int dailyRewardCap = 30;
  // Repeatable game / feature caps are governed by the 3-Tier Soft Cap (1,200 Tier-1).
  // These constants represent the Tier-1 soft target shown in the UI progress bar.
  static const int chestCap = 1200;
  static const int spinCap = 1200;
  static const int scratchCap = 1200;
  static const int quizCap = 1200;

  // Sub-game caps – all tied to Tier-1 (1,200 coins) soft cap.
  static const int gameMathQuizCap = 1200;
  static const int gameFlappyCap = 1200;
  static const int gameTapTapCap = 1200;
  static const int gameFlipCardCap = 1200;
  static const int watchVideoCap = 1200;

  // Dynamic Limits Map (pre-seeded with default static fallbacks)
  final Map<String, int> _limits = {
    'global_features': featuresCap,
    'global_offerwalls': offerwallsCap,
    'survey': offerwallsCap,
    'daily_reward': dailyRewardCap,
    'chest': chestCap,
    'spin': spinCap,
    'scratch': scratchCap,
    'quiz': quizCap,
    'math_quiz': gameMathQuizCap,
    'flappy_jump': gameFlappyCap,
    'tap_tap': gameTapTapCap,
    'flip_card': gameFlipCardCap,
    'ad': watchVideoCap,
    'watch_video': watchVideoCap,
    'video': watchVideoCap,
    'watch_earn': watchVideoCap,
    'mega_chest': 250,
    'mega_chest_double': 250,
  };

  /// Dynamic reward limits: (baseReward, premiumReward) per feature
  final Map<String, (int, int)> _rewardLimits = {};

  DailyCapService(this._repository);

  // Earnings
  int _todayFeaturesEarnings = 0;
  int _todayOfferwallsEarnings = 0;

  int _todayDailyRewardEarnings = 0;
  int _todayChestEarnings = 0;
  int _todaySpinEarnings = 0;
  int _todayScratchEarnings = 0;
  int _todayQuizEarnings = 0;
  int _todayGameMathQuizEarnings = 0;
  int _todayGameFlappyEarnings = 0;
  int _todayGameTapTapEarnings = 0;
  int _todayGameFlipCardEarnings = 0;
  int _todayWatchVideoEarnings = 0;

  String _currentDate = '';

  // Getters
  int get todayFeaturesEarnings => _todayFeaturesEarnings;
  int get todayOfferwallsEarnings => _todayOfferwallsEarnings;

  int get todayDailyRewardEarnings => _todayDailyRewardEarnings;
  int get todayChestEarnings => _todayChestEarnings;
  int get todaySpinEarnings => _todaySpinEarnings;
  int get todayScratchEarnings => _todayScratchEarnings;
  int get todayQuizEarnings => _todayQuizEarnings;
  int get todayGameMathQuizEarnings => _todayGameMathQuizEarnings;
  int get todayGameFlappyEarnings => _todayGameFlappyEarnings;
  int get todayGameTapTapEarnings => _todayGameTapTapEarnings;
  int get todayGameFlipCardEarnings => _todayGameFlipCardEarnings;
  int get todayWatchVideoEarnings => _todayWatchVideoEarnings;

  // Dynamic Caps getters (read from dynamic map)
  int get dynamicFeaturesCap => _limits['global_features'] ?? featuresCap;
  int get dynamicOfferwallsCap => _limits['global_offerwalls'] ?? offerwallsCap;

  /// 3-Tier Diminishing Yield Curve (Soft Cap) multiplier:
  /// - Tier 1 (0 – 1,200 coins earned today): 1.0x (100% full speed)
  /// - Tier 2 (1,201 – 2,200 coins earned today): 0.5x (50% normal speed)
  /// - Tier 3 (2,201+ coins earned today - Grinders): 0.15x (15% micro-rewards)
  double getYieldMultiplier() {
    if (_todayFeaturesEarnings <= 1200) {
      return 1.0;
    } else if (_todayFeaturesEarnings <= 2200) {
      return 0.5;
    } else {
      return 0.15;
    }
  }

  /// Calculates the yield-aware ad bonus coins for a given base reward.
  /// If [multiplier] is provided (e.g. 4 for mini-games/chest, 3 for streak/video),
  /// the ad bonus is calculated as (baseReward * (multiplier - 1)) scaled by the yield curve.
  /// Otherwise, scales [targetBonus] (default 25) by the yield curve:
  /// Tier 1 (0 – 1,200 coins): 100% yield
  /// Tier 2 (1,201 – 2,200 coins): 50% yield
  /// Tier 3 (2,201+ coins): 15% yield (minimum 1)
  int calculateAdBonusReward(
    int baseReward, {
    int targetBonus = 25,
    int? multiplier,
  }) {
    final yieldMult = getYieldMultiplier();
    if (multiplier != null && multiplier > 1) {
      final bonusTotal = baseReward * (multiplier - 1);
      final scaledBonus = (bonusTotal * yieldMult).round();
      return baseReward + (scaledBonus > 0 ? scaledBonus : 1);
    }
    final bonus = (targetBonus * yieldMult).round().clamp(4, targetBonus);
    return baseReward + bonus;
  }

  @visibleForTesting
  void setTodayFeaturesEarningsForTest(int earnings) {
    _todayFeaturesEarnings = earnings;
  }

  // Soft Cap Economy: Continuous gameplay without hard lockouts
  int get todayEarnings => _todayFeaturesEarnings + _todayOfferwallsEarnings;
  int get remainingToday => getRemainingCap('features');
  bool get isCapReached => false;

  int get remainingFeaturesToday => getRemainingCap('features');
  int get remainingOfferwallsToday => (dynamicOfferwallsCap - _todayOfferwallsEarnings).clamp(0, dynamicOfferwallsCap);

  bool get isFeaturesCapReached => false;
  bool get isOfferwallsCapReached => _todayOfferwallsEarnings >= dynamicOfferwallsCap;

  String _getTodayUtcString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _checkMidnightReset() {
    final today = _getTodayUtcString();
    if (_currentDate.isNotEmpty && _currentDate != today) {
      _resetEarnings();
      _currentDate = today;
      _persist();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Dynamic Reward Helpers
  // ---------------------------------------------------------------------------

  /// Normalize source aliases to the canonical key used in coin_distributions.
  String _normalizeSource(String source) {
    if (source == 'watch_earn' || source == 'watch_video' || source == 'video') {
      return 'ad';
    }
    if (source == 'quizzes') return 'quiz';
    return source;
  }

  /// Get the base (single-view) reward for a feature from the database.
  /// Falls back to [fallback] if not configured.
  int getBaseReward(String source, {int fallback = 10}) {
    final key = _normalizeSource(source);
    if (_rewardLimits.containsKey(key)) {
      return _rewardLimits[key]!.$1;
    }
    // Harmonized fallbacks according to Phase 6 economy
    switch (key) {
      case 'ad':
        return 8;
      case 'chest':
        return 15;
      case 'scratch':
        return 12;
      case 'spin':
        return 10;
      case 'quiz':
      case 'math_quiz':
      case 'flappy_jump':
      case 'flip_card':
        return 6;
      case 'tap_tap':
        return 5;
      case 'mega_chest':
      case 'mega_chest_double':
        return 250;
      case 'daily_reward':
        return 10;
      default:
        return fallback;
    }
  }

  /// Get the premium (doubled/ad-boosted) reward for a feature from the database.
  /// Falls back to [fallback] if not configured.
  int getPremiumReward(String source, {int fallback = 20}) {
    final key = _normalizeSource(source);
    if (_rewardLimits.containsKey(key)) {
      return _rewardLimits[key]!.$2;
    }
    switch (key) {
      case 'ad':
        return 25; // 8 x 3 ≈ 25
      case 'chest':
        return 60; // 15 x 4
      case 'scratch':
        return 48; // 12 x 4
      case 'spin':
        return 40; // 10 x 4
      case 'quiz':
      case 'math_quiz':
      case 'flappy_jump':
      case 'flip_card':
        return 60; // Up to 60 (15 max base x 4)
      case 'tap_tap':
        return 60; // Up to 60 (15 max base x 4)
      case 'mega_chest':
      case 'mega_chest_double':
        return 250;
      case 'daily_reward':
        return 30; // 10 x 3
      default:
        return fallback;
    }
  }

  /// Get the random reward range for a feature, defaults to hardcoded values if not in DB.
  (int min, int max) getRewardLimits(String source) {
    final key = _normalizeSource(source);
    if (_rewardLimits.containsKey(key)) {
      return _rewardLimits[key]!;
    }
    if (key == 'chest') return (12, 18);
    if (key == 'scratch') return (10, 14);
    if (key == 'mega_chest') return (250, 250);
    return (5, 10);
  }

  // ---------------------------------------------------------------------------
  // Load & Refresh
  // ---------------------------------------------------------------------------

  /// Load persisted daily earnings.
  Future<void> load() async {
    final storedDate = await _secureStorage.read(key: _earningsDateKey) ?? '';
    final today = _getTodayUtcString();

    if (storedDate == today) {
      final featuresStr = await _secureStorage.read(key: _featuresEarningsKey);
      final offerwallsStr = await _secureStorage.read(key: _offerwallsEarningsKey);
      _todayFeaturesEarnings = featuresStr != null ? (int.tryParse(featuresStr) ?? 0) : 0;
      _todayOfferwallsEarnings = offerwallsStr != null ? (int.tryParse(offerwallsStr) ?? 0) : 0;

      _todayDailyRewardEarnings = int.tryParse(await _secureStorage.read(key: _dailyRewardEarningsKey) ?? '0') ?? 0;
      _todayChestEarnings = int.tryParse(await _secureStorage.read(key: _chestEarningsKey) ?? '0') ?? 0;
      _todaySpinEarnings = int.tryParse(await _secureStorage.read(key: _spinEarningsKey) ?? '0') ?? 0;
      _todayScratchEarnings = int.tryParse(await _secureStorage.read(key: _scratchEarningsKey) ?? '0') ?? 0;
      _todayQuizEarnings = int.tryParse(await _secureStorage.read(key: _quizEarningsKey) ?? '0') ?? 0;

      _todayGameMathQuizEarnings = int.tryParse(await _secureStorage.read(key: _gameMathQuizEarningsKey) ?? '0') ?? 0;
      _todayGameFlappyEarnings = int.tryParse(await _secureStorage.read(key: _gameFlappyEarningsKey) ?? '0') ?? 0;
      _todayGameTapTapEarnings = int.tryParse(await _secureStorage.read(key: _gameTapTapEarningsKey) ?? '0') ?? 0;
      _todayGameFlipCardEarnings = int.tryParse(await _secureStorage.read(key: _gameFlipCardEarningsKey) ?? '0') ?? 0;
      _todayWatchVideoEarnings = int.tryParse(await _secureStorage.read(key: _watchVideoEarningsKey) ?? '0') ?? 0;
    } else {
      _resetEarnings();
    }
    _currentDate = today;

    // Load cached dynamic limits from secure storage if available.
    // Sanitize stale legacy caps (≤ 150) to 1200 for all repeatable features
    // so devices that cached the old 120 value are automatically corrected.
    final nonScaledKeys = const {'daily_reward', 'global_offerwalls', 'survey', 'mega_chest', 'mega_chest_double'};
    for (final key in _limits.keys) {
      try {
        final val = await _secureStorage.read(key: 'cap_limit_$key');
        if (val != null) {
          final parsed = int.tryParse(val);
          if (parsed != null) {
            final isStale = parsed <= 150 && !nonScaledKeys.contains(key);
            _limits[key] = isStale ? 1200 : parsed;
            if (isStale) {
              // Overwrite stale value in storage so next cold-start is clean.
              await _secureStorage.write(key: 'cap_limit_$key', value: '1200');
            }
          }
        }
      } catch (_) {}
    }

    try {
      final chestBase = await _secureStorage.read(key: 'reward_base_chest');
      final chestPremium = await _secureStorage.read(key: 'reward_premium_chest');
      if (chestBase != null && chestPremium != null) {
        _rewardLimits['chest'] = (int.parse(chestBase), int.parse(chestPremium));
      }
      final scratchBase = await _secureStorage.read(key: 'reward_base_scratch');
      final scratchPremium = await _secureStorage.read(key: 'reward_premium_scratch');
      if (scratchBase != null && scratchPremium != null) {
        _rewardLimits['scratch'] = (int.parse(scratchBase), int.parse(scratchPremium));
      }
      // Load any other cached reward limits
      for (final source in ['ad', 'spin', 'quiz', 'math_quiz', 'tap_tap', 'flappy_jump', 'flip_card', 'mega_chest', 'daily_reward']) {
        final base = await _secureStorage.read(key: 'reward_base_$source');
        final premium = await _secureStorage.read(key: 'reward_premium_$source');
        if (base != null && premium != null) {
          _rewardLimits[source] = (int.parse(base), int.parse(premium));
        }
      }
    } catch (_) {}

    // Notify widgets with cached values immediately
    notifyListeners();

    // Async background fetch fresh limits from database
    _fetchFreshLimits();
  }

  /// Force-refresh limits from the database. Call on pull-to-refresh.
  Future<void> refreshLimits() async {
    await _fetchFreshLimits();
  }

  Future<void> _fetchFreshLimits() async {
    try {
      final list = await _repository.getCoinDistributions();
      for (final item in list) {
        final id = item['id'] as String?;
        final cap = item['daily_cap'] as int?;
        final base = item['base_reward'] as int?;
        final premium = item['premium_reward'] as int?;

        if (id != null && cap != null) {
          // Sanitize stale legacy values from DB (≤ 150 for repeatable features → 1200)
          const nonScaledDb = {'daily_reward', 'global_offerwalls', 'survey', 'mega_chest', 'mega_chest_double'};
          final effectiveCap = (cap <= 150 && !nonScaledDb.contains(id)) ? 1200 : cap;
          _limits[id] = effectiveCap;
          // Also sync aliases for watch features
          if (id == 'ad') {
            _limits['watch_video'] = effectiveCap;
            _limits['video'] = effectiveCap;
            _limits['watch_earn'] = effectiveCap;
          }
          // Cache effective value in secure storage
          await _secureStorage.write(key: 'cap_limit_$id', value: effectiveCap.toString());
        }

        if (id != null && base != null && premium != null) {
          _rewardLimits[id] = (base, premium);
          // Sync aliases
          if (id == 'ad') {
            _rewardLimits['watch_video'] = (base, premium);
            _rewardLimits['watch_earn'] = (base, premium);
          }
          await _secureStorage.write(key: 'reward_base_$id', value: base.toString());
          await _secureStorage.write(key: 'reward_premium_$id', value: premium.toString());
        }
      }
      // Notify all listening widgets that fresh values have arrived
      notifyListeners();
    } catch (e) {
      debugPrint('DailyCapService: Failed to fetch fresh coin distributions from DB: $e');
    }
  }

  void _resetEarnings() {
    _todayFeaturesEarnings = 0;
    _todayOfferwallsEarnings = 0;
    _todayDailyRewardEarnings = 0;
    _todayChestEarnings = 0;
    _todaySpinEarnings = 0;
    _todayScratchEarnings = 0;
    _todayQuizEarnings = 0;
    _todayGameMathQuizEarnings = 0;
    _todayGameFlappyEarnings = 0;
    _todayGameTapTapEarnings = 0;
    _todayGameFlipCardEarnings = 0;
    _todayWatchVideoEarnings = 0;
  }

  /// Resets all in-memory daily earnings to 0. Used during account deletion or fresh reset.
  void resetAllEarnings() {
    _resetEarnings();
    _currentDate = _getTodayUtcString();
    notifyListeners();
  }

  /// Get the remaining cap for a specific feature source.
  /// Uses soft-tier remaining values for repeatable features/games,
  /// and hard daily limits for single-claim daily rewards & offerwalls.
  int getRemainingCap(String source) {
    _checkMidnightReset();

    if (source == 'survey') {
      final maxOfferwalls = _limits['global_offerwalls'] ?? offerwallsCap;
      return (maxOfferwalls - _todayOfferwallsEarnings).clamp(0, maxOfferwalls);
    }

    if (source == 'daily_reward') {
      final categoryCap = _limits['daily_reward'] ?? dailyRewardCap;
      return (categoryCap - _todayDailyRewardEarnings).clamp(0, categoryCap);
    }

    // Repeatable gameplay & ad features are governed by the soft-cap yield curve
    if (_todayFeaturesEarnings < 1200) {
      return 1200 - _todayFeaturesEarnings;
    } else if (_todayFeaturesEarnings < 2200) {
      return 2200 - _todayFeaturesEarnings;
    } else {
      // Grinder tier (uncapped gameplay at 0.15x)
      return 999;
    }
  }


  /// Get the total configured cap for a specific category or game.
  /// For repeatable games / features, returns the Tier-1 soft cap (1,200).
  /// For daily_reward / offerwalls, returns the specific hard daily limit.
  int getCategoryCap(String source) {
    final key = _normalizeSource(source);
    if (key == 'daily_reward') return _limits[key] ?? dailyRewardCap;
    if (key == 'survey' || key == 'global_offerwalls') return _limits[key] ?? offerwallsCap;
    // All repeatable game / feature keys: enforce minimum 1,200 (Tier-1 target)
    final stored = _limits[key] ?? 1200;
    return stored < 200 ? 1200 : stored;
  }

  /// Get total earned today for a specific game or feature
  int getEarnedToday(String source) {
    _checkMidnightReset();
    final today = _getTodayUtcString();
    if (_currentDate != today) return 0;

    if (source == 'daily_reward') return _todayDailyRewardEarnings;
    if (source == 'chest') return _todayChestEarnings;
    if (source == 'spin') return _todaySpinEarnings;
    if (source == 'scratch') return _todayScratchEarnings;
    if (source == 'quiz' || source == 'quizzes') return _todayQuizEarnings;
    if (source == 'math_quiz') return _todayGameMathQuizEarnings;
    if (source == 'flappy_jump') return _todayGameFlappyEarnings;
    if (source == 'tap_tap') return _todayGameTapTapEarnings;
    if (source == 'flip_card') return _todayGameFlipCardEarnings;
    if (source == 'ad' || source == 'watch_video' || source == 'video' || source == 'watch_earn') return _todayWatchVideoEarnings;
    return 0;
  }

  bool isCapReachedFor(String source) {
    if (source == 'daily_reward' || source == 'survey') {
      return getRemainingCap(source) <= 0;
    }
    return false;
  }

  /// Try to add coins. Applies diminishing yield multiplier for repeatable features.
  /// Returns the amount actually added.
  int addCoins(int amount, String source) {
    _checkMidnightReset();
    if (_currentDate.isEmpty) {
      _currentDate = _getTodayUtcString();
    }

    if (source == 'survey') {
      final maxOfferwalls = _limits['global_offerwalls'] ?? offerwallsCap;
      final available = (maxOfferwalls - _todayOfferwallsEarnings).clamp(0, maxOfferwalls);
      final toAdd = amount.clamp(0, available);
      _todayOfferwallsEarnings += toAdd;
      _persist();
      if (toAdd > 0) notifyListeners();
      return toAdd;
    } else {
      final multiplier = getYieldMultiplier();
      int toAdd = (amount * multiplier).round();
      if (amount > 0 && toAdd <= 0) {
        toAdd = 1;
      }

      if (toAdd > 0) {
        _todayFeaturesEarnings += toAdd;
        if (source == 'daily_reward') {
          _todayDailyRewardEarnings += toAdd;
        } else if (source == 'chest') {
          _todayChestEarnings += toAdd;
        } else if (source == 'spin') {
          _todaySpinEarnings += toAdd;
        } else if (source == 'scratch') {
          _todayScratchEarnings += toAdd;
        } else if (source == 'quiz' || source == 'quizzes') {
          _todayQuizEarnings += toAdd;
        } else if (source == 'math_quiz') {
          _todayGameMathQuizEarnings += toAdd;
        } else if (source == 'flappy_jump') {
          _todayGameFlappyEarnings += toAdd;
        } else if (source == 'tap_tap') {
          _todayGameTapTapEarnings += toAdd;
        } else if (source == 'flip_card') {
          _todayGameFlipCardEarnings += toAdd;
        } else if (source == 'ad' || source == 'watch_video' || source == 'video' || source == 'watch_earn') {
          _todayWatchVideoEarnings += toAdd;
        }
        _persist();
        notifyListeners();
      }
      return toAdd;
    }
  }

  Future<void> _persist() async {
    await _secureStorage.write(key: _featuresEarningsKey, value: _todayFeaturesEarnings.toString());
    await _secureStorage.write(key: _offerwallsEarningsKey, value: _todayOfferwallsEarnings.toString());
    await _secureStorage.write(key: _earningsDateKey, value: _currentDate);

    await _secureStorage.write(key: _dailyRewardEarningsKey, value: _todayDailyRewardEarnings.toString());
    await _secureStorage.write(key: _chestEarningsKey, value: _todayChestEarnings.toString());
    await _secureStorage.write(key: _spinEarningsKey, value: _todaySpinEarnings.toString());
    await _secureStorage.write(key: _scratchEarningsKey, value: _todayScratchEarnings.toString());
    await _secureStorage.write(key: _quizEarningsKey, value: _todayQuizEarnings.toString());

    await _secureStorage.write(key: _gameMathQuizEarningsKey, value: _todayGameMathQuizEarnings.toString());
    await _secureStorage.write(key: _gameFlappyEarningsKey, value: _todayGameFlappyEarnings.toString());
    await _secureStorage.write(key: _gameTapTapEarningsKey, value: _todayGameTapTapEarnings.toString());
    await _secureStorage.write(key: _gameFlipCardEarningsKey, value: _todayGameFlipCardEarnings.toString());
    await _secureStorage.write(key: _watchVideoEarningsKey, value: _todayWatchVideoEarnings.toString());
  }
}
