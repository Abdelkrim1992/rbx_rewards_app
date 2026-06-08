import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbx_rewards_app/presentation/providers/user_provider.dart';
import '../../core/utils/uuid_generator.dart';
import 'providers.dart';

final coinProvider = NotifierProvider<CoinNotifier, int>(() => CoinNotifier());

class CoinNotifier extends Notifier<int> {
  bool _mounted = true;

  @override
  int build() {
    ref.onDispose(() => _mounted = false);

    // Listen to auth state changes to sync balance when user logs in
    ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        _syncFromBackend();
      }
    });

    // Step 1: Show cached local balance immediately (instant, no network needed)
    // Step 2: Fetch authoritative balance from backend in background
    // Use Future.microtask to avoid using ref.read directly inside the build method
    Future.microtask(() {
      if (_mounted) {
        _loadFromLocal();
        _syncFromBackend();
      }
    });

    return 0;
  }

  /// Load balance from device secure storage. Fast and offline-capable.
  void _loadFromLocal() {
    ref.read(secureRepositoryProvider).getBalance().then((cached) {
      if (!_mounted) return;
      // Only apply cached value if backend hasn't already updated state
      if (state == 0 && cached > 0) {
        state = cached;
      }
    }).catchError((_) {});
  }

  /// Fetch the authoritative balance from the backend Edge Function (Redis-backed).
  /// This is the single source of truth — overwrites any cached value.
  void _syncFromBackend() {
    ref.read(supabaseRepositoryProvider).getUserStats().then((data) {
      if (!_mounted) return;
      if (data.isEmpty) return;
      final balance = data['balance'] as int? ?? data['coins'] as int? ?? 0;
      if (balance >= 0) {
        state = balance;
        // Persist to local cache so next startup shows correct value instantly
        ref.read(secureRepositoryProvider).saveBalance(balance);
      }
    }).catchError((e) {
      // Backend unavailable — local cache value is kept, no crash
      // ignore: avoid_print
      print('CoinNotifier: Could not sync from backend: $e');
    });
  }

  /// Add coins to the balance. Updates state immediately (optimistic),
  /// then syncs to the backend. UI never waits for the network.
  Future<int> credit(int amount, String source) async {
    if (!_mounted) return 0;
    final txId = UuidGenerator.generateV4();
    final optimisticBalance = state + amount;
    state = optimisticBalance; // immediate UI update
    _saveLocally(optimisticBalance);
    
    try {
      final newBalance = await ref.read(coinServiceProvider).creditCoins(
        amount,
        source: source,
        txId: txId,
      );
      if (_mounted) {
        state = newBalance;
        _saveLocally(newBalance);
      }
      return newBalance;
    } catch (_) {
      // Optimistic value is kept; offline queue handles the sync later
      return optimisticBalance;
    }
  }

  /// Spend coins. Updates state immediately (optimistic), then syncs to backend.
  Future<bool> spend(int amount, String rewardTitle) async {
    if (!_mounted) return false;
    if (state < amount) return false;
    final txId = UuidGenerator.generateV4();
    final optimisticBalance = state - amount;
    state = optimisticBalance; // immediate UI update
    _saveLocally(optimisticBalance);
    
    try {
      final newBalance = await ref.read(coinServiceProvider).spendCoins(
        amount,
        rewardTitle: rewardTitle,
        txId: txId,
      );
      if (_mounted) {
        state = newBalance;
        _saveLocally(newBalance);
      }
      return true;
    } catch (_) {
      // Queueing handled in coinServiceProvider.
      return true;
    }
  }

  /// Called externally when a trusted source (e.g. backend webhook, offerwall)
  /// provides the authoritative balance. Always overwrites local state.
  void updateBalance(int balance) {
    if (!_mounted) return;
    state = balance;
    _saveLocally(balance);
  }

  /// Re-syncs balance from the backend. Call this when the app comes to foreground
  /// or after an offerwall session ends.
  void refresh() {
    _syncFromBackend();
  }

  void _saveLocally(int balance) {
    ref.read(secureRepositoryProvider).saveBalance(balance);
  }
}
