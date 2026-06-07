import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/uuid_generator.dart';
import 'providers.dart';

final coinProvider = NotifierProvider<CoinNotifier, int>(() => CoinNotifier());

class CoinNotifier extends Notifier<int> {
  @override
  int build() {
    // Synchronously read the cached balance from secure storage on startup.
    // However, since SecureStorage is async, we can load it asynchronously or default to 0,
    // and trigger an async update.
    // Alternatively, we can let userProfileProvider keep track of user profile, and let coinProvider
    // just be a simple notifier or watch userProfileProvider.
    // Let's load the cached balance asynchronously in an init/load method or load it in build:
    ref.read(secureRepositoryProvider).getBalance().then((balance) {
      state = balance;
    });
    return 0;
  }

  Future<int> credit(int amount, String source) async {
    final txId = UuidGenerator.generateV4();
    state += amount; // optimistic update
    try {
      final newBalance = await ref.read(coinServiceProvider).creditCoins(amount, source: source, txId: txId);
      state = newBalance;
      return state;
    } catch (_) {
      // Optimistic state is kept, but it will be flushed when online.
      return state;
    }
  }

  Future<bool> spend(int amount, String rewardTitle) async {
    if (state < amount) return false;
    final txId = UuidGenerator.generateV4();
    state -= amount; // optimistic update
    try {
      final newBalance = await ref.read(coinServiceProvider).spendCoins(amount, rewardTitle: rewardTitle, txId: txId);
      state = newBalance;
      return true;
    } catch (_) {
      // Revert optimistic if offline queue is not expected to handle spends, 
      // but coin_service.spendCoins also queues it. So keep the optimistic value.
      return true;
    }
  }

  void updateBalance(int balance) {
    state = balance;
  }
}
