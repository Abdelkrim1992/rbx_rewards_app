import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks daily coin earnings and enforces a 5000 RBX cap.
class DailyCapService {
  static const _secureStorage = FlutterSecureStorage();
  static const String _dailyEarningsKey = 'daily_earnings';
  static const String _earningsDateKey = 'earnings_date';
  static const int _dailyCap = 5000;

  int _todayEarnings = 0;
  String _currentDate = '';

  int get todayEarnings => _todayEarnings;
  int get remainingToday => (_dailyCap - _todayEarnings).clamp(0, _dailyCap);
  bool get isCapReached => _todayEarnings >= _dailyCap;

  /// Load persisted daily earnings.
  Future<void> load() async {
    final storedDate = await _secureStorage.read(key: _earningsDateKey) ?? '';
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';

    if (storedDate == today) {
      final storedEarningsStr = await _secureStorage.read(key: _dailyEarningsKey);
      _todayEarnings = storedEarningsStr != null ? (int.tryParse(storedEarningsStr) ?? 0) : 0;
    } else {
      _todayEarnings = 0;
    }
    _currentDate = today;
  }

  /// Try to add coins. Returns the amount actually added (may be less than requested if cap hit).
  int addCoins(int amount) {
    if (_currentDate.isEmpty) {
      final now = DateTime.now();
      _currentDate = '${now.year}-${now.month}-${now.day}';
    }

    final available = _dailyCap - _todayEarnings;
    final toAdd = amount.clamp(0, available);
    _todayEarnings += toAdd;
    _persist();
    return toAdd;
  }

  Future<void> _persist() async {
    await _secureStorage.write(key: _dailyEarningsKey, value: _todayEarnings.toString());
    await _secureStorage.write(key: _earningsDateKey, value: _currentDate);
  }
}
