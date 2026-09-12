/// Model representing the user's referral status and reward statistics.
class ReferralState {
  final String myReferralCode;
  final String? referredByCode;
  final bool hasRedeemedCode;
  final int totalFriendsInvited;
  final int totalCoinsEarned;

  static const int welcomeBonusCoins = 100;
  static const int inviterBonusCoins = 200;

  const ReferralState({
    required this.myReferralCode,
    this.referredByCode,
    required this.hasRedeemedCode,
    required this.totalFriendsInvited,
    required this.totalCoinsEarned,
  });

  ReferralState copyWith({
    String? myReferralCode,
    String? referredByCode,
    bool? hasRedeemedCode,
    int? totalFriendsInvited,
    int? totalCoinsEarned,
  }) {
    return ReferralState(
      myReferralCode: myReferralCode ?? this.myReferralCode,
      referredByCode: referredByCode ?? this.referredByCode,
      hasRedeemedCode: hasRedeemedCode ?? this.hasRedeemedCode,
      totalFriendsInvited: totalFriendsInvited ?? this.totalFriendsInvited,
      totalCoinsEarned: totalCoinsEarned ?? this.totalCoinsEarned,
    );
  }

  factory ReferralState.initial(String code) {
    return ReferralState(
      myReferralCode: code,
      referredByCode: null,
      hasRedeemedCode: false,
      totalFriendsInvited: 0,
      totalCoinsEarned: 0,
    );
  }
}

/// Result of attempting to redeem a referral code.
class ReferralRedeemResult {
  final bool isSuccess;
  final String message;
  final int coinsAwarded;

  const ReferralRedeemResult({
    required this.isSuccess,
    required this.message,
    this.coinsAwarded = 0,
  });
}
