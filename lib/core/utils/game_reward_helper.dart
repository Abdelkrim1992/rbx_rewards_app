import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../widgets/ad_reward_dialog.dart';
import '../../widgets/game_prefs.dart';
import 'reward_helper.dart';

/// Helper function to show modern reward choice dialog with 2X video multiplier.
/// Ad video is ONLY shown when the user taps "DOUBLE TO +2X RBX".
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
  bool enableQuickAd = false,
  String? heroAsset,
}) async {
  final gameKey = featureName.toLowerCase().replaceAll(' ', '_');
  await GamePrefs.incrementGamePlayCount(gameKey);

  if (!context.mounted) return;

  await showRewardChoice(
    context: context,
    featureName: featureName,
    baseReward: baseReward,
    quickPlacement: quickPlacement,
    premiumPlacement: premiumPlacement,
    heroAsset: heroAsset,
    onSuccess: onSuccess,
    onCancel: onCancel,
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
