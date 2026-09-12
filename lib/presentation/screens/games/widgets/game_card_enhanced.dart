import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_cached_image.dart';
import '../models/game_item_data.dart';

class GameCardEnhanced extends StatefulWidget {
  final GameItemData game;
  final int earnedToday;
  final int totalCap;
  final int remainingCap;
  final VoidCallback onTap;
  final VoidCallback onQuickPlay;

  const GameCardEnhanced({
    super.key,
    required this.game,
    required this.earnedToday,
    required this.totalCap,
    required this.remainingCap,
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
    final isBlocked = widget.remainingCap <= 0;
    final progress = widget.totalCap > 0
        ? (widget.earnedToday / widget.totalCap).clamp(0.0, 1.0)
        : 0.0;

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
        child: AnimatedOpacity(
          opacity: isBlocked ? 0.72 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isBlocked ? const Color(0xFFE2E8F0) : AppColors.cardBorder,
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game Image with floating badge
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
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

                          // Dynamic Badge in Top Left
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isBlocked
                                    ? const Color(0xFF64748B)
                                    : game.badgeColor,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x2E000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                isBlocked ? 'CAPPED' : game.badgeText,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),

                          // Time badge in Top Right
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 10,
                                    color: Colors.white70,
                                  ),
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
                  ),

                  // Game Info & Progress Area
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          game.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF131326),
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Subtitle
                        Text(
                          game.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF868A9F),
                          ),
                        ),
                        const SizedBox(height: 7),

                        // Cap Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4.5,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isBlocked
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.purple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Progress text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isBlocked ? 'Limit reached' : 'Earned today',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              '${widget.earnedToday}/${widget.totalCap}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isBlocked
                                    ? const Color(0xFF94A3B8)
                                    : AppColors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),

                        // Bottom Action Row (Coin Pill + Quick Play Button)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Remaining coins pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: isBlocked
                                    ? const Color(0xFFF1F5F9)
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isBlocked
                                        ? 'Capped'
                                        : '+${widget.remainingCap} RBX',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: isBlocked
                                          ? const Color(0xFF94A3B8)
                                          : AppColors.purple,
                                    ),
                                  ),
                                  if (!isBlocked) ...[
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
                                ],
                              ),
                            ),

                            // Play button
                            GestureDetector(
                              onTap: widget.onQuickPlay,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: isBlocked
                                      ? null
                                      : AppColors.primaryGradient,
                                  color: isBlocked ? const Color(0xFFE2E8F0) : null,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isBlocked
                                      ? null
                                      : const [
                                          BoxShadow(
                                            color: Color(0x336035EE),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Icon(
                                  isBlocked
                                      ? Icons.lock_outline_rounded
                                      : Icons.play_arrow_rounded,
                                  color: isBlocked
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white,
                                  size: 16,
                                ),
                              ),
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
        ),
      ),
    );
  }
}
