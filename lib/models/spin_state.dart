class SpinState {
  final int spinsRemaining;
  final int? cooldownEndMs;

  SpinState({
    required this.spinsRemaining,
    this.cooldownEndMs,
  });

  factory SpinState.fromJson(Map<String, dynamic> json) {
    return SpinState(
      spinsRemaining: json['spinsRemaining'] as int? ?? json['spins_remaining'] as int? ?? 0,
      cooldownEndMs: json['cooldownEnd'] as int? ?? json['cooldown_end'] as int?,
    );
  }
}

class SpinResult {
  final int spinsRemaining;
  final int? cooldownEnd;
  final int coinsEarned;

  SpinResult({
    required this.spinsRemaining,
    this.cooldownEnd,
    required this.coinsEarned,
  });

  factory SpinResult.fromJson(Map<String, dynamic> json) {
    return SpinResult(
      spinsRemaining: json['spinsRemaining'] as int? ?? json['spins_remaining'] as int? ?? 0,
      cooldownEnd: json['cooldownEnd'] as int? ?? json['cooldown_end'] as int?,
      coinsEarned: json['coinsEarned'] as int? ?? json['coins_earned'] as int? ?? 0,
    );
  }
}
