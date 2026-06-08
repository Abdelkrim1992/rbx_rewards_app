class SpinState {
  final int spinsRemaining;
  final int? cooldownEndMs;

  SpinState({
    required this.spinsRemaining,
    this.cooldownEndMs,
  });

  factory SpinState.fromJson(Map<String, dynamic> json) {
    final int? relativeCooldownMs = (json['cooldownEnd'] as num?)?.toInt() ?? (json['cooldown_end'] as num?)?.toInt();
    final int? absoluteCooldownMs = (relativeCooldownMs != null && relativeCooldownMs > 0)
        ? DateTime.now().millisecondsSinceEpoch + relativeCooldownMs
        : null;

    return SpinState(
      spinsRemaining: (json['spinsRemaining'] as num?)?.toInt() ?? (json['spins_remaining'] as num?)?.toInt() ?? 0,
      cooldownEndMs: absoluteCooldownMs,
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
    final int? relativeCooldownMs = (json['cooldownEnd'] as num?)?.toInt() ?? (json['cooldown_end'] as num?)?.toInt();
    final int? absoluteCooldownMs = (relativeCooldownMs != null && relativeCooldownMs > 0)
        ? DateTime.now().millisecondsSinceEpoch + relativeCooldownMs
        : null;

    return SpinResult(
      spinsRemaining: (json['spinsRemaining'] as num?)?.toInt() ?? (json['spins_remaining'] as num?)?.toInt() ?? 0,
      cooldownEnd: absoluteCooldownMs,
      coinsEarned: (json['coinsEarned'] as num?)?.toInt() ?? (json['coins_earned'] as num?)?.toInt() ?? 0,
    );
  }
}
