import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple SharedPreferences-based queue for pending coin/game transactions
/// to be retried when the device comes back online.
class PendingTransactionService {
  static const String _keyQueue = 'pending_transactions';

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyQueue);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_keyQueue);
    } else {
      await prefs.setString(_keyQueue, jsonEncode(queue));
    }
  }

  static Future<void> enqueue(Map<String, dynamic> tx) async {
    final queue = await getQueue();
    final txId = tx['txId'] as String?;
    if (txId != null && queue.any((item) => item['txId'] == txId)) {
      return; // Already queued; skip duplicate.
    }
    queue.add(tx);
    await setQueue(queue);
  }
}
