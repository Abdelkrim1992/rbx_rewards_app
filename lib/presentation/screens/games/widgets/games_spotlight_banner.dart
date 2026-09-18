import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_cached_image.dart';
import '../models/game_item_data.dart';

class GamesSpotlightBanner extends StatefulWidget {
  final GameItemData game;
  final int earnedToday;
  final int totalCap;
  final int remainingCap;
  final int rewardAmount;
  final VoidCallback onPlayTap;

  const GamesSpotlightBanner({
    super.key,
    required this.game,
    required this.earnedToday,
    required this.totalCap,
    required this.remainingCap,
    this.rewardAmount = 31,
    required this.onPlayTap,
  });

  @override
  State<GamesSpotlightBanner> createState() => _GamesSpotlightBannerState();
}

class _GamesSpotlightBannerState extends State<GamesSpotlightBanner> {
  double _buttonScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalCap > 0
        ? (widget.earnedToday / widget.totalCap).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              _buildBackgroundGlow(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(),
                    const SizedBox(height: 14),
                    _buildGameInfoRow(),
                    const SizedBox(height: 14),
                    _buildProgressSection(progress),
                    const SizedBox(height: 14),
                    _buildPlayButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(
      top: -40,
      right: -40,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.game.themeColor.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5252), Color(0xFFFF7A00)],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🔥', style: TextStyle(fontSize: 12)),
              SizedBox(width: 4),
              Text(
                'FEATURED ARCADE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Up to +${widget.rewardAmount}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 5),
              Image.asset(
                AppAssets.goldCoin,
                width: 15,
                height: 15,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.monetization_on,
                  size: 15,
                  color: Color(0xFFFFCC44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameInfoRow() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 78,
            height: 78,
            color: widget.game.softBgColor,
            child: AppCachedImage(
              imageUrl: widget.game.imageUrl,
              fit: BoxFit.cover,
              errorWidget: Icon(
                Icons.sports_esports_rounded,
                size: 38,
                color: widget.game.themeColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.game.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF131326),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.game.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _MetaPill(icon: Icons.timer_outlined, label: widget.game.avgTime),
                  const SizedBox(width: 6),
                  _MetaPill(icon: Icons.speed_rounded, label: widget.game.difficulty),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Coins Progress',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              Text(
                '${widget.earnedToday} / ${widget.totalCap} RBX',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _buttonScale = 0.97),
      onTapUp: (_) {
        setState(() => _buttonScale = 1.0);
        widget.onPlayTap();
      },
      onTapCancel: () => setState(() => _buttonScale = 1.0),
      child: AnimatedScale(
        scale: _buttonScale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Play Featured Game Now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
