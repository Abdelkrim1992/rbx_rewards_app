class UserProfile {
  final String id;
  final int coins;
  final int totalEarned;
  final int consecutiveDays;
  final int gamesPlayed;
  final int offersCompleted;
  final String displayName;
  final String? profilePhotoUrl;
  final DateTime? dailyRewardClaimedAt;

  final int totalSpent;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.coins,
    required this.totalEarned,
    required this.consecutiveDays,
    required this.gamesPlayed,
    required this.offersCompleted,
    required this.displayName,
    this.profilePhotoUrl,
    this.dailyRewardClaimedAt,
    this.totalSpent = 0,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      coins: json['balance'] as int? ?? json['coins'] as int? ?? 0,
      totalEarned: json['total_earned'] as int? ?? 0,
      consecutiveDays: json['consecutive_days'] as int? ?? 0,
      gamesPlayed: json['games_played'] as int? ?? 0,
      offersCompleted: json['offers_completed'] as int? ?? 0,
      displayName: json['display_name'] as String? ?? 'Player',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      dailyRewardClaimedAt: json['daily_reward_claimed_at'] != null
          ? DateTime.tryParse(json['daily_reward_claimed_at'] as String)
          : null,
      totalSpent: json['total_spent'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  UserProfile copyWith({
    String? id,
    int? coins,
    int? totalEarned,
    int? consecutiveDays,
    int? gamesPlayed,
    int? offersCompleted,
    String? displayName,
    String? profilePhotoUrl,
    DateTime? dailyRewardClaimedAt,
    int? totalSpent,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      coins: coins ?? this.coins,
      totalEarned: totalEarned ?? this.totalEarned,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      offersCompleted: offersCompleted ?? this.offersCompleted,
      displayName: displayName ?? this.displayName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      dailyRewardClaimedAt: dailyRewardClaimedAt ?? this.dailyRewardClaimedAt,
      totalSpent: totalSpent ?? this.totalSpent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
