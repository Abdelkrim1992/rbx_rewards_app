class GameSubmitResult {
  final bool success;
  final String? error;
  final bool queued;
  final int coinsEarned;

  GameSubmitResult({
    required this.success,
    this.error,
    this.queued = false,
    this.coinsEarned = 0,
  });

  factory GameSubmitResult.fromMap(Map<String, dynamic> map) {
    return GameSubmitResult(
      success: map['success'] as bool? ?? (map['error'] == null),
      error: map['error'] as String?,
      queued: map['queued'] as bool? ?? false,
      coinsEarned: map['credited'] as int? ?? map['coins_earned'] as int? ?? 0,
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final int score;
  final String? profilePhotoUrl;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.score,
    this.profilePhotoUrl,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      userId: map['user_id'] as String? ?? map['id'] as String? ?? '',
      displayName: map['display_name'] as String? ?? 'Player',
      score: map['score'] as int? ?? map['total_earned'] as int? ?? 0,
      profilePhotoUrl: map['profile_photo_url'] as String?,
    );
  }
}
