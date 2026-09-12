import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/quest_model.dart';
import '../../business/quest_service.dart';
import 'coin_provider.dart';
import 'providers.dart';
import 'user_provider.dart';

final questServiceProvider = Provider<QuestService>((ref) {
  return QuestService(
    coinService: ref.watch(coinServiceProvider),
    antiCheat: ref.watch(antiCheatServiceProvider),
  );
});

final questStateProvider =
    StateNotifierProvider<QuestNotifier, AsyncValue<DailyQuestsState>>((ref) {
  return QuestNotifier(ref);
});

class QuestNotifier extends StateNotifier<AsyncValue<DailyQuestsState>> {
  final Ref _ref;

  QuestNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final service = _ref.read(questServiceProvider);
      final stateData = await service.getQuestsState();
      state = AsyncValue.data(stateData);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> recordGamePlayed() async {
    await _advanceQuest(QuestType.playGame);
  }

  Future<void> recordScratchCard() async {
    await _advanceQuest(QuestType.scratchCard);
  }

  Future<void> recordVideoOrChest() async {
    await _advanceQuest(QuestType.watchVideoOrChest);
  }

  Future<void> _advanceQuest(QuestType type, [int amount = 1]) async {
    try {
      final service = _ref.read(questServiceProvider);
      final updated = await service.incrementQuest(type, amount);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> claimMasterChest({int multiplier = 1}) async {
    final service = _ref.read(questServiceProvider);
    final success = await service.claimMasterChest(rewardMultiplier: multiplier);

    if (success) {
      _ref.invalidate(coinProvider);
      _ref.invalidate(userProfileStreamProvider);
      await load();
    }
    return success;
  }
}
