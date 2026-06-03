/// Badge awarded for ad-watching milestones.
class Badge {
  final String id;
  final String name;
  final String description;
  final String iconEmoji;
  final int rewardAmount;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconEmoji,
    required this.rewardAmount,
  });
}

/// Predefined ad-watching badges.
class Badges {
  static const adWatcher = Badge(
    id: 'ad_watcher',
    name: 'Ad Watcher',
    description: 'Watched 5 ads in one day',
    iconEmoji: '🥉',
    rewardAmount: 100,
  );

  static const adMaster = Badge(
    id: 'ad_master',
    name: 'Ad Master',
    description: 'Watched 15 ads in one day',
    iconEmoji: '🥈',
    rewardAmount: 250,
  );

  static const adChampion = Badge(
    id: 'ad_champion',
    name: 'Ad Champion',
    description: 'Watched 25 ads in one day',
    iconEmoji: '🥇',
    rewardAmount: 500,
  );

  static const weekStreak = Badge(
    id: 'week_streak',
    name: '7-Day Streak',
    description: '7 consecutive days of 15+ ads',
    iconEmoji: '🔥',
    rewardAmount: 1000,
  );

  static const List<Badge> all = [adWatcher, adMaster, adChampion, weekStreak];
}
