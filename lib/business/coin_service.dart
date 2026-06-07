import '../data/hive_repository.dart';
import '../data/secure_repository.dart';
import '../data/supabase_repository.dart';
import 'connectivity_service.dart';

class CoinService {
  final SupabaseRepository _remote;
  final HiveRepository _queue;
  final SecureRepository _secure;
  final ConnectivityService _connectivity;

  CoinService({
    required SupabaseRepository remote,
    required HiveRepository queue,
    required SecureRepository secure,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _queue = queue,
        _secure = secure,
        _connectivity = connectivity;

  Future<int> creditCoins(int amount, {required String source, required String txId}) async {
    final online = await _connectivity.isOnline;
    if (!online) {
      await _queue.enqueuePending({
        'type': 'credit',
        'amount': amount,
        'source': source,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final cached = await _secure.getBalance();
      final optimistic = cached + amount;
      await _secure.saveBalance(optimistic);
      return optimistic;
    }
    try {
      final balance = await _remote.creditCoinsViaEdge(amount, source, txId);
      await _secure.saveBalance(balance);
      return balance;
    } catch (e) {
      await _queue.enqueuePending({
        'type': 'credit',
        'amount': amount,
        'source': source,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final cached = await _secure.getBalance();
      final optimistic = cached + amount;
      await _secure.saveBalance(optimistic);
      rethrow;
    }
  }

  Future<int> spendCoins(int amount, {required String rewardTitle, required String txId}) async {
    final online = await _connectivity.isOnline;
    if (!online) {
      await _queue.enqueuePending({
        'type': 'spend',
        'amount': amount,
        'rewardTitle': rewardTitle,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final cached = await _secure.getBalance();
      final optimistic = cached - amount;
      await _secure.saveBalance(optimistic);
      return optimistic;
    }
    try {
      final balance = await _remote.spendCoinsViaEdge(amount, rewardTitle, txId);
      await _secure.saveBalance(balance);
      return balance;
    } catch (e) {
      // For spend, if it fails, we shouldn't necessarily assume it went through,
      // but to match the previous queueing/offline behavior:
      await _queue.enqueuePending({
        'type': 'spend',
        'amount': amount,
        'rewardTitle': rewardTitle,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final cached = await _secure.getBalance();
      final optimistic = cached - amount;
      await _secure.saveBalance(optimistic);
      rethrow;
    }
  }

  Future<void> flushPendingQueue() async {
    final online = await _connectivity.isOnline;
    if (!online) return;

    final queue = _queue.getPendingQueue();
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final tx in queue) {
      try {
        switch (tx['type']) {
          case 'credit':
            await _remote.creditCoinsViaEdge(tx['amount'] as int, tx['source'] as String, tx['txId'] as String);
            break;
          case 'spend':
            await _remote.spendCoinsViaEdge(tx['amount'] as int, tx['rewardTitle'] as String, tx['txId'] as String);
            break;
          case 'game':
          case 'game_result':
            // Game sessions flushed via edge function add-game-coins
            await _remote.callEdgeFunction('add-game-coins', body: {
              'amount': tx['score'],
              'gameName': tx['gameName'],
              'sessionId': tx['sessionId'],
              'txId': tx['txId'] ?? 'game_${tx['sessionId']}',
              'durationSeconds': tx['durationSeconds'],
              'multiplier': tx['multiplier'] ?? 1,
            });
            break;
        }
      } catch (e) {
        if (!_isIdempotencyError(e)) {
          remaining.add(tx);
        }
      }
    }
    await _queue.setPendingQueue(remaining);
  }

  bool _isIdempotencyError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('duplicate') ||
        msg.contains('already processed') ||
        msg.contains('insufficient') ||
        msg.contains('cap reached') ||
        msg.contains('unique_violation') ||
        msg.contains('23505'); // Postgres unique violation code
  }
}
