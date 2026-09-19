import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/coin_provider.dart';
import '../presentation/providers/providers.dart';
import '../presentation/providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'app_cached_image.dart';

class RbxAppHeader extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final ValueChanged<int>? onNavTap;
  final bool isScrolled;
  final bool isSticky;

  /// Global key to target the active coin balance badge during flying coin animations
  static GlobalKey? get balanceBadgeKey => _headerState?._badgeKey;

  /// Public hook to trigger balance badge bounce pulse from external overlays
  static void pulseBadge() {
    _headerState?.pulse();
  }

  static _RbxAppHeaderState? _headerState;

  const RbxAppHeader({
    super.key,
    this.onNavTap,
    this.isScrolled = false,
    this.isSticky = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  ConsumerState<RbxAppHeader> createState() => _RbxAppHeaderState();
}

class _RbxAppHeaderState extends ConsumerState<RbxAppHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  int _previousCoins = 0;

  @override
  void initState() {
    super.initState();
    RbxAppHeader._headerState = this;
    _previousCoins = ref.read(coinProvider);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    if (RbxAppHeader._headerState == this) {
      RbxAppHeader._headerState = null;
    }
    _pulseController.dispose();
    super.dispose();
  }

  void pulse() {
    if (mounted) {
      _pulseController.reset();
      _pulseController.forward();
    }
  }

  final GlobalKey _badgeKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    RbxAppHeader._headerState = this;
  }

  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 100000) {
      return '${(coins / 1000).toStringAsFixed(0)}K';
    }
    return coins.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _buildBreakdownRow({
    required String icon,
    required String title,
    required int earned,
    required Color iconBg,
    required Color iconBorder,
  }) {
    final hasEarned = earned > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconBorder, width: 1),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: hasEarned ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasEarned ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Text(
              hasEarned ? '+$earned RBX' : '0 RBX',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: hasEarned ? const Color(0xFF059669) : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBalanceSheet(BuildContext context, int coins) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final capService = ref.watch(dailyCapServiceProvider);
            final liveCoins = ref.watch(coinProvider);
            final todayEarned = capService.todayFeaturesEarnings;
            final maxCap = capService.dynamicFeaturesCap;
            final remaining = (maxCap - todayEarned).clamp(0, maxCap);

            final arcadeGamesEarned = capService.todayGameMathQuizEarnings +
                capService.todayGameFlappyEarnings +
                capService.todayGameTapTapEarnings +
                capService.todayGameFlipCardEarnings +
                capService.todayQuizEarnings;
            final chestsAndVideosEarned = capService.todayChestEarnings +
                capService.todayWatchVideoEarnings;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Image.asset(AppAssets.goldCoin, width: 28, height: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Coin Balance',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '$liveCoins RBX Coins',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Daily Earning Progress
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Daily Cap Left',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$remaining / $maxCap coins',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: maxCap > 0 ? (todayEarned / maxCap).clamp(0.0, 1.0) : 0,
                                  minHeight: 7,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Today's Activity Breakdown Rows
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "Today's Activity Breakdown",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+$todayEarned RBX',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 6),
                              _buildBreakdownRow(
                                icon: '🔥',
                                title: 'Daily Streak',
                                earned: capService.todayDailyRewardEarnings,
                                iconBg: const Color(0xFFFFF7ED),
                                iconBorder: const Color(0xFFFFEDD5),
                              ),
                              _buildBreakdownRow(
                                icon: '🎡',
                                title: 'Spin & Win',
                                earned: capService.todaySpinEarnings,
                                iconBg: const Color(0xFFFAF5FF),
                                iconBorder: const Color(0xFFF3E8FF),
                              ),
                              _buildBreakdownRow(
                                icon: '🎟️',
                                title: 'Scratch Cards',
                                earned: capService.todayScratchEarnings,
                                iconBg: const Color(0xFFFEF3C7),
                                iconBorder: const Color(0xFFFDE68A),
                              ),
                              _buildBreakdownRow(
                                icon: '🎮',
                                title: 'Arcade Mini-Games',
                                earned: arcadeGamesEarned,
                                iconBg: const Color(0xFFEFF6FF),
                                iconBorder: const Color(0xFFDBEAFE),
                              ),
                              _buildBreakdownRow(
                                icon: '🎁',
                                title: 'Chests & Video Ads',
                                earned: chestsAndVideosEarned,
                                iconBg: const Color(0xFFFDF2F8),
                                iconBorder: const Color(0xFFFCE7F3),
                              ),
                              if (capService.todayOfferwallsEarnings > 0)
                                _buildBreakdownRow(
                                  icon: '⭐',
                                  title: 'Offerwalls & Tasks',
                                  earned: capService.todayOfferwallsEarnings,
                                  iconBg: const Color(0xFFF0FDF4),
                                  iconBorder: const Color(0xFFDCFCE7),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                                label: const Text(
                                  'Redeem Robux',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  widget.onNavTap?.call(2); // Rewards tab
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final coins = ref.watch(coinProvider);

    if (coins > _previousCoins) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pulse();
      });
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: widget.isScrolled ? 0.96 : 1.0),
        border: Border(
          bottom: BorderSide(
            color: widget.isScrolled
                ? AppColors.cardBorder.withValues(alpha: 0.8)
                : Colors.transparent,
            width: 1,
          ),
        ),
        boxShadow: widget.isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.only(
        left: isCompact ? 12 : AppLayout.screenPadding,
        right: isCompact ? 12 : AppLayout.screenPadding,
        top: widget.isScrolled ? 12 : (isCompact ? 16 : 20),
        bottom: widget.isScrolled ? 10 : 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onNavTap?.call(3);
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isCompact ? 36 : 40,
                    height: isCompact ? 36 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: (userProfile.profilePhotoUrl != null &&
                              userProfile.profilePhotoUrl!.isNotEmpty)
                          ? AppCachedImage(
                              imageUrl: userProfile.profilePhotoUrl!,
                              fallbackAsset: AppAssets.profileAvatar,
                              width: isCompact ? 36 : 40,
                              height: isCompact ? 36 : 40,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              AppAssets.profileAvatar,
                              width: isCompact ? 36 : 40,
                              height: isCompact ? 36 : 40,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${userProfile.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isCompact ? 13 : 14.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Lvl ${(userProfile.totalEarned / 5000).floor() + 1}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Live Coin Balance Badge (Target of Flying Coin Animations)
          GestureDetector(
            onTap: () => _showBalanceSheet(context, coins),
            behavior: HitTestBehavior.opaque,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                key: _badgeKey,
                height: 36,
                padding: const EdgeInsets.only(left: 8, right: 10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.cardBorder, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AppAssets.goldCoin,
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFFFB000),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 5),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(
                        begin: _previousCoins > coins ? coins : _previousCoins,
                        end: coins,
                      ),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      onEnd: () {
                        _previousCoins = coins;
                      },
                      builder: (context, animatedValue, child) {
                        return Text(
                          _formatCoins(animatedValue),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
                            letterSpacing: 0.2,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
