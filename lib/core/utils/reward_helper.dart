import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../widgets/two_tier_reward_dialog.dart';
import '../../widgets/congratulations_dialog.dart';

/// Helper function to show two-tier reward choice dialog and handle ad display.
/// 
/// This implements the "Normal + Double" strategy:
/// - Normal: baseReward + Rewarded Interstitial (shorter ad)
/// - Double: baseReward * 2 + Rewarded Ad (longer ad)
Future<void> showRewardChoice({
  required BuildContext context,
  required String featureName,
  required int baseReward,
  required AdPlacement quickPlacement,
  required AdPlacement premiumPlacement,
  required Future<void> Function(int coins) onSuccess,
  Function()? onCancel,
}) async {
  final choice = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => TwoTierRewardDialog(
      title: featureName,
      description: 'Choose your reward',
      quickReward: baseReward,
      quickLabel: 'Claim $baseReward RBX',
      premiumReward: baseReward * 2,
      onQuickClaim: () => Navigator.pop(context, 'quick'),
      onPremiumClaim: () => Navigator.pop(context, 'premium'),
    ),
  );

  if (!context.mounted || choice == null) {
    onCancel?.call();
    return;
  }

  final container = ProviderScope.containerOf(context);
  final adNotifier = container.read(adProvider.notifier);

  if (choice == 'quick') {
    // Show rewarded interstitial (shorter ad, ~20s)
    await adNotifier.showRewardedInterstitial(
      quickPlacement,
      onReward: (_) async {
        await onSuccess(baseReward);
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CongratulationsDialog(earnedCoins: baseReward),
          );
        }
      },
      onAdFailed: (error) async {
        await onSuccess(baseReward);
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CongratulationsDialog(earnedCoins: baseReward),
          );
        }
      },
    );
  } else if (choice == 'premium') {
    // Show rewarded ad (longer ad, ~40s, higher eCPM)
    await adNotifier.showOptionalAd(
      premiumPlacement,
      onReward: (_) async {
        await onSuccess(baseReward * 2);
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CongratulationsDialog(earnedCoins: baseReward * 2),
          );
        }
      },
      onAdFailed: (error) async {
        await onSuccess(baseReward);
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CongratulationsDialog(earnedCoins: baseReward),
          );
        }
      },
    );
  }
}
