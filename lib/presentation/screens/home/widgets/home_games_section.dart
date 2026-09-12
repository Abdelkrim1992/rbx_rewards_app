import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_cached_image.dart';

class HomeGameItemData {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int remainingCoins;
  final Color bgColor;
  final VoidCallback onTap;

  const HomeGameItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.remainingCoins,
    required this.bgColor,
    required this.onTap,
  });
}

class HomeGamesSection extends StatelessWidget {
  final List<HomeGameItemData> games;
  final VoidCallback onViewAll;

  const HomeGamesSection({
    super.key,
    required this.games,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.screenPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Play to Earn',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131326),
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.elementSpacing),

        // Horizontal Games Shelf
        SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.screenPadding,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final game = games[index];
              return _GameShelfCard(game: game);
            },
          ),
        ),
      ],
    );
  }
}

class _GameShelfCard extends StatefulWidget {
  final HomeGameItemData game;

  const _GameShelfCard({required this.game});

  @override
  State<_GameShelfCard> createState() => _GameShelfCardState();
}

class _GameShelfCardState extends State<_GameShelfCard> {
  double _scale = 1.0;

  String _getGameBadge(String id) {
    switch (id) {
      case 'tap_tap':
        return '🔥 Hot';
      case 'math_quiz':
        return '⚡ Quick';
      case 'flappy_jump':
        return '🎯 Arcade';
      case 'flip_card':
        return '🧠 Memory';
      case 'quizzes':
        return '🏆 Trivia';
      default:
        return '⚡ Fast';
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isBlocked = game.remainingCoins <= 0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        game.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 140,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cover Image Banner with overlay badge
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        height: 84,
                        width: double.infinity,
                        color: game.bgColor,
                        child: AppCachedImage(
                          imageUrl: game.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: Icon(
                            Icons.sports_esports,
                            size: 38,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: isBlocked
                                ? const Color(0xCC475569)
                                : const Color(0xD90F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBlocked ? '✓ Done' : _getGameBadge(game.id),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  game.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF131326),
                  ),
                ),
              ),
              const SizedBox(height: 2),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  game.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF868A9F),
                  ),
                ),
              ),
              const Spacer(),

              // Coin Reward Badge
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? const Color(0xFFF1F5F9)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isBlocked ? 'Limit Reached' : '+${game.remainingCoins} RBX',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isBlocked
                              ? const Color(0xFF94A3B8)
                              : AppColors.primary,
                        ),
                      ),
                      if (!isBlocked) ...[
                        const SizedBox(width: 3),
                        Image.asset(
                          AppAssets.goldCoin,
                          width: 13,
                          height: 13,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            size: 13,
                            color: Color(0xFFFFCC44),
                          ),
                        ),
                      ],
                    ],
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
