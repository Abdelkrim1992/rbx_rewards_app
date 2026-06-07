class UserProfile {
  final String id;
  final int coins;
  final int totalEarned;
  final int consecutiveDays;
  final int gamesPlayed;
  final int offersCompleted;
  final String displayName;
  final String? profilePhotoUrl;

  UserProfile({
    required this.id,
    required this.coins,
    required this.totalEarned,
    required this.consecutiveDays,
    required this.gamesPlayed,
    required this.offersCompleted,
    required this.displayName,
    this.profilePhotoUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      coins: json['coins'] as int? ?? 0,
      totalEarned: json['total_earned'] as int? ?? 0,
      consecutiveDays: json['consecutive_days'] as int? ?? 0,
      gamesPlayed: json['games_played'] as int? ?? 0,
      offersCompleted: json['offers_completed'] as int? ?? 0,
      displayName: json['display_name'] as String? ?? 'Player',
      profilePhotoUrl: json['profile_photo_url'] as String?,
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
    );
  }
}
