import 'package:flutter/material.dart';
import '../models/ad_models.dart';
import 'reward_claim_dialog.dart';

/// Compatibility layer replacing the legacy two-tier dialog with the modern RewardClaimDialog.
/// Ad video is ONLY shown in the double button.
class TwoTierRewardDialog extends StatelessWidget {
  final String title;
  final String description;
  final int quickReward;
  final int premiumReward;
  final Future<void> Function() onQuickClaim;
  final Future<void> Function() onPremiumClaim;
  final String quickLabel;
  final String premiumLabel;

  // Customization parameters kept for API compatibility
  final IconData? icon;
  final Widget? customIcon;
  final Color? iconBgColor;
  final Color? iconColor;
  final Gradient? premiumGradient;
  final Color? quickTextColor;
  final Color? quickBorderColor;
  final Color? quickBgColor;

  const TwoTierRewardDialog({
    super.key,
    required this.title,
    required this.description,
    required this.quickReward,
    required this.premiumReward,
    required this.onQuickClaim,
    required this.onPremiumClaim,
    this.quickLabel = 'Quick Claim',
    this.premiumLabel = 'Watch a video for more reward',
    this.icon,
    this.customIcon,
    this.iconBgColor,
    this.iconColor,
    this.premiumGradient,
    this.quickTextColor,
    this.quickBorderColor,
    this.quickBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return RewardClaimDialog(
      title: title,
      subtitle: description,
      baseReward: quickReward,
      adPlacement: AdPlacement.doubleReward,
      onClaimCompleted: (coins) async {
        if (coins > quickReward) {
          await onPremiumClaim();
        } else {
          await onQuickClaim();
        }
      },
    );
  }
}
