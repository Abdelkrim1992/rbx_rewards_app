import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_cached_image.dart';
import '../models/game_item_data.dart';

class GamesSpotlightBanner extends StatelessWidget {
  final GameItemData game;
  final int earnedToday;
  final int totalCap;
  final int remainingCap;
  final VoidCallback onPlayTap;

  const GamesSpotlightBanner({
    super.key,
    required this.game,
    required this.earnedToday,
    required this.totalCap,
    required this.remainingCap,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBlocked = remainingCap <= 0;
    final progress = totalCap > 0 ? (earnedToday / totalCap).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Subtle background accent glow in the top-right corner
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        game.themeColor.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header tag: Featured of the Day
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33FF6B6B),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥', style: TextStyle(fontSize: 12)),
                              SizedBox(width: 4),
                              Text(
                                'FEATURED GAME',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Up to +$totalCap RBX',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.purple,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Image.asset(
                                AppAssets.goldCoin,
                                width: 14,
                                height: 14,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.monetization_on,
                                  size: 14,
                                  color: Color(0xFFFFCC44),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Game Media + Details Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Game Cover Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 76,
                            height: 76,
                            color: game.softBgColor,
                            child: AppCachedImage(
                              imageUrl: game.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: Icon(
                                Icons.sports_esports_rounded,
                                size: 36,
                                color: game.themeColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title, Subtitle, and metadata tags
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF131326),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                game.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF868A9F),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _MetaPill(
                                    icon: Icons.timer_outlined,
                                    label: game.avgTime,
                                  ),
                                  const SizedBox(width: 6),
                                  _MetaPill(
                                    icon: Icons.speed_rounded,
                                    label: game.difficulty,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Daily Cap Progress Bar Strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEDF2F7),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isBlocked
                                    ? 'Daily Cap Reached (100%)'
                                    : 'Daily Coins Progress',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isBlocked
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              Text(
                                isBlocked
                                    ? '$totalCap / $totalCap RBX'
                                    : '$earnedToday / $totalCap RBX',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isBlocked
                                      ? const Color(0xFF64748B)
                                      : AppColors.purple,
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isBlocked
                                    ? const Color(0xFF94A3B8)
                                    : AppColors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Big Action Button
                    GestureDetector(
                      onTap: onPlayTap,
                      child: Container(
                        height: 44,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: isBlocked ? null : AppColors.primaryGradient,
                          color: isBlocked ? const Color(0xFFF1F5F9) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: isBlocked
                              ? Border.all(color: const Color(0xFFE2E8F0))
                              : null,
                          boxShadow: isBlocked
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x3D6035EE),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isBlocked
                                  ? Icons.lock_clock_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: isBlocked
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isBlocked
                                  ? 'Daily Limit Reached • Resets Tonight'
                                  : 'Play Featured Game Now',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isBlocked
                                    ? const Color(0xFF94A3B8)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
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

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 3),
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
