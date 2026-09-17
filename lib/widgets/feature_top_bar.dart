import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/coin_provider.dart';
import '../theme/app_theme.dart';

/// Top-tier unified feature bar for games, activities, and sub-screens.
/// Houses:
/// 1. [Top-Left]: Adaptive back/exit button with disabled opacity state during active play.
/// 2. [Center]: Scalable title / round status.
/// 3. [Top-Right]: Dynamic rolling coin balance pill that acts as the primary flight target
///    for flying coin animations.
class FeatureTopBar extends ConsumerStatefulWidget {
  final String title;
  final VoidCallback? onBack;
  final bool isBackEnabled;
  final Widget? centerWidget;
  final Widget? trailing;

  /// Global key for the in-feature coin balance pill to receive flying coin particles
  static GlobalKey? get balanceBadgeKey => _activeState?._badgeKey;

  /// Public pulse trigger for arrival celebrations
  static void pulseBadge() {
    _activeState?._pulse();
  }

  static _FeatureTopBarState? _activeState;

  const FeatureTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.isBackEnabled = true,
    this.centerWidget,
    this.trailing,
  });

  @override
  ConsumerState<FeatureTopBar> createState() => _FeatureTopBarState();
}

class _FeatureTopBarState extends ConsumerState<FeatureTopBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  final GlobalKey _badgeKey = GlobalKey();
  int _previousCoins = 0;

  @override
  void initState() {
    super.initState();
    FeatureTopBar._activeState = this;
    _previousCoins = ref.read(coinProvider);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    if (FeatureTopBar._activeState == this) {
      FeatureTopBar._activeState = null;
    }
    _pulseController.dispose();
    super.dispose();
  }

  void _pulse() {
    if (mounted) {
      _pulseController.reset();
      _pulseController.forward();
    }
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

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinProvider);

    if (coins > _previousCoins) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pulse();
      });
    }

    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 360;
    final horizontalPadding = isCompact ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        10,
        horizontalPadding,
        6,
      ),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Left: Back button
            if (widget.onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: widget.isBackEnabled ? widget.onBack : null,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: widget.isBackEnabled ? 1.0 : 0.35,
                    child: Container(
                      width: isCompact ? 38 : 42,
                      height: isCompact ? 38 : 42,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.cardBorder.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.primary,
                        size: isCompact ? 16 : 18,
                      ),
                    ),
                  ),
                ),
              ),

            // Center: Title or custom widget
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 46 : 60,
              ),
              child: widget.centerWidget ??
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
            ),

            // Right: Balance Pill (Target for coin animations) or Trailing
            Align(
              alignment: Alignment.centerRight,
              child: widget.trailing ??
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      key: _badgeKey,
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.cardBorder,
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
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
                            width: 18,
                            height: 18,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monetization_on_rounded,
                              color: Color(0xFFFFB000),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 5),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(
                              begin: _previousCoins > coins ? coins : _previousCoins,
                              end: coins,
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            onEnd: () {
                              _previousCoins = coins;
                            },
                            builder: (context, animatedVal, child) {
                              return Text(
                                _formatCoins(animatedVal),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryText,
                                ),
                              );
                            },
                          ),
                        ],
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
