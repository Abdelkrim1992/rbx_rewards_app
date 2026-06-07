import 'package:hive_flutter/hive_flutter.dart';

class HiveRepository {
  static const String _pendingBoxName = 'pending_txs';
  late Box<Map> _pendingBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _pendingBox = await Hive.openBox<Map>(_pendingBoxName);
  }

  Future<void> enqueuePending(Map<String, dynamic> tx) async {
    await _pendingBox.add(tx);
  }

  List<Map<String, dynamic>> getPendingQueue() {
    return _pendingBox.values.map((map) {
      return Map<String, dynamic>.from(map);
    }).toList();
  }

  Future<void> setPendingQueue(List<Map<String, dynamic>> queue) async {
    await _pendingBox.clear();
    for (final tx in queue) {
      await _pendingBox.add(tx);
    }
  }

  Future<void> clearAll() async {
    await _pendingBox.clear();
  }
}
