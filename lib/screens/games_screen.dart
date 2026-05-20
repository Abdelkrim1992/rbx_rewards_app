import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';
import 'tap_tap_game_screen.dart';
import 'flappy_jump_game_screen.dart';
import 'math_quiz_screen.dart';
import 'flip_card_game_screen.dart';

class GamesScreen extends StatelessWidget {
  final Function(int) onNavTap;

  const GamesScreen({super.key, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    final games = [
      _GameData(
        imageUrl: AppAssets.tapTapGame,
        title: 'Tap Tap',
        coins: '+200',
        bgColor: const Color(0xFFEAF3FF),
      ),
      _GameData(
        imageUrl: AppAssets.quizMasterGame,
        title: 'Math Quiz',
        coins: '+200',
        bgColor: const Color(0xFFE3F8EB),
      ),
      _GameData(
        imageUrl: AppAssets.flappyJumpGame,
        title: 'Flappy Jump',
        coins: '+200',
        bgColor: const Color(0xFFFFF3E3),
      ),
      _GameData(
        imageUrl: AppAssets.memoryMatchGame,
        title: 'Flip Cards',
        coins: '+200',
        bgColor: const Color(0xFFFFE8F0),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: onNavTap),
                    // Section heading
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
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
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('${game.title} is coming soon! ✨'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
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

  const _GameData({
    required this.imageUrl,
    required this.title,
    required this.coins,
    required this.bgColor,
  });
}

class _GameCard extends StatelessWidget {
  final _GameData data;

  const _GameCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game image
            Expanded(
              child: Container(
                width: double.infinity,
                color: data.bgColor,
                child: data.imageUrl.startsWith('http')
                    ? Image.network(
                        data.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.sports_esports,
                          size: 48,
                          color: data.bgColor == const Color(0xFFEAF3FF)
                              ? Colors.blue
                              : AppColors.primary,
                        ),
                      )
                    : Image.asset(
                        data.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.sports_esports,
                          size: 48,
                          color: data.bgColor == const Color(0xFFEAF3FF)
                              ? Colors.blue
                              : AppColors.primary,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Image.asset(
                              AppAssets.goldCoin,
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.monetization_on,
                                  size: 20,
                                  color: Color(0xFFFFCC44)),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                data.coins,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.purple,
                                ),
                              ),
                            ),
                            const Text(
                              ' RBX',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x446035EE),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow,
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
    );
  }
}
