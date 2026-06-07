import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/coin_provider.dart';
import '../providers/user_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/reward_provider.dart';
import '../providers/providers.dart';
import '../../models/ad_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/two_tier_reward_dialog.dart';
import '../../widgets/congratulations_dialog.dart';
import '../../core/utils/reward_helper.dart';
import '../../business/tapjoy_service.dart';
import '../../business/pubscale_service.dart';
import 'chest_screen.dart';
import 'tap_tap_game_screen.dart';
import 'flappy_jump_game_screen.dart';
import 'math_quiz_screen.dart';
import 'earn_more_screen.dart';
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
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _completeClaim() async {
    await showRewardChoice(
      context: context,
      featureName: 'Daily Reward',
      baseReward: 15,
      quickPlacement: AdPlacement.dailyReward,
      premiumPlacement: AdPlacement.dailyReward,
      onSuccess: (coins) async {
        await ref.read(dailyRewardCooldownProvider.notifier).claimDaily(amount: coins);
      },
    );
  }

  void _claimDaily() {
    final coolingDown = ref.read(dailyRewardCooldownProvider).inSeconds > 0;
    if (coolingDown) return;
    _completeClaim();
  }

  Future<void> _showSurveyDialog() async {
    final coinsEarned = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SurveyDialog(),
    );

    if (!mounted || coinsEarned == null || coinsEarned <= 0) return;

    await showRewardChoice(
      context: context,
      featureName: 'Survey Reward',
      baseReward: coinsEarned,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.miniGameCompletion,
      onSuccess: (coins) async {
        await ref.read(coinProvider.notifier).credit(coins, 'survey');
        await ref.read(profileServiceProvider).incrementOffersCompleted();
      },
    );
  }

  Future<void> _showScratchDialog() async {
    // Step 1: Animation plays (scratch card reveal)
    final coinsEarned = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ScratchRewardDialog(),
    );

    if (!mounted || coinsEarned == null || coinsEarned <= 0) return;

    await showRewardChoice(
      context: context,
      featureName: 'Scratch Card Reward',
      baseReward: coinsEarned,
      quickPlacement: AdPlacement.scratchCard,
      premiumPlacement: AdPlacement.doubleReward,
      onSuccess: (coins) async {
        await ref.read(coinProvider.notifier).credit(coins, 'scratch');
        await ref.read(profileServiceProvider).incrementOffersCompleted();
      },
    );
  }

  Future<void> _launchOfferwall(String sdkName) async {
    if (kIsWeb || (Theme.of(context).platform != TargetPlatform.iOS && Theme.of(context).platform != TargetPlatform.android)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offerwalls are only supported on Android and iOS devices.'),
            backgroundColor: AppColors.purple,
          ),
        );
      }
      return;
    }

    bool success = false;
    if (sdkName == 'tapjoy') {
      success = await TapjoyService().showOfferwall();
    } else if (sdkName == 'pubscale') {
      success = await PubscaleService().launch();
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sdkName[0].toUpperCase()}${sdkName.substring(1)} Offerwall is loading. Please try again in a moment.'),
          backgroundColor: AppColors.purple,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinProvider);
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    final dailyCooldown = ref.watch(dailyRewardCooldownProvider);
    final isDailyClaimed = dailyCooldown.inSeconds > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshableScrollView(
                padding: const EdgeInsets.only(top: 12, bottom: 100),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        children: [
                          Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131326),
                              letterSpacing: -0.55,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('👋', style: TextStyle(fontSize: 22)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Balance Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _InteractiveCard(
                        onTap: () => widget.onNavTap(3), // Navigate to Rewards
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
                                      isDailyClaimed
                                          ? 'You earned 100 coins today.'
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
                                          isDailyClaimed ? null : _claimDaily,
                                      child: Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        decoration: BoxDecoration(
                                          gradient: isDailyClaimed
                                              ? null
                                              : AppColors.primaryGradient,
                                          color: isDailyClaimed
                                              ? Colors.white
                                                  .withValues(alpha: 0.5)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: isDailyClaimed
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
                                            if (isDailyClaimed)
                                              const Icon(Icons.timer_outlined,
                                                  size: 16,
                                                  color: AppColors.primary),
                                            if (isDailyClaimed)
                                              const SizedBox(width: 6),
                                            isDailyClaimed
                                                ? Text(
                                                    'Ends ${_formatDuration(dailyCooldown)}',
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
                                    AppAssets.dailyRewardImage,
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

                    // Quick Actions header
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(
                        title: 'Quick Actions',
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
                              coins: '+200 RBX',
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
                              subtitle: 'Answer & win',
                              coins: '+200 RBX',
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
                              coins: '+200 RBX',
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

                    // Earn More header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(
                        title: 'Earn More',
                        linkText: 'View All',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EarnMoreScreen(onNavTap: widget.onNavTap),
                            ),
                          );
                          if (!context.mounted) return;
                          ref.invalidate(userProfileStreamProvider);
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // Earn More list
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _EarnMoreVerticalCard(
                                iconUrl: AppAssets.quizMasterEarnMore,
                                title: 'Quiz Master',
                                subtitle: 'Answer & earn',
                                badge: 'Up to 400',
                                onTap: () async {
                                  final earned =
                                      await Navigator.of(context).push<int>(
                                    MaterialPageRoute(
                                        builder: (_) => const QuizzesScreen()),
                                  );
                                  if (earned != null && earned > 0) {
                                    if (!context.mounted) return;
                                    ref.invalidate(userProfileStreamProvider);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _EarnMoreVerticalCard(
                                iconUrl: AppAssets.tapTapGame,
                                title: 'Scratch',
                                subtitle: 'Reveal rewards',
                                badge: 'Up to 350',
                                onTap: _showScratchDialog,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _EarnMoreVerticalCard(
                                iconUrl:
                                    'https://cdn3d.iconscout.com/3d/premium/thumb/clipboard-survey-9937084-8134762.png',
                                title: 'Surveys',
                                subtitle: 'Answer polls',
                                badge: 'Up to 250',
                                onTap: _showSurveyDialog,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Offers & Tasks header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(
                        title: 'Offers & Tasks',
                        linkText: 'View All',
                        onTap: () => widget.onNavTap(2),
                      ),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // Offers & Tasks list (3 items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Column(
                        children: [
                          _HomeOfferListItem(
                            icon: Icons.star_rounded,
                            title: 'Mega Reward Offers',
                            subtitle: 'Games, surveys & app downloads',
                            reward: 12000,
                            difficulty: 'Medium',
                            estimatedTime: 'Varies',
                            onTap: () => _launchOfferwall('tapjoy'),
                          ),
                          const SizedBox(height: 12),
                          _HomeOfferListItem(
                            icon: Icons.bolt_rounded,
                            title: 'Express Coin Offers',
                            subtitle: 'Tasks, surveys & fast payouts',
                            reward: 15000,
                            difficulty: 'Easy',
                            estimatedTime: 'Varies',
                            onTap: () => _launchOfferwall('pubscale'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RbxBottomNav(currentIndex: 0, onTap: widget.onNavTap),
        ),
      ),
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
              iconUrl.startsWith('http')
                  ? Image.network(
                      iconUrl,
                      width: 56,
                      height: 56,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.star,
                        size: 46,
                        color: AppColors.primary,
                      ),
                    )
                  : Image.asset(
                      iconUrl,
                      width: 56,
                      height: 56,
                      errorBuilder: (_, __, ___) => const Icon(
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

class _EarnMoreVerticalCard extends StatelessWidget {
  final String iconUrl;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _EarnMoreVerticalCard({
    required this.iconUrl,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _InteractiveCard(
      onTap: onTap,
      child: Container(
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
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image container at the top
              Container(
                height: 70,
                width: double.infinity,
                color: AppColors.primarySoft,
                child: iconUrl.startsWith('http')
                    ? Image.network(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.star,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      )
                    : Image.asset(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.star,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                child: Column(
                  children: [
                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131326),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Subtitle
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
                    // Badge
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
                          Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.visible,
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

class _HomeOfferListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int reward;
  final String difficulty;
  final String estimatedTime;
  final VoidCallback? onTap;

  const _HomeOfferListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.reward,
    required this.difficulty,
    required this.estimatedTime,
    this.onTap,
  });

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return const Color(0xFF27AE60);
      case 'Medium':
        return const Color(0xFFFF9800);
      case 'Hard':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF868A9F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFF3F4F6)),
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
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131326),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF868A9F),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Difficulty tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _difficultyColor(difficulty).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          difficulty,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _difficultyColor(difficulty),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time tag
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer,
                              size: 12, color: Color(0xFF868A9F)),
                          const SizedBox(width: 3),
                          Text(
                            estimatedTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF868A9F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Reward
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AppAssets.goldRbxCoin,
                      width: 18,
                      height: 18,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.monetization_on,
                        size: 18,
                        color: Color(0xFFFFCC44),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$reward',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF131326),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
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
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 2,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            children: [
              Container(
                height: 70, // Matched with _EarnMoreVerticalCard image height
                width: double.infinity,
                color: bgColor,
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.sports_esports,
                          size: 44,
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                      )
                    : Image.asset(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.sports_esports,
                          size: 44,
                          color: AppColors.primary.withOpacity(0.5),
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
