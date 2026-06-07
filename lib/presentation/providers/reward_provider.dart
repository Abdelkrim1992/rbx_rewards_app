import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'coin_provider.dart';

final dailyRewardCooldownProvider = StateNotifierProvider<DailyRewardCooldownNotifier, Duration>((ref) {
  return DailyRewardCooldownNotifier(ref);
});

class DailyRewardCooldownNotifier extends StateNotifier<Duration> {
  final Ref _ref;
  Timer? _timer;

  DailyRewardCooldownNotifier(this._ref) : super(Duration.zero) {
    _loadCooldown();
  }

  Future<void> _loadCooldown() async {
    final cooldown = await _ref.read(rewardServiceProvider).getDailyRewardCooldown();
    state = cooldown;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (state == Duration.zero) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.inSeconds > 0) {
        state = state - const Duration(seconds: 1);
      } else {
        state = Duration.zero;
        _timer?.cancel();
      }
    });
  }

  Future<bool> claimDaily({int amount = 100}) async {
    final result = await _ref.read(rewardServiceProvider).claimDailyReward(amount: amount);
    if (result.success) {
      state = const Duration(hours: 24);
      _startTimer();
      await _ref.read(coinProvider.notifier).credit(result.amount, 'daily_reward');
      return true;
    }
    return false;
  }

  Future<void> refresh() async {
    await _loadCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
