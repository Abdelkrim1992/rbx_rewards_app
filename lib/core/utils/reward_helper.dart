import 'package:flutter/material.dart';
import '../../models/ad_models.dart';
import '../../widgets/reward_claim_dialog.dart';

/// Helper function to show modern reward claim dialog with configurable video ad multiplier (x3 or x4).
/// 
/// Follows the Phase-6 unified reward model:
/// - Animated odometer count-up
/// - Dynamic goal-gradient progress tracking
/// - One-tap regular claim or Multiplied Reward via rewarded video
Future<void> showRewardChoice({
  required BuildContext context,
  required String featureName,
  required int baseReward,
  required AdPlacement quickPlacement,
  required AdPlacement premiumPlacement,
  required Future<void> Function(int coins) onSuccess,
  Function()? onCancel,
  String? heroAsset,
  int? multiplier,
  int? premiumReward,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RewardClaimDialog(
      title: featureName,
      baseReward: baseReward,
      adPlacement: premiumPlacement,
      heroAsset: heroAsset,
      multiplier: multiplier,
      premiumReward: premiumReward,
      onClaimCompleted: (coins) async {
        await onSuccess(coins);
      },
      onCancel: onCancel,
    ),
  );
}
