import 'dart:async';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks app usage time and triggers lucky bonus popups every 2 hours.
class LuckyBonusService {
  static const _secureStorage = FlutterSecureStorage();
  static const String _lastBonusTimeKey = 'lucky_bonus_last_time';
  static const String _bonusCountTodayKey = 'lucky_bonus_count_today';
  static const String _bonusDateKey = 'lucky_bonus_date';
  static const Duration _triggerInterval = Duration(hours: 2);
  static const int _maxDailyBonuses = 2;

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

  /// Generate a random reward amount (10-30 RBX base coins).
  int generateReward() => 10 + Random().nextInt(21);

  /// Load persisted state.
  Future<void> load() async {
    final lastTimeStr = await _secureStorage.read(key: _lastBonusTimeKey);
    if (lastTimeStr != null) {
      final lastTime = int.tryParse(lastTimeStr);
      if (lastTime != null) {
        _lastBonusTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
      }
    }
    final countTodayStr = await _secureStorage.read(key: _bonusCountTodayKey);
    _bonusCountToday = countTodayStr != null ? (int.tryParse(countTodayStr) ?? 0) : 0;
    _todayDate = await _secureStorage.read(key: _bonusDateKey) ?? '';
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
    if (_lastBonusTime != null) {
      await _secureStorage.write(
          key: _lastBonusTimeKey, value: _lastBonusTime!.millisecondsSinceEpoch.toString());
    }
    await _secureStorage.write(key: _bonusCountTodayKey, value: _bonusCountToday.toString());
    await _secureStorage.write(key: _bonusDateKey, value: _todayDate);
  }

  void dispose() {
    _usageTimer?.cancel();
  }
}
