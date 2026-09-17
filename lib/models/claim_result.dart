class ClaimResult {
  final bool success;
  final int amount;
  final int newBalance;
  final int consecutiveDays;
  final String? errorMessage;

  final bool isOffline;

  ClaimResult({
    required this.success,
    required this.amount,
    required this.newBalance,
    required this.consecutiveDays,
    this.errorMessage,
    this.isOffline = false,
  });

  factory ClaimResult.fromMap(Map<String, dynamic> map) {
    final dynamic dataRaw = map['data'];
    final Map<String, dynamic>? data = dataRaw is Map<String, dynamic>
        ? dataRaw
        : (dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : null);

    return ClaimResult(
      success: (map['success'] as bool?) ?? (data?['success'] as bool?) ?? false,
      amount: (map['amount'] as int?) ?? (data?['amount'] as int?) ?? 0,
      newBalance: (map['balance'] as int?) ??
          (map['new_balance'] as int?) ??
          (data?['balance'] as int?) ??
          (data?['new_balance'] as int?) ??
          0,
      consecutiveDays: (map['consecutive_days'] as int?) ??
          (map['consecutiveDays'] as int?) ??
          (data?['consecutive_days'] as int?) ??
          (data?['consecutiveDays'] as int?) ??
          0,
      errorMessage: (map['error'] as String?) ?? (data?['error'] as String?),
      isOffline: false,
    );
  }

  factory ClaimResult.offlineClaim({required int amount}) {
    return ClaimResult(
      success: true,
      amount: amount,
      newBalance: 0, // Not verified offline
      consecutiveDays: 1,
      isOffline: true,
    );
  }
}
