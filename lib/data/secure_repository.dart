import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureRepository {
  static const _storage = FlutterSecureStorage();

  static const String _keyBalance = 'balance';
  static const String _keyDailyRewardClaimedAt = 'daily_reward_claimed_at';
  static const String _keySpinFreeSpins = 'spin_free_spins';
  static const String _keySpinCooldownEnd = 'spin_cooldown_end';
  static const String _keyFirstRedemptionReachedAt = 'first_redemption_reached_at';

  Future<int> getBalance() async {
    final val = await _storage.read(key: _keyBalance);
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<void> saveBalance(int balance) async {
    await _storage.write(key: _keyBalance, value: '$balance');
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> writeDailyRewardClaimedAt(DateTime time) async {
    await _storage.write(
      key: _keyDailyRewardClaimedAt,
      value: '${time.millisecondsSinceEpoch}',
    );
  }

  Future<Duration> getDailyRewardCooldownLocal() async {
    final val = await _storage.read(key: _keyDailyRewardClaimedAt);
    if (val == null) return Duration.zero;
    final claimedAtMs = int.tryParse(val);
    if (claimedAtMs == null) return Duration.zero;

    final claimedAt = DateTime.fromMillisecondsSinceEpoch(claimedAtMs);
    final remaining = claimedAt.add(const Duration(hours: 24)).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> saveSpinState(int spins, int? cooldownEndMs) async {
    await _storage.write(key: _keySpinFreeSpins, value: '$spins');
    if (cooldownEndMs != null) {
      await _storage.write(key: _keySpinCooldownEnd, value: '$cooldownEndMs');
    } else {
      await _storage.delete(key: _keySpinCooldownEnd);
    }
  }

  Future<int> getSpinFreeSpins() async {
    final val = await _storage.read(key: _keySpinFreeSpins);
    return int.tryParse(val ?? '5') ?? 5;
  }

  Future<int?> getSpinCooldownEnd() async {
    final val = await _storage.read(key: _keySpinCooldownEnd);
    return val != null ? int.tryParse(val) : null;
  }

  Future<int?> getFirstRedemptionReachedAt() async {
    final val = await _storage.read(key: _keyFirstRedemptionReachedAt);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> saveFirstRedemptionReachedAt(int timeMs) async {
    await _storage.write(key: _keyFirstRedemptionReachedAt, value: '$timeMs');
  }
}
