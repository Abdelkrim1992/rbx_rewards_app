import '../data/secure_repository.dart';
import '../data/supabase_repository.dart';
import '../models/spin_state.dart';
import 'connectivity_service.dart';

class SpinService {
  final SupabaseRepository _remote;
  final SecureRepository _secure;
  final ConnectivityService _connectivity;

  SpinService({
    required SupabaseRepository remote,
    required SecureRepository secure,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _secure = secure,
        _connectivity = connectivity;

  Future<SpinResult> useSpin() async {
    final online = await _connectivity.isOnline;
    if (!online) {
      // Local spin decrease
      final spins = await _secure.getSpinFreeSpins();
      final newSpins = spins > 0 ? spins - 1 : 0;
      int? cooldownEnd;
      if (newSpins == 0) {
        cooldownEnd = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
      }
      await _secure.saveSpinState(newSpins, cooldownEnd);
      return SpinResult(
        spinsRemaining: newSpins,
        cooldownEnd: cooldownEnd,
        coinsEarned: 0,
      );
    }

    final data = await _remote.callEdgeFunction('use-spin', body: {});
    final result = SpinResult.fromJson(data);
    await _secure.saveSpinState(result.spinsRemaining, result.cooldownEnd);
    return result;
  }

  Future<SpinState> getSpinState() async {
    final online = await _connectivity.isOnline;
    if (!online) {
      final spins = await _secure.getSpinFreeSpins();
      final cooldownEnd = await _secure.getSpinCooldownEnd();
      return SpinState(spinsRemaining: spins, cooldownEndMs: cooldownEnd);
    }
    try {
      final data = await _remote.callEdgeFunction('get-spin-state', body: {});
      final state = SpinState.fromJson(data);
      await _secure.saveSpinState(state.spinsRemaining, state.cooldownEndMs);
      return state;
    } catch (_) {
      final spins = await _secure.getSpinFreeSpins();
      final cooldownEnd = await _secure.getSpinCooldownEnd();
      return SpinState(spinsRemaining: spins, cooldownEndMs: cooldownEnd);
    }
  }

  Future<void> addFreeSpinLocal() async {
    final spins = await _secure.getSpinFreeSpins();
    await _secure.saveSpinState(spins + 1, null);
  }
}
