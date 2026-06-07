class ChestResult {
  final bool success;
  final int coinsEarned;
  final String? errorMessage;

  ChestResult({
    required this.success,
    required this.coinsEarned,
    this.errorMessage,
  });

  factory ChestResult.fromMap(Map<String, dynamic> map) {
    return ChestResult(
      success: map['success'] as bool? ?? false,
      coinsEarned: map['coins_earned'] as int? ?? map['coinsEarned'] as int? ?? 0,
      errorMessage: map['error'] as String?,
    );
  }
}
