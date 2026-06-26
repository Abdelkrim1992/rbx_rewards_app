import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/supabase_repository.dart';

/// Tracks daily coin earnings and enforces in-app feature level daily caps.
class DailyCapService {
  final SupabaseRepository _repository;
  
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

  // Static Fallback Caps (defaults)
  static const int featuresCap = 1000;
  static const int offerwallsCap = 1000;
  
  static const int dailyRewardCap = 30;
  static const int chestCap = 120;
  static const int spinCap = 150;
  static const int scratchCap = 100;
  static const int quizCap = 120;
  
  // Sub-game caps
  static const int gameMathQuizCap = 120;
  static const int gameFlappyCap = 150;
  static const int gameTapTapCap = 150;
  static const int gameFlipCardCap = 60;

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
  };

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

  // Dynamic Caps getters (read from dynamic map)
  int get dynamicFeaturesCap => _limits['global_features'] ?? featuresCap;
  int get dynamicOfferwallsCap => _limits['global_offerwalls'] ?? offerwallsCap;

  // Backwards compatibility properties
  int get todayEarnings => _todayFeaturesEarnings + _todayOfferwallsEarnings;
  int get remainingToday => (dynamicFeaturesCap - _todayFeaturesEarnings).clamp(0, dynamicFeaturesCap);
  bool get isCapReached => _todayFeaturesEarnings >= dynamicFeaturesCap;

  int get remainingFeaturesToday => (dynamicFeaturesCap - _todayFeaturesEarnings).clamp(0, dynamicFeaturesCap);
  int get remainingOfferwallsToday => (dynamicOfferwallsCap - _todayOfferwallsEarnings).clamp(0, dynamicOfferwallsCap);

  bool get isFeaturesCapReached => _todayFeaturesEarnings >= dynamicFeaturesCap;
  bool get isOfferwallsCapReached => _todayOfferwallsEarnings >= dynamicOfferwallsCap;

  /// Load persisted daily earnings.
  Future<void> load() async {
    final storedDate = await _secureStorage.read(key: _earningsDateKey) ?? '';
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';

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
    } else {
      _resetEarnings();
    }
    _currentDate = today;

    // Load cached dynamic limits from secure storage if available
    for (final key in _limits.keys) {
      try {
        final val = await _secureStorage.read(key: 'cap_limit_$key');
        if (val != null) {
          final parsed = int.tryParse(val);
          if (parsed != null) {
            _limits[key] = parsed;
          }
        }
      } catch (_) {}
    }

    // Async background fetch fresh limits from database
    _fetchFreshLimits();
  }

  Future<void> _fetchFreshLimits() async {
    try {
      final list = await _repository.getCoinDistributions();
      for (final item in list) {
        final id = item['id'] as String?;
        final cap = item['daily_cap'] as int?;
        if (id != null && cap != null) {
          _limits[id] = cap;
          // Cache in secure storage
          await _secureStorage.write(key: 'cap_limit_$id', value: cap.toString());
        }
      }
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
  }

  /// Get the remaining cap for a specific feature source.
  int getRemainingCap(String source) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (_currentDate != today) {
      return _getInitialCategoryCap(source);
    }

    final globalRemaining = (dynamicFeaturesCap - _todayFeaturesEarnings).clamp(0, dynamicFeaturesCap);
    
    if (source == 'survey') {
      final maxOfferwalls = _limits['global_offerwalls'] ?? offerwallsCap;
      return (maxOfferwalls - _todayOfferwallsEarnings).clamp(0, maxOfferwalls);
    }
    
    int categoryRemaining = 0;
    final categoryCap = _limits[source] ?? _getInitialCategoryCap(source);
    
    if (source == 'daily_reward') {
      categoryRemaining = (categoryCap - _todayDailyRewardEarnings).clamp(0, categoryCap);
    } else if (source == 'chest') {
      categoryRemaining = (categoryCap - _todayChestEarnings).clamp(0, categoryCap);
    } else if (source == 'spin') {
      categoryRemaining = (categoryCap - _todaySpinEarnings).clamp(0, categoryCap);
    } else if (source == 'scratch') {
      categoryRemaining = (categoryCap - _todayScratchEarnings).clamp(0, categoryCap);
    } else if (source == 'quiz') {
      categoryRemaining = (categoryCap - _todayQuizEarnings).clamp(0, categoryCap);
    } else if (source == 'math_quiz') {
      categoryRemaining = (categoryCap - _todayGameMathQuizEarnings).clamp(0, categoryCap);
    } else if (source == 'flappy_jump') {
      categoryRemaining = (categoryCap - _todayGameFlappyEarnings).clamp(0, categoryCap);
    } else if (source == 'tap_tap') {
      categoryRemaining = (categoryCap - _todayGameTapTapEarnings).clamp(0, categoryCap);
    } else if (source == 'flip_card') {
      categoryRemaining = (categoryCap - _todayGameFlipCardEarnings).clamp(0, categoryCap);
    } else {
      return 0;
    }

    return categoryRemaining < globalRemaining ? categoryRemaining : globalRemaining;
  }

  int _getInitialCategoryCap(String source) {
    if (source == 'survey') return _limits['global_offerwalls'] ?? offerwallsCap;
    return _limits[source] ?? 0;
  }

  bool isCapReachedFor(String source) {
    return getRemainingCap(source) <= 0;
  }

  /// Try to add coins. Returns the amount actually added (may be less than requested if cap hit).
  int addCoins(int amount, String source) {
    if (_currentDate.isEmpty) {
      final now = DateTime.now();
      _currentDate = '${now.year}-${now.month}-${now.day}';
    }

    if (source == 'survey') {
      final maxOfferwalls = _limits['global_offerwalls'] ?? offerwallsCap;
      final available = (maxOfferwalls - _todayOfferwallsEarnings).clamp(0, maxOfferwalls);
      final toAdd = amount.clamp(0, available);
      _todayOfferwallsEarnings += toAdd;
      _persist();
      return toAdd;
    } else {
      final globalAvailable = (dynamicFeaturesCap - _todayFeaturesEarnings).clamp(0, dynamicFeaturesCap);
      int categoryAvailable = 0;
      final categoryCap = _limits[source] ?? _getInitialCategoryCap(source);
      
      if (source == 'daily_reward') {
        categoryAvailable = (categoryCap - _todayDailyRewardEarnings).clamp(0, categoryCap);
      } else if (source == 'chest') {
        categoryAvailable = (categoryCap - _todayChestEarnings).clamp(0, categoryCap);
      } else if (source == 'spin') {
        categoryAvailable = (categoryCap - _todaySpinEarnings).clamp(0, categoryCap);
      } else if (source == 'scratch') {
        categoryAvailable = (categoryCap - _todayScratchEarnings).clamp(0, categoryCap);
      } else if (source == 'quiz') {
        categoryAvailable = (categoryCap - _todayQuizEarnings).clamp(0, categoryCap);
      } else if (source == 'math_quiz') {
        categoryAvailable = (categoryCap - _todayGameMathQuizEarnings).clamp(0, categoryCap);
      } else if (source == 'flappy_jump') {
        categoryAvailable = (categoryCap - _todayGameFlappyEarnings).clamp(0, categoryCap);
      } else if (source == 'tap_tap') {
        categoryAvailable = (categoryCap - _todayGameTapTapEarnings).clamp(0, categoryCap);
      } else if (source == 'flip_card') {
        categoryAvailable = (categoryCap - _todayGameFlipCardEarnings).clamp(0, categoryCap);
      } else if (source == 'game') {
        categoryAvailable = globalAvailable;
      } else {
        categoryAvailable = 0;
      }

      final toAdd = amount.clamp(0, categoryAvailable < globalAvailable ? categoryAvailable : globalAvailable);
      
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
        } else if (source == 'quiz') {
          _todayQuizEarnings += toAdd;
        } else if (source == 'math_quiz') {
          _todayGameMathQuizEarnings += toAdd;
        } else if (source == 'flappy_jump') {
          _todayGameFlappyEarnings += toAdd;
        } else if (source == 'tap_tap') {
          _todayGameTapTapEarnings += toAdd;
        } else if (source == 'flip_card') {
          _todayGameFlipCardEarnings += toAdd;
        }
        _persist();
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
  }
}
