import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import '../../core/utils/uuid_generator.dart';
import 'providers.dart';

final coinProvider = NotifierProvider<CoinNotifier, int>(() => CoinNotifier());

class CoinNotifier extends Notifier<int> {
  bool _mounted = true;
  int _lastCreditTime = 0;

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
    // Step 2: Flush pending offline queue if any
    // Step 3: Fetch authoritative balance from backend in background
    Future.microtask(() {
      if (_mounted) {
        _loadFromLocal();
        ref.read(coinServiceProvider).flushPendingQueue().then((_) {
          if (_mounted) _syncFromBackend();
        }).catchError((_) {
          if (_mounted) _syncFromBackend();
        });
        ref.read(dailyCapServiceProvider).load();
      }
    });

    return 0;
  }

  /// Load balance from device secure storage. Fast and offline-capable.
  /// Shows cached data immediately upon app startup.
  void _loadFromLocal() {
    ref.read(secureRepositoryProvider).getBalance().then((cached) {
      if (!_mounted) return;
      // Only apply cached value if backend hasn't already updated state
      if (state == 0 && cached > 0) {
        state = cached;
      }
    }).catchError((_) {});
  }

  /// Fetch the authoritative balance from the backend Edge Function / Postgres DB.
  /// This is the single source of truth — saves to cache and updates state.
  void _syncFromBackend() {
    ref.read(supabaseRepositoryProvider).getUserStats().then((data) {
      if (!_mounted) return;
      if (data.isEmpty) return;
      final balance = data['balance'] as int? ?? data['coins'] as int? ?? 0;
      if (balance >= 0) {
        // Prevent stale backend cache with 0 coins from wiping out an active positive balance
        if (state > 0 && balance == 0) return;
        // Prevent stale backend response from wiping out a recent in-flight credit
        if (state > balance &&
            (DateTime.now().millisecondsSinceEpoch - _lastCreditTime < 10000)) {
          return;
        }
        state = balance;
        // Persist authoritative balance to local cache so next startup shows correct value instantly
        ref.read(secureRepositoryProvider).saveBalance(balance);
      }
    }).catchError((e) {
      // Backend unavailable — local cache value is kept, no crash
      // ignore: avoid_print
      print('CoinNotifier: Could not sync from backend: $e');
    });
  }

  /// Add coins to the balance. Pushes FIRST to database, then upon confirmation
  /// caches to local storage and updates state.
  Future<int> credit(int amount, String source) async {
    if (!_mounted) return 0;
    
    final dailyCapService = ref.read(dailyCapServiceProvider);
    final allowedAmount = dailyCapService.addCoins(amount, source);
    if (allowedAmount <= 0) {
      return state;
    }

    final txId = UuidGenerator.generateV4();
    _lastCreditTime = DateTime.now().millisecondsSinceEpoch;
    
    try {
      // 1. Push to database FIRST
      final newBalance = await ref.read(coinServiceProvider).creditCoins(
        allowedAmount,
        source: source,
        txId: txId,
      );
      
      // 2. Cache locally and update state ONLY AFTER database confirmation
      if (_mounted) {
        // Never allow a credit operation to decrease active balance
        if (newBalance >= state) {
          state = newBalance;
          _saveLocally(newBalance);
        } else {
          final safeBalance = state + allowedAmount;
          state = safeBalance;
          _saveLocally(safeBalance);
        }
      }
      return state;
    } catch (_) {
      // Offline / network fallback: CoinService already enqueued the tx
      // and saved to local secure cache.
      final cached = await ref.read(secureRepositoryProvider).getBalance();
      if (_mounted) {
        state = cached > 0 ? cached : (state + allowedAmount);
        _saveLocally(state);
      }
      return state;
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

  /// Sets the authoritative balance confirmed directly by the database
  /// (e.g. from game_service session submission, Supabase RPC, or backend response),
  /// caching it to local storage immediately.
  void setAuthoritativeBalance(int newBalance) {
    if (!_mounted) return;
    if (newBalance <= 0 && state > 0) return;
    _lastCreditTime = DateTime.now().millisecondsSinceEpoch;
    state = newBalance;
    _saveLocally(newBalance);
  }

  /// Called externally when a trusted source (e.g. backend webhook, offerwall)
  /// provides the authoritative balance. Overwrites local state and updates cache.
  void updateBalance(int balance) {
    if (!_mounted) return;
    if (state > 0 && balance == 0) return;
    // Never allow an external update to reduce local balance unless it's an intentional reset
    if (balance < state) return;
    // Prevent stale backend cache from wiping out a recent in-flight credit
    if (state > balance &&
        (DateTime.now().millisecondsSinceEpoch - _lastCreditTime < 10000)) {
      return;
    }
    state = balance;
    _saveLocally(balance);
  }

  /// Re-syncs balance from the backend. Call this when the app comes to foreground
  /// or after an offerwall session ends.
  void refresh() {
    _syncFromBackend();
  }

  /// Unconditionally resets the balance to 0, wiping in-memory state and local cache.
  /// Used during account deletion or fresh reset.
  void forceReset() {
    if (!_mounted) return;
    _lastCreditTime = 0;
    state = 0;
    _saveLocally(0);
  }

  void _saveLocally(int balance) {
    ref.read(secureRepositoryProvider).saveBalance(balance);
  }
}
