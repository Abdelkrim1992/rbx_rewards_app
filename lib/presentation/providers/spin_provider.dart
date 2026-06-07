import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/spin_state.dart';
import 'providers.dart';

final spinProvider = NotifierProvider<SpinNotifier, SpinState>(() => SpinNotifier());

class SpinNotifier extends Notifier<SpinState> {
  Timer? _timer;

  @override
  SpinState build() {
    // Load initial spin state asynchronously
    ref.read(spinServiceProvider).getSpinState().then((state) {
      this.state = state;
      _startTimerIfNeeded();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return SpinState(spinsRemaining: 5, cooldownEndMs: null);
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    final cooldownEnd = state.cooldownEndMs;
    if (cooldownEnd == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= cooldownEnd) {
        _timer?.cancel();
        // Cooldown finished, refresh state from server/local reset
        ref.read(spinServiceProvider).getSpinState().then((newState) {
          state = newState;
        });
      } else {
        // Trigger a state update to rebuild listeners (even if fields are same, we just update reference to notify)
        state = SpinState(spinsRemaining: state.spinsRemaining, cooldownEndMs: state.cooldownEndMs);
      }
    });
  }

  Duration get cooldownRemaining {
    final cooldownEnd = state.cooldownEndMs;
    if (cooldownEnd == null) return Duration.zero;
    final remainingMs = cooldownEnd - DateTime.now().millisecondsSinceEpoch;
    return remainingMs > 0 ? Duration(milliseconds: remainingMs) : Duration.zero;
  }

  Future<SpinResult?> spin() async {
    try {
      final result = await ref.read(spinServiceProvider).useSpin();
      state = SpinState(spinsRemaining: result.spinsRemaining, cooldownEndMs: result.cooldownEnd);
      _startTimerIfNeeded();
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    final newState = await ref.read(spinServiceProvider).getSpinState();
    state = newState;
    _startTimerIfNeeded();
  }

  Future<void> addFreeSpinLocal() async {
    await ref.read(spinServiceProvider).addFreeSpinLocal();
    await refresh();
  }
}
