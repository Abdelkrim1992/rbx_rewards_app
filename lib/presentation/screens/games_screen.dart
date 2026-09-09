import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/app_cached_image.dart';
import '../providers/providers.dart';
import 'leaderboard_screen.dart';
import 'tap_tap_game_screen.dart';
import 'flappy_jump_game_screen.dart';
import 'math_quiz_screen.dart';
import 'flip_card_game_screen.dart';
import 'scratch_card_screen.dart';

class GamesScreen extends ConsumerWidget {
  final Function(int) onNavTap;

  const GamesScreen({super.key, required this.onNavTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capService = ref.watch(dailyCapServiceProvider);
    
    final tapTapRemaining = capService.getRemainingCap('tap_tap');
    final mathQuizRemaining = capService.getRemainingCap('math_quiz');
    final flappyRemaining = capService.getRemainingCap('flappy_jump');
    final flipRemaining = capService.getRemainingCap('flip_card');
    final scratchRemaining = capService.getRemainingCap('scratch');

    final games = [
      _GameData(
        imageUrl: AppAssets.tapTapGame,
        title: 'Tap Tap',
        coins: '+$tapTapRemaining RBX',
        isBlocked: tapTapRemaining <= 0,
        bgColor: const Color(0xFFEAF3FF),
      ),
      _GameData(
        imageUrl: AppAssets.quizMasterGame,
        title: 'Math Quiz',
        coins: '+$mathQuizRemaining RBX',
        isBlocked: mathQuizRemaining <= 0,
        bgColor: const Color(0xFFE3F8EB),
      ),
      _GameData(
        imageUrl: AppAssets.flappyJumpGame,
        title: 'Flappy Jump',
        coins: '+ $flappyRemaining RBX',
        isBlocked: flappyRemaining <= 0,
        bgColor: const Color(0xFFFFF3E3),
      ),
      _GameData(
        imageUrl: AppAssets.memoryMatchGame,
        title: 'Flip Cards',
        coins: '+ $flipRemaining RBX',
        isBlocked: flipRemaining <= 0,
        bgColor: const Color(0xFFFFE8F0),
      ),
      _GameData(
        imageUrl: AppAssets.dailyRewardImage,
        title: 'Scratch Card',
        coins: '+ $scratchRemaining RBX',
        isBlocked: scratchRemaining <= 0,
        bgColor: const Color(0xFFEAF3FF),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshableScrollView(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: onNavTap),
                    // Section heading with Leaderboard button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Play & Earn',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF131326),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Complete mini games to collect RBX coins',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF868A9F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LeaderboardScreen(
                                    onBack: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Leaderboard',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
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
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Game cards grid
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: games.length,
                        itemBuilder: (ctx, i) {
                          final game = games[i];
                          return GestureDetector(
                            onTap: () {
                              if (game.isBlocked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Daily limit reached for ${game.title}!'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: AppColors.purple,
                                  ),
                                );
                                return;
                              }
                              if (game.title == 'Tap Tap') {
                                Navigator.of(context)
                                    .push<int>(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TapTapGameScreen(),
                                  ),
                                )
                                    .then((coinsEarned) {
                                  if (coinsEarned != null) {
                                    onNavTap(0);
                                  }
                                });
                              } else if (game.title == 'Flappy Jump') {
                                Navigator.of(context)
                                    .push<int>(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FlappyJumpGameScreen(),
                                  ),
                                )
                                    .then((coinsEarned) {
                                  if (coinsEarned != null) {
                                    onNavTap(0);
                                  }
                                });
                              } else if (game.title == 'Math Quiz') {
                                Navigator.of(context)
                                    .push<int>(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MathQuizScreen(),
                                  ),
                                )
                                    .then((coinsEarned) {
                                  if (coinsEarned != null) {
                                    onNavTap(0);
                                  }
                                });
                              } else if (game.title == 'Flip Cards') {
                                Navigator.of(context)
                                    .push<int>(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FlipCardGameScreen(),
                                  ),
                                )
                                    .then((coinsEarned) {
                                  if (coinsEarned != null) {
                                    onNavTap(0);
                                  }
                                });
                              } else if (game.title == 'Scratch Card') {
                                Navigator.of(context)
                                    .push<void>(
                                  MaterialPageRoute(
                                    builder: (context) => ScratchCardScreen(
                                      onBack: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                )
                                    .then((_) {
                                  // Re-fetch cap values if scratch state changed
                                });
                              }
                            },
                            child: _GameCard(data: game),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Coming soon banner
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primarySoft,
                              AppColors.primarySoft.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.purple.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.lock,
                                  color: AppColors.purple, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'More games coming soon ✨',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                            const Icon(Icons.layers,
                                color: AppColors.purple, size: 32),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RbxBottomNav(currentIndex: 1, onTap: onNavTap),
        ),
      ),
    );
  }
}

class _GameData {
  final String imageUrl;
  final String title;
  final String coins;
  final Color bgColor;
  final bool isBlocked;

  const _GameData({
    required this.imageUrl,
    required this.title,
    required this.coins,
    required this.bgColor,
    required this.isBlocked,
  });
}

class _GameCard extends StatelessWidget {
  final _GameData data;

  const _GameCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: data.isBlocked ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game image with padding and rounded corners
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      color: data.bgColor,
                      child: AppCachedImage(
                        imageUrl: data.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Icon(
                          Icons.sports_esports,
                          size: 48,
                          color: data.bgColor == const Color(0xFFEAF3FF)
                              ? Colors.blue
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: data.isBlocked
                                    ? const Color(0xFFF1F5F9)
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      data.coins,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: data.isBlocked
                                            ? Colors.grey
                                            : AppColors.purple,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Image.asset(
                                    AppAssets.goldCoin,
                                    width: 18,
                                    height: 18,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.monetization_on,
                                      size: 18,
                                      color: data.isBlocked
                                          ? Colors.grey
                                          : const Color(0xFFFFCC44),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: data.isBlocked ? null : AppColors.primaryGradient,
                            color: data.isBlocked ? Colors.grey : null,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: data.isBlocked
                                ? null
                                : const [
                                    BoxShadow(
                                      color: Color(0x446035EE),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Icon(data.isBlocked ? Icons.lock : Icons.play_arrow,
                              color: Colors.white, size: 16),
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
    );
  }
}
