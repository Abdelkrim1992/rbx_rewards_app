import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../widgets/mini_game_reward_dialog.dart';
import '../../widgets/game_prefs.dart';

/// Helper function to show game-specific two-tier reward choice dialog and handle ad display.
///
/// Refactored to use [MiniGameRewardDialog] and support customized styling.
Future<void> showGameRewardChoice({
  required BuildContext context,
  required String featureName,
  required int baseReward,
  required AdPlacement quickPlacement,
  required AdPlacement premiumPlacement,
  required Future<void> Function(int coins) onSuccess,
  Function()? onCancel,
  String? description,
  IconData? icon,
  Color? iconBgColor,
  Color? iconColor,
  Gradient? premiumGradient,
  Color? quickTextColor,
  Color? quickBorderColor,
  bool enableQuickAd = true,
}) async {
  final container = ProviderScope.containerOf(context);
  final adNotifier = container.read(adProvider.notifier);

  final gameKey = featureName.toLowerCase().replaceAll(' ', '_');
  await GamePrefs.incrementGamePlayCount(gameKey);
  final playCount = await GamePrefs.getGamePlayCount(gameKey);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => MiniGameRewardDialog(
      title: featureName,
      description: description ?? 'Choose your reward',
      quickReward: baseReward,
      quickLabel: 'Claim $baseReward RBX',
      premiumReward: baseReward * 2,
      icon: icon,
      iconBgColor: iconBgColor,
      iconColor: iconColor,
      premiumGradient: premiumGradient,
      quickTextColor: quickTextColor,
      quickBorderColor: quickBorderColor,
      onQuickClaim: () async {
        if (enableQuickAd && playCount % 3 == 0) {
          await adNotifier.showRewardedInterstitial(
            quickPlacement,
            onReward: (_) async {
              await onSuccess(baseReward);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            onAdFailed: (error) async {
              await onSuccess(baseReward);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          );
        } else {
          await onSuccess(baseReward);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      onPremiumClaim: () async {
        await adNotifier.showOptionalAd(
          premiumPlacement,
          onReward: (_) async {
            await onSuccess(baseReward * 2);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          onAdFailed: (error) async {
            await onSuccess(baseReward);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    ),
  );
}
