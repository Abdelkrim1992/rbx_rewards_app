import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/coin_provider.dart';
import '../providers/user_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/reward_provider.dart';
import '../providers/providers.dart';
import '../providers/mega_chest_provider.dart';
import '../../models/ad_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/congratulations_dialog.dart';
import '../../widgets/coin_burst.dart';
import '../../widgets/app_cached_image.dart';
import '../../core/utils/reward_helper.dart';
import 'chest_screen.dart';
import 'tap_tap_game_screen.dart';
import 'flappy_jump_game_screen.dart';
import 'math_quiz_screen.dart';
import 'quizzes_screen.dart';

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

  Future<void> _completeClaim() async {
    final userProfile = ref.read(userProfileProvider);
    final isWithinFirstWeek = userProfile.consecutiveDays < 7;
    final nextDay = (userProfile.consecutiveDays % 7) + 1;
    final rewardAmount = isWithinFirstWeek
        ? (nextDay == 7 ? 100 : 10 + (nextDay * 5))
        : 15;

    await showRewardChoice(
      context: context,
      featureName: 'Daily Reward',
      baseReward: rewardAmount,
      quickPlacement: AdPlacement.dailyReward,
      premiumPlacement: AdPlacement.dailyReward,
      onSuccess: (coins) async {
        await ref.read(dailyRewardCooldownProvider.notifier).claimDaily(amount: coins);
      },
    );
  }

  void _claimDaily() async {
    if (_isProcessing) return;
    final coolingDown = ref.read(dailyRewardCooldownProvider).inSeconds > 0;
    if (coolingDown) return;
    setState(() => _isProcessing = true);
    await _completeClaim();
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _completeMegaChestClaim() async {
    setState(() => _isProcessing = true);
    final success = await ref.read(megaChestMilestoneProvider.notifier).claimReward();
    setState(() => _isProcessing = false);

    if (success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (_) => const CongratulationsDialog(earnedCoins: 1000),
      );
      ref.invalidate(userProfileStreamProvider);
    }
  }


  // Future<void> _launchOfferwall(String sdkName) async {
  //   if (kIsWeb || (Theme.of(context).platform != TargetPlatform.iOS && Theme.of(context).platform != TargetPlatform.android)) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Offerwalls are only supported on Android and iOS devices.'),
  //           backgroundColor: AppColors.purple,
  //         ),
  //       );
  //     }
  //     return;
  //   }

  //   bool success = false;
  //   if (sdkName == 'tapjoy') {
  //     success = await TapjoyService().showOfferwall();
  //   } else if (sdkName == 'pubscale') {
  //     success = await PubscaleService().launch();
  //   }

  //   if (!success && mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('${sdkName[0].toUpperCase()}${sdkName.substring(1)} Offerwall is loading. Please try again in a moment.'),
  //         backgroundColor: AppColors.purple,
  //       ),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinProvider);
    final userProfile = ref.watch(userProfileProvider);
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    final dailyCooldown = ref.watch(dailyRewardCooldownProvider);
    final isDailyClaimed = dailyCooldown.inSeconds > 0;
    final capService = ref.watch(dailyCapServiceProvider);
    final isDailyCapReached = capService.isCapReachedFor('daily_reward');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isDailyBlocked = isDailyClaimed || isDailyCapReached || isFeaturesCapReached;

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
                    RbxAppHeader(onNavTap: widget.onNavTap),
                    // Offline banner
                    if (!isOnline)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.screenPadding, vertical: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFE69C)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.wifi_off,
                                  color: Color(0xFF856404), size: 20),
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
                      title: 'Welcome back 👋',
                      subtitle: 'Earn coins & redeem for Roblox rewards',
                    ),

                    // Balance Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _InteractiveCard(
                        onTap: () => widget.onNavTap(2), // Navigate to Rewards
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 2,
                                spreadRadius: 0,
                                // offset: Offset(0,1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    AppAssets.goldRbxCoin,
                                    width: 40,
                                    height: 40,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.monetization_on,
                                      size: 50,
                                      color: Color(0xFFFFCC44),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'YOUR RBX BALANCE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF868A9F),
                                          letterSpacing: 0.8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('$coins',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF664DFF),
                                                letterSpacing: 0,
                                                height: 1.0,
                                              )),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'RBX Coins',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF868A9F),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFFD1D5DB),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Daily Reward Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.dailyCardGradient,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 2,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 20, 0, 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDailyClaimed
                                          ? 'Reward Claimed\nSee you tomorrow'
                                          : 'Daily Reward',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF131326),
                                        letterSpacing: -0.5,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isDailyBlocked
                                          ? (isDailyClaimed
                                              ? 'You claimed your daily login reward.'
                                              : 'Daily login limit or feature cap reached today.')
                                          : 'Come back every day and claim awesome rewards.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4A4B60),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _InteractiveCard(
                                      onTap:
                                          isDailyBlocked ? null : _claimDaily,
                                      child: Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        decoration: BoxDecoration(
                                          gradient: isDailyBlocked
                                              ? null
                                              : AppColors.primaryGradient,
                                          color: isDailyBlocked
                                              ? Colors.white
                                                  .withValues(alpha: 0.5)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: isDailyBlocked
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  )
                                                ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (isDailyBlocked && isDailyClaimed)
                                              const Icon(Icons.timer_outlined,
                                                  size: 16,
                                                  color: AppColors.primary),
                                            if (isDailyBlocked && isDailyClaimed)
                                              const SizedBox(width: 6),
                                            isDailyBlocked
                                                ? Text(
                                                    isDailyClaimed
                                                        ? 'Ends ${_formatDuration(dailyCooldown)}'
                                                        : 'Cap Reached',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.primary,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Claim Now',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Container(
                                height: 160,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 12),
                                child: Opacity(
                                  opacity: isDailyClaimed ? 0.7 : 1.0,
                                  child: Image.asset(
                                    AppAssets.dailyRewardGift,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.card_giftcard,
                                      size: 100,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Daily Streak Bonus Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _DailyStreakCard(
                        consecutiveDays: userProfile.consecutiveDays,
                        isDailyClaimed: isDailyClaimed,
                        dailyCooldown: dailyCooldown,
                        onClaim: isDailyBlocked ? null : _claimDaily,
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Quick Actions header
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(
                        title: 'Earn Today',
                      ),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // Quick Actions grid
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        children: [
                          _QuickActionCard(
                            iconUrl: AppAssets.chestIcon,
                            title: 'Chest',
                            badge: 'Ready',
                            onTap: isOnline
                                ? () async {
                                    final earned =
                                        await Navigator.of(context).push<int>(
                                      MaterialPageRoute(
                                          builder: (_) => const ChestScreen()),
                                    );
                                    if (earned != null && earned > 0) {
                                      ref.invalidate(userProfileStreamProvider);
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            iconUrl: AppAssets.spinWheelIcon,
                            title: 'Spin & Win',
                            badge: 'Ready',
                            onTap: isOnline ? widget.onSpinTap : null,
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            iconUrl: AppAssets.quizMasterQuickActions,
                            title: 'Quizzes',
                            badge: 'Ready',
                            onTap: isOnline
                                ? () async {
                                    final earned =
                                        await Navigator.of(context).push<int>(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const QuizzesScreen()),
                                    );
                                    if (earned != null && earned > 0) {
                                      ref.invalidate(userProfileStreamProvider);
                                    }
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Play to Earn header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(
                        title: 'Play to Earn',
                        linkText: 'View All',
                        onTap: () => widget.onNavTap(1),
                      ),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // Games row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.tapTapGame,
                              title: 'Tap Tap',
                              subtitle: 'Tap & earn',
                              coins: '+120 RBX',
                              bgColor: const Color(0xFFEAF3FF),
                              onTap: isOnline
                                  ? () async {
                                      final earned =
                                          await Navigator.of(context).push<int>(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const TapTapGameScreen(),
                                        ),
                                      );
                                      if (earned != null && earned > 0) {
                                        ref.invalidate(userProfileStreamProvider);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.quizMasterGame,
                              title: 'Math Quiz',
                              subtitle: 'Solve & earn',
                              coins: '+120 RBX',
                              bgColor: const Color(0xFFE3F8EB),
                              onTap: isOnline
                                  ? () async {
                                      final earned =
                                          await Navigator.of(context).push<int>(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const MathQuizScreen(),
                                        ),
                                      );
                                      if (earned != null && earned > 0) {
                                        ref.invalidate(userProfileStreamProvider);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.flappyJumpGame,
                              title: 'Flappy Jump',
                              subtitle: 'Fly & earn',
                              coins: '+120 RBX',
                              bgColor: const Color(0xFFFFF3E3),
                              onTap: isOnline
                                  ? () async {
                                      final earned =
                                          await Navigator.of(context).push<int>(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const FlappyJumpGameScreen(),
                                        ),
                                      );
                                      if (earned != null && earned > 0) {
                                        ref.invalidate(userProfileStreamProvider);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Mega Chest Progress Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _MegaChestCard(
                        onClaimTriggered: () {
                          setState(() {
                            _showCoinBurst = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
      if (_isProcessing)
        Container(
          color: Colors.black26,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
    ],
    ),
      bottomNavigationBar: RbxBottomNav(currentIndex: 0, onTap: widget.onNavTap),
    );
  }
}

class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InteractiveCard({required this.child, this.onTap});

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        if (widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? linkText;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.title,
    this.linkText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF131326),
          ),
        ),
        if (linkText != null && onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  linkText!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.purple),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String iconUrl;
  final String title;
  final String badge;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.iconUrl,
    required this.title,
    required this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _InteractiveCard(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              AppCachedImage(
                imageUrl: iconUrl,
                width: 56,
                height: 56,
                errorWidget: const Icon(
                  Icons.star,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF131326),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF664DFF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _GameCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String coins;
  final Color bgColor;
  final VoidCallback? onTap;

  const _GameCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _InteractiveCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 100, // Increased height to make the card bigger
                    width: double.infinity,
                    color: bgColor,
                    child: AppCachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: Icon(
                        Icons.sports_esports,
                        size: 44,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13, // Increased from 13
                        fontWeight: FontWeight.w800, // Bolder
                        color: Color(0xFF131326),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF868A9F),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              coins,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.purple,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Image.asset(
                            AppAssets.goldCoin,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monetization_on,
                              size: 20,
                              color: Color(0xFFFFCC44),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MegaChestCard extends ConsumerStatefulWidget {
  final VoidCallback onClaimTriggered;

  const _MegaChestCard({required this.onClaimTriggered});

  @override
  ConsumerState<_MegaChestCard> createState() => _MegaChestCardState();
}

class _MegaChestCardState extends ConsumerState<_MegaChestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Alarm shake/vibration rotation sequence
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _showChestInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppAssets.megaChest,
                width: 100,
                height: 100,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.card_giftcard,
                  size: 80,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mega Chest',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131326),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Earn 10,000 Coins from playing mini-games, completing math quizzes, scratching cards, and opening chests to unlock the Mega Chest and claim an extra 1,000 RBX Coins!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF868A9F),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text(
                  'Start Earning',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinBalance = ref.watch(coinProvider);
    var lastClaimedMilestone = ref.watch(megaChestMilestoneProvider);

    // Automatically reset milestone if balance falls below it due to spending
    if (coinBalance < lastClaimedMilestone * 10000) {
      final newMilestone = (coinBalance / 10000).floor();
      lastClaimedMilestone = newMilestone;
      Future.microtask(() {
        ref.read(megaChestMilestoneProvider.notifier).setMilestone(newMilestone);
      });
    }

    final nextMilestoneLimit = (lastClaimedMilestone + 1) * 10000;
    final isReadyToClaim = coinBalance >= nextMilestoneLimit;

    // Control shaking repeating animation
    if (isReadyToClaim) {
      if (!_shakeController.isAnimating) {
        _shakeController.repeat();
      }
    } else {
      if (_shakeController.isAnimating) {
        _shakeController.stop();
        _shakeController.reset();
      }
    }

    // Calculate progress coins (relative to current milestone block)
    final progressCoins = isReadyToClaim
        ? 10000
        : (coinBalance - (lastClaimedMilestone * 10000)).clamp(0, 10000);
    final progressPercent = progressCoins / 10000.0;

    return _InteractiveCard(
      onTap: () {
        if (isReadyToClaim) {
          widget.onClaimTriggered();
        } else {
          _showChestInfoDialog(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFF3F3F5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left side details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReadyToClaim ? 'Mega Chest Ready!' : 'Mega Chest Progress',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131326),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Progress Bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            color: AppColors.purple,
                            backgroundColor: const Color(0xFFE9EAF5),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Progress label
                      Text(
                        '$progressCoins / 10000',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF131326),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right side Chest Image with Shake Animation
            Container(
              width: 56,
              height: 56,
              decoration: isReadyToClaim
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: isReadyToClaim ? _shakeAnimation.value : 0.0,
                    child: child,
                  );
                },
                child: Image.asset(
                  AppAssets.megaChest,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.card_giftcard,
                    size: 40,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyStreakCard extends StatelessWidget {
  final int consecutiveDays;
  final bool isDailyClaimed;
  final Duration dailyCooldown;
  final VoidCallback? onClaim;

  const _DailyStreakCard({
    required this.consecutiveDays,
    this.isDailyClaimed = false,
    this.dailyCooldown = Duration.zero,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final cycleStreak = consecutiveDays % 7;
    final int claimedInCycle;
    final int? activeDayToClaim;

    if (isDailyClaimed) {
      claimedInCycle =
          (consecutiveDays > 0 && cycleStreak == 0) ? 7 : cycleStreak;
      activeDayToClaim = null;
    } else {
      claimedInCycle = cycleStreak;
      activeDayToClaim = cycleStreak + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DailyStreakHeader(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isClaimed = dayNum <= claimedInCycle;
              final isActive = dayNum == activeDayToClaim;

              return _StreakDayItem(
                dayNum: dayNum,
                isClaimed: isClaimed,
                isActive: isActive,
                onTap: isActive ? onClaim : null,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DailyStreakHeader extends StatelessWidget {
  const _DailyStreakHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Daily Streak Bonus',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF131326),
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Keep your streak for bigger rewards!',
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7C8BA0),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _StreakDayItem extends StatelessWidget {
  final int dayNum;
  final bool isClaimed;
  final bool isActive;
  final VoidCallback? onTap;

  const _StreakDayItem({
    required this.dayNum,
    required this.isClaimed,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCoinCircle(),
          const SizedBox(height: 6),
          _buildDayLabel(),
        ],
      ),
    );
  }

  Widget _buildCoinCircle() {
    if (isActive) {
      return const _ActiveStreakCoin();
    }
    if (isClaimed) {
      return const _ClaimedStreakCoin();
    }
    return const _LockedStreakCoin();
  }

  Widget _buildDayLabel() {
    final Color textColor;
    final FontWeight fontWeight;

    if (isActive) {
      textColor = const Color(0xFF6D28D9);
      fontWeight = FontWeight.w700;
    } else if (isClaimed) {
      textColor = const Color(0xFF10B981);
      fontWeight = FontWeight.w600;
    } else {
      textColor = const Color(0xFF8C95A6);
      fontWeight = FontWeight.w500;
    }

    return Text(
      'Day $dayNum',
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: fontWeight,
        color: textColor,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _ActiveStreakCoin extends StatelessWidget {
  const _ActiveStreakCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6),
            Color(0xFF6D28D9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          AppAssets.goldRbxCoin,
          width: 25,
          height: 25,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _ClaimedStreakCoin extends StatelessWidget {
  const _ClaimedStreakCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFFBEB),
        border: Border.all(
          color: const Color(0xFFFCD34D),
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AppAssets.goldRbxCoin,
            width: 23,
            height: 23,
            fit: BoxFit.contain,
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedStreakCoin extends StatelessWidget {
  const _LockedStreakCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF4F5F8),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Center(
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      0.40, 0,
          ]),
          child: Image.asset(
            AppAssets.goldRbxCoin,
            width: 21,
            height: 21,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}


