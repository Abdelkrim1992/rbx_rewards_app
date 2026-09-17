import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ad_models.dart';
import '../business/sound_service.dart';
import '../presentation/providers/ad_provider.dart';
import '../presentation/providers/coin_provider.dart';
import '../presentation/providers/providers.dart';
import '../presentation/providers/reward_catalog_provider.dart';
import '../theme/app_theme.dart';
import 'coin_fly_overlay.dart';
import 'interactive_button.dart';
import 'reward_box.dart';

export 'reward_box.dart';

/// Production-ready Reward Claim Dialog with "Double-Up" Video Ad Multiplier.
/// Follows industry standards used by top reward apps (Mistplay, Freecash, Playbite).
class RewardClaimDialog extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final int baseReward;
  final AdPlacement adPlacement;
  final Future<void> Function(int coins) onClaimCompleted;
  final VoidCallback? onCancel;
  final String? heroAsset;
  final Widget? customHero;

  final int? multiplier;
  final int? premiumReward;

  const RewardClaimDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.baseReward,
    this.adPlacement = AdPlacement.doubleReward,
    required this.onClaimCompleted,
    this.onCancel,
    this.heroAsset,
    this.customHero,
    this.multiplier,
    this.premiumReward,
  });

  @override
  ConsumerState<RewardClaimDialog> createState() => _RewardClaimDialogState();
}

class _RewardClaimDialogState extends ConsumerState<RewardClaimDialog>
    with TickerProviderStateMixin {
  late AnimationController _odometerController;
  late AnimationController _pulseController;
  late Animation<int> _odometerAnimation;
  late Animation<double> _pulseAnimation;

  bool _isClaiming = false;
  bool _isLoadingAd = false;
  bool _isDoubled = false;
  String? _infoBanner;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Ticker animation for points
    _odometerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _odometerAnimation = IntTween(
      begin: 0,
      end: widget.baseReward,
    ).animate(CurvedAnimation(
      parent: _odometerController,
      curve: Curves.easeOutCubic,
    ));

    // Breathing pulse for 2X CTA
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial haptic and start counting up
    HapticFeedback.mediumImpact();
    _odometerController.forward();
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleRegularClaim() async {
    if (_isClaiming || _isLoadingAd) return;
    setState(() => _isClaiming = true);
    HapticFeedback.lightImpact();

    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox != null && renderBox.hasSize
          ? renderBox.localToGlobal(Offset(renderBox.size.width / 2, renderBox.size.height / 2))
          : Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);

      CoinFlyOverlay.spawn(context, fromPosition: origin, coinCount: 10);

      await widget.onClaimCompleted(widget.baseReward);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  int _getBoostedReward() {
    if (widget.premiumReward != null) {
      return widget.premiumReward!;
    }
    final capService = ref.read(dailyCapServiceProvider);
    return capService.calculateAdBonusReward(
      widget.baseReward,
      multiplier: widget.multiplier,
    );
  }

  Future<void> _handleDoubleClaim() async {
    if (_isClaiming || _isLoadingAd) return;
    final adNotifier = ref.read(adProvider.notifier);

    if (!adNotifier.canShowOptionalAd) {
      setState(() {
        _infoBanner = 'No video available right now. Granting base reward!';
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      await _handleRegularClaim();
      return;
    }

    setState(() {
      _isLoadingAd = true;
      _infoBanner = null;
    });

    await adNotifier.showOptionalAd(
      widget.adPlacement,
      onReward: (_) async {
        await _onAdRewardEarned();
      },
      onAdFailed: (error) async {
        await _onAdFailedFallback(error);
      },
      onAdDismissed: () {
        if (mounted && !_isDoubled) {
          setState(() => _isLoadingAd = false);
        }
      },
    );
  }

  Future<void> _onAdRewardEarned() async {
    final boostedAmount = _getBoostedReward();
    if (!mounted) return;

    setState(() {
      _isLoadingAd = false;
      _isDoubled = true;
      _infoBanner = 'BONUS BOOST ACTIVATED! 🎉';
    });

    // Roll odometer from base to boosted amount
    _odometerAnimation = IntTween(
      begin: widget.baseReward,
      end: boostedAmount,
    ).animate(CurvedAnimation(
      parent: _odometerController,
      curve: Curves.easeOutBack,
    ));

    _odometerController.reset();
    HapticFeedback.heavyImpact();
    await _odometerController.forward();

    final renderBox = context.findRenderObject() as RenderBox?;
    final origin = renderBox != null && renderBox.hasSize
        ? renderBox.localToGlobal(Offset(renderBox.size.width / 2, renderBox.size.height / 2))
        : Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);

    CoinFlyOverlay.spawn(context, fromPosition: origin, coinCount: 14);

    // Award boosted points
    await widget.onClaimCompleted(boostedAmount);

    // Keep celebration visible briefly before pop
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onAdFailedFallback(String error) async {
    if (!mounted) return;
    setState(() {
      _isLoadingAd = false;
      _infoBanner = 'Video unavailable. Granting base reward!';
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    await widget.onClaimCompleted(widget.baseReward);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenWidth < 360 || screenHeight < 680;

    return PopScope(
      canPop: !_isClaiming && !_isLoadingAd,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 20,
          vertical: isCompact ? 16 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 380,
              maxHeight: screenHeight * 0.92,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2E6035EE),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    _buildTopAura(),
                    _buildCloseButton(),
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 18 : 22,
                        isCompact ? 22 : 26,
                        isCompact ? 18 : 22,
                        isCompact ? 18 : 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeroIcon(isCompact),
                          SizedBox(height: isCompact ? 10 : 14),
                          _buildTitleSection(isCompact),
                          SizedBox(height: isCompact ? 10 : 12),
                          _buildOdometerDisplay(),
                          if (_infoBanner != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoBanner(),
                          ],
                          SizedBox(height: isCompact ? 14 : 18),
                          const GoalProgressCard(),
                          SizedBox(height: isCompact ? 16 : 20),
                          _buildActionButtons(isCompact),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 14,
      right: 14,
      child: GestureDetector(
        onTap: (_isClaiming || _isLoadingAd) ? null : _handleRegularClaim,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F2F8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAura() {
    return Positioned(
      top: -60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8C62F8).withValues(alpha: 0.35),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveHeroAsset() {
    // One common image for all features reward popups as requested
    return AppAssets.onboardingCoin;
  }

  Widget _buildHeroIcon(bool isCompact) {
    if (widget.customHero != null) return widget.customHero!;

    final asset = _resolveHeroAsset();
    final size = isCompact ? 76.0 : 96.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5DEFF), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A6035EE),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      child: Center(
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.stars_rounded,
            size: isCompact ? 36 : 46,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(bool isCompact) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOdometerDisplay() {
    return RewardBox(
      amount: widget.baseReward,
      animation: _odometerAnimation,
      isDoubled: _isDoubled,
    );
  }

  Widget _buildInfoBanner() {
    return Text(
      _infoBanner!,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6035EE),
      ),
    );
  }

  Widget _buildActionButtons(bool isCompact) {
    if (_isDoubled) {
      return SizedBox(
        height: isCompact ? 46 : 52,
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Added to your balance!',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final boostedReward = _getBoostedReward();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Video Ad Bonus CTA matching Phase 6 layout
        ScaleTransition(
          scale: _pulseAnimation,
          child: InteractiveButton(
            height: isCompact ? 48 : 52,
            gradient: AppColors.primaryGradient,
            borderRadius: 16,
            isLoading: _isLoadingAd,
            onTap: (_isClaiming || _isLoadingAd) ? null : _handleDoubleClaim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: isCompact ? 20 : 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CLAIM +$boostedReward RBX',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),

        // Secondary Regular Quick Claim CTA
        SizedBox(
          width: double.infinity,
          height: isCompact ? 38 : 42,
          child: TextButton(
            onPressed: (_isClaiming || _isLoadingAd) ? null : _handleRegularClaim,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isClaiming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64748B)),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Quick Claim (+${widget.baseReward} RBX)',
                      style: TextStyle(
                        fontSize: isCompact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Dynamic Goal-Gradient Context Widget
/// Shows real progress towards the user's active Roblox gift card goal
class GoalProgressCard extends ConsumerWidget {
  const GoalProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(coinProvider);
    final activeGoal = ref.watch(activeGoalRewardProvider);
    final progress = (coins / math.max(activeGoal.targetCoins, 1)).clamp(0.0, 1.0);
    final remaining = math.max(0, activeGoal.targetCoins - coins);
    final percent = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  activeGoal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              remaining > 0
                  ? '$remaining RBX away from reward'
                  : 'Goal reached! Ready to redeem',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
