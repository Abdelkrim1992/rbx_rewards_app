import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static const Duration dailyRewardCooldown = Duration(hours: 24);
  static const int dailyRewardAmount = 100;
  static const int megaChestRewardAmount = 500;

  static const String _keyCoins = 'rbx_coins_balance';
  static const String _keyMegaChestClaimed = 'mega_chest_claimed';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyDailyRewardClaimedAt = 'daily_reward_claimed_at';
  static const String _keySpinFreeSpins = 'spin_free_spins';
  static const String _keySpinCooldownEnd = 'spin_cooldown_end';
  static const String _keyTotalCoinsEarned = 'total_coins_earned';
  static const String _keyGamesPlayed = 'games_played';
  static const String _keyOffersCompleted = 'offers_completed';
  static const String _keyLastActiveDate = 'last_active_date';
  static const String _keyConsecutiveDays = 'consecutive_days';

  int _coins = 0;
  bool _isLoaded = false;
  bool _isMegaChestClaimed = false;
  bool _isOnboardingCompleted = false;
  DateTime? _dailyRewardClaimedAt;
  Timer? _timer;

  int _spinFreeSpins = 1;
  DateTime? _spinCooldownEnd;
  Timer? _spinTimer;

  int _totalCoinsEarned = 0;
  int _gamesPlayed = 0;
  int _offersCompleted = 0;
  DateTime? _lastActiveDate;
  int _consecutiveDays = 0;

  int get coins => _coins;
  bool get isLoaded => _isLoaded;
  bool get isMegaChestClaimed => _isMegaChestClaimed;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  int get totalCoinsEarned => _totalCoinsEarned;
  int get gamesPlayed => _gamesPlayed;
  int get offersCompleted => _offersCompleted;
  int get consecutiveDays => _consecutiveDays;

  Duration get dailyRewardRemaining {
    final claimedAt = _dailyRewardClaimedAt;
    if (claimedAt == null) return Duration.zero;

    final remaining =
        claimedAt.add(dailyRewardCooldown).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isDailyRewardCoolingDown => dailyRewardRemaining > Duration.zero;

  int get spinFreeSpins => _spinFreeSpins;

  bool get isSpinOnCooldown {
    final end = _spinCooldownEnd;
    if (end == null) return false;
    return DateTime.now().isBefore(end);
  }

  Duration get spinCooldownRemaining {
    final end = _spinCooldownEnd;
    if (end == null) return Duration.zero;
    final remaining = end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt(_keyCoins) ?? 0;
    _isMegaChestClaimed = prefs.getBool(_keyMegaChestClaimed) ?? false;
    _isOnboardingCompleted = prefs.getBool(_keyOnboardingCompleted) ?? false;

    final dailyRewardClaimedAt = prefs.getString(_keyDailyRewardClaimedAt);
    _dailyRewardClaimedAt = dailyRewardClaimedAt == null
        ? null
        : DateTime.tryParse(dailyRewardClaimedAt);

    _spinFreeSpins = prefs.getInt(_keySpinFreeSpins) ?? 1;
    final spinCooldownEnd = prefs.getString(_keySpinCooldownEnd);
    _spinCooldownEnd =
        spinCooldownEnd == null ? null : DateTime.tryParse(spinCooldownEnd);

    // Reset spin if cooldown expired
    if (_spinCooldownEnd != null && DateTime.now().isAfter(_spinCooldownEnd!)) {
      _spinFreeSpins = 1;
      _spinCooldownEnd = null;
      await prefs.setInt(_keySpinFreeSpins, 1);
      await prefs.remove(_keySpinCooldownEnd);
    }

    _totalCoinsEarned = prefs.getInt(_keyTotalCoinsEarned) ?? 0;
    _gamesPlayed = prefs.getInt(_keyGamesPlayed) ?? 0;
    _offersCompleted = prefs.getInt(_keyOffersCompleted) ?? 0;

    final lastActiveDate = prefs.getString(_keyLastActiveDate);
    _lastActiveDate =
        lastActiveDate == null ? null : DateTime.tryParse(lastActiveDate);
    _consecutiveDays = prefs.getInt(_keyConsecutiveDays) ?? 0;
    await _updateConsecutiveDays(prefs);

    _isLoaded = true;
    _syncDailyRewardTimer();
    _syncSpinTimer();
    notifyListeners();
  }

  Future<void> _updateConsecutiveDays(SharedPreferences prefs) async {
    final today = DateTime.now();
    final last = _lastActiveDate;
    if (last == null) {
      _consecutiveDays = 1;
    } else {
      final diff = DateTime(today.year, today.month, today.day)
          .difference(DateTime(last.year, last.month, last.day))
          .inDays;
      if (diff == 0) {
        // same day, keep count
      } else if (diff == 1) {
        _consecutiveDays++;
      } else {
        _consecutiveDays = 1;
      }
    }
    _lastActiveDate = today;
    await prefs.setInt(_keyConsecutiveDays, _consecutiveDays);
    await prefs.setString(_keyLastActiveDate, today.toIso8601String());
  }

  Future<void> refreshCoins() async {
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt(_keyCoins) ?? 0;
    notifyListeners();
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboardingCompleted = value;
    await prefs.setBool(_keyOnboardingCompleted, value);
    notifyListeners();
  }

  Future<void> saveCoins(int value) async {
    final prefs = await SharedPreferences.getInstance();
    _coins = value;
    await prefs.setInt(_keyCoins, value);
    notifyListeners();
  }

  Future<int> addCoins(int value) async {
    final total = _coins + value;
    _totalCoinsEarned += value;
    await saveCoins(total);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalCoinsEarned, _totalCoinsEarned);
    return total;
  }

  Future<void> incrementGamesPlayed() async {
    _gamesPlayed++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGamesPlayed, _gamesPlayed);
    notifyListeners();
  }

  Future<void> incrementOffersCompleted() async {
    _offersCompleted++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOffersCompleted, _offersCompleted);
    notifyListeners();
  }

  Future<bool> spendCoins(int value) async {
    if (_coins < value) return false;
    await saveCoins(_coins - value);
    return true;
  }

  Future<bool> claimDailyReward() async {
    if (isDailyRewardCoolingDown) return false;

    final prefs = await SharedPreferences.getInstance();
    _dailyRewardClaimedAt = DateTime.now();
    _coins += dailyRewardAmount;

    await prefs.setString(
      _keyDailyRewardClaimedAt,
      _dailyRewardClaimedAt!.toIso8601String(),
    );
    await prefs.setInt(_keyCoins, _coins);

    _syncDailyRewardTimer();
    notifyListeners();
    return true;
  }

  Future<bool> claimMegaChest() async {
    if (_isMegaChestClaimed) return false;

    final prefs = await SharedPreferences.getInstance();
    _isMegaChestClaimed = true;
    _coins += megaChestRewardAmount;

    await prefs.setBool(_keyMegaChestClaimed, true);
    await prefs.setInt(_keyCoins, _coins);

    notifyListeners();
    return true;
  }

  Future<void> useSpin() async {
    if (_spinFreeSpins <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    _spinFreeSpins--;
    await prefs.setInt(_keySpinFreeSpins, _spinFreeSpins);

    if (_spinFreeSpins == 0) {
      _spinCooldownEnd = DateTime.now().add(const Duration(hours: 24));
      await prefs.setString(
          _keySpinCooldownEnd, _spinCooldownEnd!.toIso8601String());
    }

    _syncSpinTimer();
    notifyListeners();
  }

  Future<void> addFreeSpin() async {
    final prefs = await SharedPreferences.getInstance();
    _spinFreeSpins++;
    await prefs.setInt(_keySpinFreeSpins, _spinFreeSpins);
    notifyListeners();
  }

  void _syncSpinTimer() {
    _spinTimer?.cancel();
    if (!isSpinOnCooldown) return;

    _spinTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isSpinOnCooldown) {
        _spinFreeSpins = 1;
        _spinCooldownEnd = null;
        _spinTimer?.cancel();
      }
      notifyListeners();
    });
  }

  void _syncDailyRewardTimer() {
    _timer?.cancel();
    if (!isDailyRewardCoolingDown) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isDailyRewardCoolingDown) {
        _timer?.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spinTimer?.cancel();
    super.dispose();
  }
}
