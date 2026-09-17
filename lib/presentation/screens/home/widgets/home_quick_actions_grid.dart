import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_cached_image.dart';

class HomeQuickActionsGrid extends StatelessWidget {
  final VoidCallback onChestTap;
  final VoidCallback onSpinTap;
  final VoidCallback onScratchTap;
  final VoidCallback onWatchAdTap;
  final bool isOnline;
  /// Dynamic reward badge shown on the Watch & Earn card (e.g. '+50 RBX').
  /// Driven by coin_distributions.base_reward for 'ad' in the database.
  final int watchEarnCoins;
  /// Whether the user has hit the daily Watch & Earn cap.
  final bool isWatchEarnCapped;

  const HomeQuickActionsGrid({
    super.key,
    required this.onChestTap,
    required this.onSpinTap,
    required this.onScratchTap,
    required this.onWatchAdTap,
    this.isOnline = true,
    this.watchEarnCoins = 50,
    this.isWatchEarnCapped = false,
  });

  @override
  Widget build(BuildContext context) {
    final watchBadge = isWatchEarnCapped ? 'Capped' : '+$watchEarnCoins RBX';
    final watchBadgeColor = isWatchEarnCapped
        ? const Color(0xFFF1F5F9)
        : const Color(0xFFFFE4E6);
    final watchBadgeTextColor = isWatchEarnCapped
        ? const Color(0xFF94A3B8)
        : const Color(0xFFE11D48);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earn Today',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF131326),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppLayout.elementSpacing),
          Row(
            children: [
              _QuickActionItem(
                iconUrl: AppAssets.chestIcon,
                title: 'Chest',
                badge: 'Ready',
                badgeColor: AppColors.primarySoft,
                badgeTextColor: AppColors.primary,
                onTap: isOnline ? onChestTap : null,
              ),
              const SizedBox(width: 8),
              _QuickActionItem(
                iconUrl: AppAssets.spinWheelIcon,
                title: 'Spin & Win',
                badge: 'Free Spin',
                badgeColor: const Color(0xFFFEF3C7),
                badgeTextColor: const Color(0xFFB45309),
                onTap: isOnline ? onSpinTap : null,
              ),
              const SizedBox(width: 8),
              _QuickActionItem(
                iconUrl: AppAssets.dailyRewardImage,
                title: 'Scratch',
                badge: 'Instant Win',
                badgeColor: const Color(0xFFECFDF5),
                badgeTextColor: const Color(0xFF059669),
                onTap: isOnline ? onScratchTap : null,
              ),
              const SizedBox(width: 8),
              _QuickActionItem(
                iconUrl: AppAssets.watchEarnIcon,
                fallbackIcon: Icons.play_circle_fill_rounded,
                fallbackIconColor: const Color(0xFFE52E71),
                title: 'Watch & Earn',
                badge: watchBadge,
                badgeColor: watchBadgeColor,
                badgeTextColor: watchBadgeTextColor,
                onTap: isOnline && !isWatchEarnCapped ? onWatchAdTap : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatefulWidget {
  final String iconUrl;
  final IconData? fallbackIcon;
  final Color? fallbackIconColor;
  final String title;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final VoidCallback? onTap;

  const _QuickActionItem({
    required this.iconUrl,
    this.fallbackIcon,
    this.fallbackIconColor,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    this.onTap,
  });

  @override
  State<_QuickActionItem> createState() => _QuickActionItemState();
}

class _QuickActionItemState extends State<_QuickActionItem> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _scale = 0.95)
            : null,
        onTapUp: widget.onTap != null
            ? (_) {
                setState(() => _scale = 1.0);
                widget.onTap!();
              }
            : null,
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.cardBorder,
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: widget.iconUrl.isNotEmpty
                        ? AppCachedImage(
                            imageUrl: widget.iconUrl,
                            width: 44,
                            height: 44,
                            errorWidget: Icon(
                              widget.fallbackIcon ?? Icons.star,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(
                            widget.fallbackIcon ?? Icons.star,
                            size: 40,
                            color: widget.fallbackIconColor ?? AppColors.primary,
                          ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131326),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: widget.badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: widget.badgeTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
