import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ad_models.dart';
import '../presentation/providers/ad_provider.dart';
import '../presentation/providers/coin_provider.dart';
import '../presentation/providers/reward_catalog_provider.dart';
import '../theme/app_theme.dart';
import 'interactive_button.dart';

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
      await widget.onClaimCompleted(widget.baseReward);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  Future<void> _handleDoubleClaim() async {
    if (_isClaiming || _isLoadingAd) return;
    final adNotifier = ref.read(adProvider.notifier);

    if (!adNotifier.canShowOptionalAd) {
      setState(() {
        _infoBanner = 'Daily video limit reached. Granting base reward!';
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
    final doubleAmount = widget.baseReward * 2;
    if (!mounted) return;

    setState(() {
      _isLoadingAd = false;
      _isDoubled = true;
      _infoBanner = '2X MULTIPLIER ACTIVATED! 🎉';
    });

    // Roll odometer from base to 2X
    _odometerAnimation = IntTween(
      begin: widget.baseReward,
      end: doubleAmount,
    ).animate(CurvedAnimation(
      parent: _odometerController,
      curve: Curves.easeOutBack,
    ));

    _odometerController.reset();
    HapticFeedback.heavyImpact();
    await _odometerController.forward();

    // Award doubled points
    await widget.onClaimCompleted(doubleAmount);

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
    return PopScope(
      canPop: !_isClaiming && !_isLoadingAd,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeroIcon(),
                      const SizedBox(height: 14),
                      _buildTitleSection(),
                      const SizedBox(height: 12),
                      _buildOdometerDisplay(),
                      if (_infoBanner != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoBanner(),
                      ],
                      const SizedBox(height: 18),
                      _GoalProgressCard(),
                      const SizedBox(height: 20),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ],
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
    // If explicitly provided and not the awkward tilted card gift box, use it
    if (widget.heroAsset != null &&
        widget.heroAsset!.isNotEmpty &&
        widget.heroAsset != AppAssets.dailyRewardGift) {
      return widget.heroAsset!;
    }
    final titleLower = widget.title.toLowerCase();
    if (titleLower.contains('chest')) {
      return AppAssets.megaChest;
    } else if (titleLower.contains('spin')) {
      return AppAssets.spinWheelIcon;
    }
    return AppAssets.goldRbxCoin;
  }

  Widget _buildHeroIcon() {
    if (widget.customHero != null) return widget.customHero!;

    final asset = _resolveHeroAsset();
    return Container(
      width: 92,
      height: 92,
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
      padding: const EdgeInsets.all(14),
      child: Center(
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.stars_rounded,
            size: 46,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        Text(
          widget.title.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: 0.5,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOdometerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDoubled ? const Color(0xFF8C62F8) : AppColors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            AppAssets.goldRbxCoin,
            width: 32,
            height: 32,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.monetization_on,
              color: Color(0xFFFFB000),
              size: 32,
            ),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _odometerAnimation,
            builder: (context, child) {
              return Text(
                '+${_odometerAnimation.value} RBX',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
        ],
      ),
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

  Widget _buildActionButtons() {
    if (_isDoubled) {
      return const SizedBox(
        height: 52,
        child: Center(
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

    final doubleReward = widget.baseReward * 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary 2X Double-Up CTA matching the app's signature button style (spin_screen.dart)
        ScaleTransition(
          scale: _pulseAnimation,
          child: InteractiveButton(
            height: 52,
            gradient: AppColors.primaryGradient,
            borderRadius: 16,
            isLoading: _isLoadingAd,
            onTap: (_isClaiming || _isLoadingAd) ? null : _handleDoubleClaim,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'DOUBLE TO +$doubleReward RBX',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Regular Claim CTA
        SizedBox(
          width: double.infinity,
          height: 42,
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
                : Text(
                    'Collect +${widget.baseReward} RBX Only',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
class _GoalProgressCard extends ConsumerWidget {
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
          Text(
            remaining > 0
                ? '$remaining RBX away from reward'
                : 'Goal reached! Ready to redeem',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
