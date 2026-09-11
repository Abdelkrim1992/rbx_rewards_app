import 'package:flutter/material.dart';
import 'two_tier_reward_dialog.dart';

/// Two-tier reward dialog customized for mini games.
/// Offers users a choice:
/// - Quick Claim (standard reward, zero ads)
/// - Premium Claim (higher reward + rewarded ad)
///
/// Delegates directly to [TwoTierRewardDialog] for unified behavior and styling.
class MiniGameRewardDialog extends StatelessWidget {
  final String title;
  final String description;
  final int quickReward;
  final int premiumReward;
  final Future<void> Function() onQuickClaim;
  final Future<void> Function() onPremiumClaim;
  final String quickLabel;
  final String premiumLabel;

  // Customization parameters
  final IconData? icon;
  final Widget? customIcon;
  final Color? iconBgColor;
  final Color? iconColor;
  final Gradient? premiumGradient;
  final Color? quickTextColor;
  final Color? quickBorderColor;
  final Color? quickBgColor;

  const MiniGameRewardDialog({
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
    return TwoTierRewardDialog(
      title: title,
      description: description,
      quickReward: quickReward,
      premiumReward: premiumReward,
      onQuickClaim: onQuickClaim,
      onPremiumClaim: onPremiumClaim,
      quickLabel: quickLabel,
      premiumLabel: premiumLabel,
      icon: icon,
      customIcon: customIcon,
      iconBgColor: iconBgColor,
      iconColor: iconColor,
      premiumGradient: premiumGradient,
      quickTextColor: quickTextColor,
      quickBorderColor: quickBorderColor,
      quickBgColor: quickBgColor,
    );
  }
}

