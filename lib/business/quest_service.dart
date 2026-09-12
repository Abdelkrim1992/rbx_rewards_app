import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/quest_model.dart';
import 'anti_cheat_service.dart';
import 'coin_service.dart';

/// Service managing daily quests progression, daily resets, and master chest rewards.
class QuestService {
  final CoinService _coinService;
  final AntiCheatService _antiCheat;
  static const _storage = FlutterSecureStorage();

  static const String _keyQuestsState = 'daily_quests_state_v1';

  QuestService({
    required CoinService coinService,
    required AntiCheatService antiCheat,
  })  : _coinService = coinService,
        _antiCheat = antiCheat;

  String _getTodayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Loads daily quests, automatically resetting at UTC midnight
  Future<DailyQuestsState> getQuestsState() async {
    final today = _getTodayKey();
    final raw = await _storage.read(key: _keyQuestsState);

    if (raw != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        if (data['dateKey'] == today) {
          final list = (data['quests'] as List)
              .map((q) => DailyQuest.fromJson(Map<String, dynamic>.from(q as Map)))
              .toList();
          return DailyQuestsState(
            dateKey: today,
            quests: list,
            isMasterChestClaimed: data['isMasterChestClaimed'] as bool? ?? false,
          );
        }
      } catch (e) {
        debugPrint('QuestService parse error: $e');
      }
    }

    // New day or first run: initialize defaults
    final freshState = DailyQuestsState(
      dateKey: today,
      quests: DailyQuestsState.defaultQuests(),
      isMasterChestClaimed: false,
    );
    await _persistState(freshState);
    return freshState;
  }

  /// Advances progress for a specific quest type
  Future<DailyQuestsState> incrementQuest(QuestType type, [int amount = 1]) async {
    final currentState = await getQuestsState();
    final updatedQuests = currentState.quests.map((quest) {
      if (quest.type == type && !quest.isCompleted) {
        final nextVal = (quest.currentProgress + amount).clamp(0, quest.targetCount);
        return quest.copyWith(currentProgress: nextVal);
      }
      return quest;
    }).toList();

    final nextState = DailyQuestsState(
      dateKey: currentState.dateKey,
      quests: updatedQuests,
      isMasterChestClaimed: currentState.isMasterChestClaimed,
    );

    await _persistState(nextState);
    return nextState;
  }

  /// Claims the Master Milestone Chest if all quests are complete
  Future<bool> claimMasterChest({int rewardMultiplier = 1}) async {
    // 1. Anti-cheat check: ensure clock is not tampered
    final clockCheck = _antiCheat.validateDeviceClock();
    if (!clockCheck.isValid) {
      debugPrint('QuestService: clock tampered, claim blocked');
      return false;
    }

    final state = await getQuestsState();
    if (!state.areAllCompleted || state.isMasterChestClaimed) {
      return false;
    }

    try {
      final reward = DailyQuestsState.masterChestRewardCoins * rewardMultiplier;
      final txId = const Uuid().v4();

      await _coinService.creditCoins(
        reward,
        source: 'daily_quest_master_chest',
        txId: txId,
      );

      final nextState = DailyQuestsState(
        dateKey: state.dateKey,
        quests: state.quests,
        isMasterChestClaimed: true,
      );
      await _persistState(nextState);
      return true;
    } catch (e) {
      debugPrint('QuestService claimMasterChest error: $e');
      return false;
    }
  }

  Future<void> _persistState(DailyQuestsState state) async {
    final data = {
      'dateKey': state.dateKey,
      'isMasterChestClaimed': state.isMasterChestClaimed,
      'quests': state.quests.map((q) => q.toJson()).toList(),
    };
    await _storage.write(key: _keyQuestsState, value: jsonEncode(data));
  }
}
