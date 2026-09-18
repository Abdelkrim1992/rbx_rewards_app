import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_cached_image.dart';
import '../models/game_item_data.dart';

/// A 2-column grid card for a mini-game entry.
class GameCardEnhanced extends StatefulWidget {
  final GameItemData game;
  final int earnedToday;
  final int totalCap;
  final int remainingCap;
  final int? rewardAmount;
  final VoidCallback onTap;
  final VoidCallback onQuickPlay;

  const GameCardEnhanced({
    super.key,
    required this.game,
    required this.earnedToday,
    required this.totalCap,
    required this.remainingCap,
    this.rewardAmount,
    required this.onTap,
    required this.onQuickPlay,
  });

  @override
  State<GameCardEnhanced> createState() => _GameCardEnhancedState();
}

class _GameCardEnhancedState extends State<GameCardEnhanced> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final progress = widget.totalCap > 0
        ? (widget.earnedToday / widget.totalCap).clamp(0.0, 1.0)
        : 0.0;

    final isDynamicGame = game.category != GameCategory.instant;
    final maxReward = widget.rewardAmount ?? (isDynamicGame ? 31 : 48);
    final pillText = isDynamicGame ? 'Up to +$maxReward' : '+$maxReward';

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(game),
                _buildCardBody(progress, pillText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(GameItemData game) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: game.softBgColor,
                child: AppCachedImage(
                  imageUrl: game.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: Icon(
                    Icons.sports_esports_rounded,
                    size: 40,
                    color: game.themeColor,
                  ),
                ),
              ),
            ),
            // Category badge (Top-Left)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: game.badgeColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  game.badgeText,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            // Duration badge (Top-Right)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 10, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text(
                      game.avgTime,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBody(double progress, String pillText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.game.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF131326),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.game.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 7),
          _buildProgressBar(progress),
          const SizedBox(height: 7),
          _buildActionRow(pillText),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4.5,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Earned today',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              '${widget.earnedToday}/${widget.totalCap}',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow(String pillText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pillText,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 3),
              Image.asset(
                AppAssets.goldCoin,
                width: 12,
                height: 12,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.monetization_on,
                  size: 12,
                  color: Color(0xFFFFCC44),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onQuickPlay,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 17),
          ),
        ),
      ],
    );
  }
}
