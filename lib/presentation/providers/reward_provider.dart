import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'coin_provider.dart';
import 'user_provider.dart';

final dailyRewardCooldownProvider = StateNotifierProvider<DailyRewardCooldownNotifier, Duration>((ref) {
  return DailyRewardCooldownNotifier(ref);
});

class DailyRewardCooldownNotifier extends StateNotifier<Duration> {
  final Ref _ref;
  Timer? _timer;
  DateTime? _cooldownEnd;

  DailyRewardCooldownNotifier(this._ref) : super(Duration.zero) {
    // Listen to auth state changes to reload cooldown when session restores
    _ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        _loadCooldown();
      } else {
        state = Duration.zero;
        _timer?.cancel();
      }
    });

    // Initial load in case session is already synchronously available
    Future.microtask(() => _loadCooldown());
  }

  Future<void> _loadCooldown() async {
    final cooldown = await _ref.read(rewardServiceProvider).getDailyRewardCooldown();
    if (cooldown.inSeconds > 0) {
      _cooldownEnd = DateTime.now().add(cooldown);
    } else {
      _cooldownEnd = null;
    }
    state = cooldown;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_cooldownEnd == null || state == Duration.zero) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownEnd == null) {
        timer.cancel();
        return;
      }
      final remaining = _cooldownEnd!.difference(DateTime.now());
      if (remaining.inSeconds > 0) {
        state = remaining;
      } else {
        state = Duration.zero;
        _cooldownEnd = null;
        _timer?.cancel();
      }
    });
  }

  Future<bool> claimDaily({int amount = 100}) async {
    final result = await _ref.read(rewardServiceProvider).claimDailyReward(amount: amount);
    if (result.success) {
      state = const Duration(hours: 24);
      _cooldownEnd = DateTime.now().add(state);
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
