import 'package:flutter/material.dart';
import '../../models/ad_models.dart';
import '../../widgets/reward_claim_dialog.dart';

/// Helper function to show modern reward claim dialog with 2X video ad multiplier.
/// 
/// Replaces the legacy two-step dialog with an industry-standard unified celebration:
/// - Animated odometer count-up
/// - Dynamic goal-gradient progress tracking
/// - One-tap regular claim or 2X Double-Up via rewarded video
Future<void> showRewardChoice({
  required BuildContext context,
  required String featureName,
  required int baseReward,
  required AdPlacement quickPlacement,
  required AdPlacement premiumPlacement,
  required Future<void> Function(int coins) onSuccess,
  Function()? onCancel,
  String? heroAsset,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RewardClaimDialog(
      title: featureName,
      baseReward: baseReward,
      adPlacement: premiumPlacement,
      heroAsset: heroAsset,
      onClaimCompleted: (coins) async {
        await onSuccess(coins);
      },
      onCancel: onCancel,
    ),
  );
}
