import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';

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
        imageUrl: AppAssets.memoryMatchGame,
        title: 'Memory Match',
        coins: '+200',
        bgColor: const Color(0xFFEBE7FF),
      ),
      _GameData(
        imageUrl: AppAssets.quizMasterGame,
        title: 'Quiz Master',
        coins: '+200',
        bgColor: const Color(0xFFE3F8EB),
      ),
      _GameData(
        imageUrl: AppAssets.flappyJumpGame,
        title: 'Flappy Jump',
        coins: '+200',
        bgColor: const Color(0xFFFFF3E3),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RbxAppHeader(),
                    // Section heading
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Expanded(
                            child: Text(
                              'Play & Earn',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF131326),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Complete mini games to collect RBX coins',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF868A9F),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Game cards grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: games.length,
                        itemBuilder: (ctx, i) => _GameCard(data: games[i]),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Coming soon banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: RbxBottomNav(currentIndex: 1, onTap: onNavTap),
            ),
          ],
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game image
            Container(
              height: 110,
              width: double.infinity,
              color: data.bgColor,
              child: Image.network(
                data.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.sports_esports,
                  size: 60,
                  color: data.bgColor == const Color(0xFFEAF3FF)
                      ? Colors.blue
                      : AppColors.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.network(
                            AppAssets.goldCoin,
                            width: 13,
                            height: 13,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.monetization_on,
                                size: 13,
                                color: Color(0xFFFFCC44)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data.coins,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purple,
                            ),
                          ),
                          const Text(
                            ' RBX',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
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
