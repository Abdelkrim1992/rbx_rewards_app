enum QuestType {
  playGame,
  scratchCard,
  watchVideoOrChest,
}

/// A single daily quest task
class DailyQuest {
  final String id;
  final QuestType type;
  final String title;
  final String icon;
  final int targetCount;
  final int currentProgress;
  final int rewardCoins;

  const DailyQuest({
    required this.id,
    required this.type,
    required this.title,
    required this.icon,
    required this.targetCount,
    required this.currentProgress,
    required this.rewardCoins,
  });

  bool get isCompleted => currentProgress >= targetCount;
  double get progressRatio => (currentProgress / targetCount).clamp(0.0, 1.0);

  DailyQuest copyWith({
    int? currentProgress,
  }) {
    return DailyQuest(
      id: id,
      type: type,
      title: title,
      icon: icon,
      targetCount: targetCount,
      currentProgress: currentProgress ?? this.currentProgress,
      rewardCoins: rewardCoins,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'icon': icon,
        'targetCount': targetCount,
        'currentProgress': currentProgress,
        'rewardCoins': rewardCoins,
      };

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: json['id'] as String,
      type: QuestType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuestType.playGame,
      ),
      title: json['title'] as String,
      icon: json['icon'] as String,
      targetCount: json['targetCount'] as int,
      currentProgress: json['currentProgress'] as int,
      rewardCoins: json['rewardCoins'] as int,
    );
  }
}

/// Aggregated state for all daily quests and the Master Milestone Chest
class DailyQuestsState {
  final String dateKey;
  final List<DailyQuest> quests;
  final bool isMasterChestClaimed;

  static const int masterChestRewardCoins = 150;

  const DailyQuestsState({
    required this.dateKey,
    required this.quests,
    required this.isMasterChestClaimed,
  });

  bool get areAllCompleted => quests.every((q) => q.isCompleted);
  int get completedCount => quests.where((q) => q.isCompleted).length;

  static List<DailyQuest> defaultQuests() => const [
        DailyQuest(
          id: 'quest_games',
          type: QuestType.playGame,
          title: 'Play 3 Mini-Games',
          icon: '🎮',
          targetCount: 3,
          currentProgress: 0,
          rewardCoins: 30,
        ),
        DailyQuest(
          id: 'quest_scratch',
          type: QuestType.scratchCard,
          title: 'Scratch 2 Cards',
          icon: '🎟️',
          targetCount: 2,
          currentProgress: 0,
          rewardCoins: 30,
        ),
        DailyQuest(
          id: 'quest_videos',
          type: QuestType.watchVideoOrChest,
          title: 'Watch 2 Videos or Chests',
          icon: '⚡',
          targetCount: 2,
          currentProgress: 0,
          rewardCoins: 40,
        ),
      ];
}
