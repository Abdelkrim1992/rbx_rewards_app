import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Simple FlutterSecureStorage-based queue for pending coin/game transactions
/// to be retried when the device comes back online.
class PendingTransactionService {
  static const String _keyQueue = 'pending_transactions';
  static const _secureStorage = FlutterSecureStorage();
  static Future<void>? _lastEnqueue;

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final jsonStr = await _secureStorage.read(key: _keyQueue);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setQueue(List<Map<String, dynamic>> queue) async {
    if (queue.isEmpty) {
      await _secureStorage.delete(key: _keyQueue);
    } else {
      await _secureStorage.write(key: _keyQueue, value: jsonEncode(queue));
    }
  }

  static Future<void> enqueue(Map<String, dynamic> tx) async {
    final previous = _lastEnqueue;
    _lastEnqueue = Future(() async {
      try {
        await previous;
      } catch (_) {
        // Previous enqueue failed; continue with this one.
      }
      final queue = await getQueue();
      final txId = tx['txId'] as String?;
      if (txId != null && queue.any((item) => item['txId'] == txId)) {
        return; // Already queued; skip duplicate.
      }
      queue.add(tx);
      await setQueue(queue);
    });
    await _lastEnqueue;
  }
}
