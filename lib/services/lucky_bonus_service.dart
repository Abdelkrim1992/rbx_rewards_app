import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks app usage time and triggers lucky bonus popups every 2 hours.
class LuckyBonusService {
  static const String _lastBonusTimeKey = 'lucky_bonus_last_time';
  static const String _bonusCountTodayKey = 'lucky_bonus_count_today';
  static const String _bonusDateKey = 'lucky_bonus_date';
  static const Duration _triggerInterval = Duration(hours: 2);
  static const int _maxDailyBonuses = 3;

  Timer? _usageTimer;
  DateTime? _lastBonusTime;
  int _bonusCountToday = 0;
  String _todayDate = '';
  bool _isTracking = false;

  /// Whether a lucky bonus is currently available to show.
  bool get canShowBonus {
    _checkDailyReset();
    if (_bonusCountToday >= _maxDailyBonuses) return false;
    if (_lastBonusTime == null) return true;
    return DateTime.now().difference(_lastBonusTime!) >= _triggerInterval;
  }

  int get remainingBonusesToday => _maxDailyBonuses - _bonusCountToday;

  /// Generate a random reward amount (100-500 RBX).
  int generateReward() => 100 + Random().nextInt(401);

  /// Load persisted state.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(_lastBonusTimeKey);
    if (lastTime != null) {
      _lastBonusTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
    }
    _bonusCountToday = prefs.getInt(_bonusCountTodayKey) ?? 0;
    _todayDate = prefs.getString(_bonusDateKey) ?? '';
    _checkDailyReset();
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (_todayDate != today) {
      _bonusCountToday = 0;
      _todayDate = today;
      _persist();
    }
  }

  /// Start tracking active app usage time.
  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Active usage tracking placeholder
    });
  }

  /// Stop tracking usage time.
  void stopTracking() {
    _usageTimer?.cancel();
    _isTracking = false;
  }

  /// Record that a bonus was shown and claimed/dismissed.
  Future<void> recordBonusShown() async {
    _lastBonusTime = DateTime.now();
    _bonusCountToday++;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastBonusTime != null) {
      await prefs.setInt(
          _lastBonusTimeKey, _lastBonusTime!.millisecondsSinceEpoch);
    }
    await prefs.setInt(_bonusCountTodayKey, _bonusCountToday);
    await prefs.setString(_bonusDateKey, _todayDate);
  }

  void dispose() {
    _usageTimer?.cancel();
  }
}
