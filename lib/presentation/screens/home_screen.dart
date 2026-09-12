import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/coin_provider.dart';
import '../providers/user_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/reward_provider.dart';
import '../providers/ad_provider.dart';
import '../providers/providers.dart';
import '../providers/mega_chest_provider.dart';
import '../providers/reward_catalog_provider.dart';
import '../../models/ad_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/streak_saver_sheet.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/congratulations_dialog.dart';
import '../../widgets/coin_burst.dart';
import '../../core/utils/reward_helper.dart';

// Screen Navigation Targets
import 'chest_screen.dart';
import 'scratch_card_screen.dart';
import 'tap_tap_game_screen.dart';
import 'flappy_jump_game_screen.dart';
import 'math_quiz_screen.dart';
import 'flip_card_game_screen.dart';
import 'quizzes_screen.dart';

// Modular Home Screen Components
import 'home/widgets/home_goal_card.dart';
import 'home/widgets/home_daily_hub_card.dart';
import 'home/widgets/home_quick_actions_grid.dart';
import 'home/widgets/home_games_section.dart';
import 'home/widgets/home_mega_chest_card.dart';
import 'home/widgets/home_referral_card.dart';
import '../providers/quest_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int) onNavTap;
  final VoidCallback onSpinTap;

  const HomeScreen({
    super.key,
    required this.onNavTap,
    required this.onSpinTap,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isProcessing = false;
  bool _showCoinBurst = false;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _completeClaim({bool saveStreak = false}) async {
    final userProfile = ref.read(userProfileProvider);
    final isWithinFirstWeek = userProfile.consecutiveDays < 7;
    final nextDay = (userProfile.consecutiveDays % 7) + 1;
    final rewardAmount = isWithinFirstWeek
        ? (nextDay == 7 ? 100 : 10 + (nextDay * 5))
        : 15;

    await showRewardChoice(
      context: context,
      featureName: nextDay == 7 ? 'Day 7 Jackpot' : 'Daily Streak Bonus',
      baseReward: rewardAmount,
      quickPlacement: AdPlacement.dailyReward,
      premiumPlacement: AdPlacement.dailyReward,
      heroAsset: nextDay == 7 ? AppAssets.megaChest : AppAssets.goldRbxCoin,
      onSuccess: (coins) async {
        await ref.read(dailyRewardCooldownProvider.notifier).claimDaily(
              amount: coins,
              saveStreak: saveStreak,
            );
        ref.invalidate(userProfileStreamProvider);
      },
    );
  }

  Future<void> _promptStreakSaver(int consecutiveDays) async {
    final nextDay = (consecutiveDays % 7) + 1;
    final rewardAmount = consecutiveDays < 7
        ? (nextDay == 7 ? 100 : 10 + (nextDay * 5))
        : 15;

    await StreakSaverSheet.show(
      context: context,
      currentStreak: consecutiveDays,
      nextDay: nextDay,
      rewardAmount: rewardAmount,
      onSaveWithAd: () async {
        Navigator.of(context).pop();
        setState(() => _isProcessing = true);
        await ref.read(adProvider.notifier).showOptionalAd(
          AdPlacement.dailyReward,
          onReward: (_) async {
            await _completeClaim(saveStreak: true);
          },
          onAdFailed: (error) async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not load ad: $error'),
                  backgroundColor: AppColors.purple,
                ),
              );
            }
          },
        );
        if (mounted) setState(() => _isProcessing = false);
      },
      onResetStreak: () async {
        Navigator.of(context).pop();
        setState(() => _isProcessing = true);
        await _completeClaim(saveStreak: false);
        if (mounted) setState(() => _isProcessing = false);
      },
    );
  }

  void _claimDaily() async {
    if (_isProcessing) return;
    final coolingDown = ref.read(dailyRewardCooldownProvider).inSeconds > 0;
    if (coolingDown) return;

    final userProfile = ref.read(userProfileProvider);
    DateTime? claimedAt = userProfile.dailyRewardClaimedAt;
    claimedAt ??=
        await ref.read(secureRepositoryProvider).getDailyRewardClaimedAtLocal();

    final isStreakBroken = userProfile.consecutiveDays > 0 &&
        claimedAt != null &&
        DateTime.now().difference(claimedAt).inHours >= 48;

    if (isStreakBroken) {
      if (!mounted) return;
      await _promptStreakSaver(userProfile.consecutiveDays);
      return;
    }

    setState(() => _isProcessing = true);
    await _completeClaim();
    if (mounted) setState(() => _isProcessing = false);
  }

  void _onWatchAdToEarn() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await ref.read(adProvider.notifier).showOptionalAd(
      AdPlacement.doubleReward,
      onReward: (_) async {
        await ref.read(coinProvider.notifier).credit(50, 'watch_video');
        ref.invalidate(userProfileStreamProvider);
        ref.read(questStateProvider.notifier).recordVideoOrChest();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const CongratulationsDialog(
              earnedCoins: 50,
              title: 'Video Reward',
              heroAsset: AppAssets.watchEarnIcon,
            ),
          );
        }
      },
      onAdFailed: (error) async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load video: $error'),
              backgroundColor: AppColors.purple,
            ),
          );
        }
      },
    );

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _completeMegaChestClaim() async {
    if (_isProcessing) return;
    await showRewardChoice(
      context: context,
      featureName: 'Chest Reward',
      baseReward: 1000,
      quickPlacement: AdPlacement.chestOpen,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.megaChest,
      onSuccess: (coins) async {
        setState(() => _isProcessing = true);
        final success =
            await ref.read(megaChestMilestoneProvider.notifier).claimReward();
        if (success && coins > 1000) {
          await ref.read(coinProvider.notifier).credit(coins - 1000, 'mega_chest_double');
        }
        ref.invalidate(userProfileStreamProvider);
        if (mounted) setState(() => _isProcessing = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinProvider);
    final userProfile = ref.watch(userProfileProvider);
    final activeGoal = ref.watch(activeGoalRewardProvider);
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    final dailyCooldown = ref.watch(dailyRewardCooldownProvider);
    final isDailyClaimed = dailyCooldown.inSeconds > 0;
    final capService = ref.watch(dailyCapServiceProvider);
    final isDailyCapReached = capService.isCapReachedFor('daily_reward');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isDailyBlocked =
        isDailyClaimed || isDailyCapReached || isFeaturesCapReached;

    final isStreakBroken = userProfile.consecutiveDays > 0 &&
        userProfile.dailyRewardClaimedAt != null &&
        DateTime.now().difference(userProfile.dailyRewardClaimedAt!).inHours >=
            48;

    final gamesList = [
      HomeGameItemData(
        id: 'tap_tap',
        title: 'Tap Tap',
        subtitle: 'Tap & collect',
        imageUrl: AppAssets.tapTapGame,
        remainingCoins: capService.getRemainingCap('tap_tap'),
        bgColor: const Color(0xFFEAF3FF),
        onTap: () async {
          if (!isOnline) return;
          final earned = await Navigator.of(context).push<int>(
            MaterialPageRoute(builder: (_) => const TapTapGameScreen()),
          );
          if (earned != null && earned > 0) {
            ref.invalidate(userProfileStreamProvider);
            ref.read(questStateProvider.notifier).recordGamePlayed();
          }
        },
      ),
      HomeGameItemData(
        id: 'math_quiz',
        title: 'Math Quiz',
        subtitle: 'Solve & win',
        imageUrl: AppAssets.quizMasterGame,
        remainingCoins: capService.getRemainingCap('math_quiz'),
        bgColor: const Color(0xFFE3F8EB),
        onTap: () async {
          if (!isOnline) return;
          final earned = await Navigator.of(context).push<int>(
            MaterialPageRoute(builder: (_) => const MathQuizScreen()),
          );
          if (earned != null && earned > 0) {
            ref.invalidate(userProfileStreamProvider);
            ref.read(questStateProvider.notifier).recordGamePlayed();
          }
        },
      ),
      HomeGameItemData(
        id: 'flappy_jump',
        title: 'Flappy Jump',
        subtitle: 'Fly & score',
        imageUrl: AppAssets.flappyJumpGame,
        remainingCoins: capService.getRemainingCap('flappy_jump'),
        bgColor: const Color(0xFFFFF3E3),
        onTap: () async {
          if (!isOnline) return;
          final earned = await Navigator.of(context).push<int>(
            MaterialPageRoute(builder: (_) => const FlappyJumpGameScreen()),
          );
          if (earned != null && earned > 0) {
            ref.invalidate(userProfileStreamProvider);
            ref.read(questStateProvider.notifier).recordGamePlayed();
          }
        },
      ),
      HomeGameItemData(
        id: 'flip_card',
        title: 'Flip Cards',
        subtitle: 'Match pairs',
        imageUrl: AppAssets.memoryMatchGame,
        remainingCoins: capService.getRemainingCap('flip_card'),
        bgColor: const Color(0xFFFFE8F0),
        onTap: () async {
          if (!isOnline) return;
          final earned = await Navigator.of(context).push<int>(
            MaterialPageRoute(builder: (_) => const FlipCardGameScreen()),
          );
          if (earned != null && earned > 0) {
            ref.invalidate(userProfileStreamProvider);
            ref.read(questStateProvider.notifier).recordGamePlayed();
          }
        },
      ),
      HomeGameItemData(
        id: 'quizzes',
        title: 'Trivia Master',
        subtitle: 'Answer & earn',
        imageUrl: AppAssets.quizMasterQuickActions,
        remainingCoins: capService.getRemainingCap('quizzes'),
        bgColor: const Color(0xFFEDE9FE),
        onTap: () async {
          if (!isOnline) return;
          final earned = await Navigator.of(context).push<int>(
            MaterialPageRoute(builder: (_) => const QuizzesScreen()),
          );
          if (earned != null && earned > 0) {
            ref.invalidate(userProfileStreamProvider);
            ref.read(questStateProvider.notifier).recordGamePlayed();
          }
        },
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: RefreshableScrollView(
                    padding: const EdgeInsets.only(top: 2, bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App Logo & Profile Header
                        RbxAppHeader(onNavTap: widget.onNavTap),

                        // Offline banner if disconnected
                        if (!isOnline)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppLayout.screenPadding,
                              vertical: 6,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFFFE69C)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.wifi_off,
                                    color: Color(0xFF856404),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'You are offline. Earning features are disabled.',
                                      style: TextStyle(
                                        color: Color(0xFF856404),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Welcome greeting
                        const RbxScreenTitle(
                          title: 'Welcome back',
                          subtitle: 'Earn coins & redeem for Roblox rewards',
                        ),

                        // Goal-Gradient Balance Progress Card
                        HomeGoalCard(
                          coins: coins,
                          targetCoins: activeGoal.targetCoins,
                          targetTitle: activeGoal.title,
                          onRedeemTap: () => widget.onNavTap(2),
                        ),
                        const SizedBox(height: AppLayout.sectionSpacing),

                        // 4-Item Quick Earning Hub (Above the fold)
                        HomeQuickActionsGrid(
                          isOnline: isOnline,
                          onChestTap: () async {
                            final earned =
                                await Navigator.of(context).push<int>(
                              MaterialPageRoute(
                                builder: (_) => const ChestScreen(),
                              ),
                            );
                            if (earned != null && earned > 0) {
                              ref.invalidate(userProfileStreamProvider);
                              ref.read(questStateProvider.notifier).recordVideoOrChest();
                            }
                          },
                          onSpinTap: widget.onSpinTap,
                          onScratchTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ScratchCardScreen(
                                  onBack: () => Navigator.of(context).pop(),
                                ),
                              ),
                            );
                            ref.read(questStateProvider.notifier).recordScratchCard();
                          },
                          onWatchAdTap: _onWatchAdToEarn,
                        ),
                        const SizedBox(height: AppLayout.sectionSpacing),

                        // Unified Daily Retention Hub (Streak & Missions)
                        HomeDailyHubCard(
                          consecutiveDays: userProfile.consecutiveDays,
                          isDailyClaimed: isDailyClaimed,
                          dailyCooldown: dailyCooldown,
                          isStreakBroken: isStreakBroken,
                          isDailyBlocked: isDailyBlocked,
                          onClaim: isDailyBlocked ? null : _claimDaily,
                          onSaveStreak: () =>
                              _promptStreakSaver(userProfile.consecutiveDays),
                          formatDuration: _formatDuration,
                        ),
                        const SizedBox(height: AppLayout.sectionSpacing),

                        // Play to Earn Mini-Games Shelf
                        HomeGamesSection(
                          games: gamesList,
                          onViewAll: () => widget.onNavTap(1),
                        ),
                        const SizedBox(height: AppLayout.sectionSpacing),

                        // Mega Chest Milestone Card
                        HomeMegaChestCard(
                          onClaimTriggered: () {
                            setState(() => _showCoinBurst = true);
                          },
                        ),
                        const SizedBox(height: AppLayout.sectionSpacing),

                        // Viral Referral Card
                        const HomeReferralCard(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coin burst celebration overlay
          if (_showCoinBurst)
            Positioned.fill(
              child: IgnorePointer(
                child: CoinBurstWidget(
                  isTriggered: _showCoinBurst,
                  onComplete: () {
                    setState(() => _showCoinBurst = false);
                    _completeMegaChestClaim();
                  },
                ),
              ),
            ),

          // Loading spinner overlay
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
      bottomNavigationBar: RbxBottomNav(
        currentIndex: 0,
        onTap: widget.onNavTap,
      ),
    );
  }
}
