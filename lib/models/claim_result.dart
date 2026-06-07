class ClaimResult {
  final bool success;
  final int amount;
  final int newBalance;
  final int consecutiveDays;
  final String? errorMessage;

  ClaimResult({
    required this.success,
    required this.amount,
    required this.newBalance,
    required this.consecutiveDays,
    this.errorMessage,
  });

  factory ClaimResult.fromMap(Map<String, dynamic> map) {
    return ClaimResult(
      success: map['success'] as bool? ?? false,
      amount: map['amount'] as int? ?? 0,
      newBalance: map['balance'] as int? ?? map['new_balance'] as int? ?? 0,
      consecutiveDays: map['consecutive_days'] as int? ?? map['consecutiveDays'] as int? ?? 0,
      errorMessage: map['error'] as String?,
    );
  }

  factory ClaimResult.offlineClaim({required int amount}) {
    return ClaimResult(
      success: true,
      amount: amount,
      newBalance: 0, // Not verified offline
      consecutiveDays: 1,
    );
  }
}
