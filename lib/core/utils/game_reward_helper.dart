import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../widgets/two_tier_reward_dialog.dart';
import '../../widgets/ad_reward_dialog.dart';
import '../../widgets/game_prefs.dart';

/// Helper function to show game-specific two-tier reward choice dialog and handle ad display.
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

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => TwoTierRewardDialog(
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
        final quickClaimCount = await GamePrefs.incrementQuickClaimCount(gameKey);
        if (enableQuickAd && (quickClaimCount % 3 == 0)) {
          bool hasHandled = false;
          await adNotifier.showRewardedInterstitial(
            quickPlacement,
            onReward: (_) async {
              hasHandled = true;
              await onSuccess(baseReward);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            onAdDismissed: () async {
              if (!hasHandled) {
                hasHandled = true;
                await onSuccess(baseReward);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            onAdFailed: (error) async {
              if (!hasHandled) {
                hasHandled = true;
                await onSuccess(baseReward);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
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
        bool hasHandled = false;
        await adNotifier.showOptionalAd(
          premiumPlacement,
          onReward: (_) async {
            hasHandled = true;
            await onSuccess(baseReward * 2);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          onAdDismissed: () async {
            if (!hasHandled) {
              hasHandled = true;
              await onSuccess(baseReward);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          onAdFailed: (error) async {
            if (!hasHandled) {
              hasHandled = true;
              await onSuccess(baseReward);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
        );
      },
    ),
  );
}

/// Helper to play a rewarded video ad for "Play Again" across all mini-games,
/// with automatic web / test fallback to [AdRewardDialog] so a video ad is ALWAYS shown.
Future<void> showPlayAgainVideoAd({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onComplete,
}) async {
  final adNotifier = ref.read(adProvider.notifier);

  // If on web, Google Mobile Ads is not supported so show AdRewardDialog directly
  if (kIsWeb) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdRewardDialog(
        title: 'REWARDED VIDEO AD',
        subtitle: 'Ad Completed! Ready to play!',
        buttonText: 'PLAY AGAIN',
        onRewardGranted: () {
          adNotifier.recordOptionalAdWatched();
        },
      ),
    );
    onComplete();
    return;
  }

  bool completed = false;

  void handleFinish() {
    if (!completed) {
      completed = true;
      onComplete();
    }
  }

  await adNotifier.showRewardedInterstitial(
    AdPlacement.miniGameCompletion,
    onReward: (_) async {},
    onAdDismissed: () {
      handleFinish();
    },
    onAdFailed: (error) async {
      debugPrint('Native ad unavailable ($error), displaying video ad dialog');
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AdRewardDialog(
            title: 'REWARDED VIDEO AD',
            subtitle: 'Ad Completed! Ready to play!',
            buttonText: 'PLAY AGAIN',
            onRewardGranted: () {
              adNotifier.recordOptionalAdWatched();
            },
          ),
        );
      }
      handleFinish();
    },
  );
}
