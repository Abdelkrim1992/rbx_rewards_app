import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onNavTap;

  const HomeScreen({super.key, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: const RbxAppHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome greeting
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Row(
                        children: [
                          const Text(
                            'Welcome back!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF131326),
                              letterSpacing: -0.55,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.network(
                            AppAssets.wavingHand,
                            width: 26,
                            height: 26,
                            errorBuilder: (_, __, ___) =>
                                const Text('👋', style: TextStyle(fontSize: 22)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Balance Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 2,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Image.network(
                                  AppAssets.goldRbxCoin,
                                  width: 52,
                                  height: 52,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.monetization_on,
                                    size: 52,
                                    color: Color(0xFFFFCC44),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'YOUR RBX BALANCE',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF868A9F),
                                        letterSpacing: 0.3,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: const [
                                        Text(
                                          '525',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF131326),
                                            letterSpacing: -0.7,
                                            height: 1.0,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'RBX Coins',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF868A9F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Opacity(
                              opacity: 0.5,
                              child: Image.network(
                                AppAssets.arrowRight,
                                width: 14,
                                height: 14,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF868A9F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Daily Reward Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.dailyCardGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33664DFF),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 22, 4, 22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Daily RBX\nReward is ready!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF131326),
                                        letterSpacing: -0.5,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Come back every day and\nclaim awesome rewards.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF4A4B60),
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 34,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x736035EE),
                                            blurRadius: 16,
                                            offset: Offset(0, 8),
                                            spreadRadius: -4,
                                          )
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Claim Now',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                                child: Image.network(
                                  AppAssets.purpleGiftBox,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.card_giftcard,
                                    size: 60,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Actions header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SectionHeader(
                        title: 'Quick Actions',
                        linkText: 'Show all actions',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Actions grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          _QuickActionCard(
                            iconUrl: AppAssets.chestIcon,
                            title: 'Chest',
                            badge: 'Ready',
                          ),
                          const SizedBox(width: 10),
                          _QuickActionCard(
                            iconUrl: AppAssets.spinWheelIcon,
                            title: 'Spin & Win',
                            badge: 'Ready',
                            onTap: () => onNavTap(1),
                          ),
                          const SizedBox(width: 10),
                          _QuickActionCard(
                            iconUrl: AppAssets.missionsIcon,
                            title: 'Missions',
                            badge: '3/6',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Play to Earn header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SectionHeader(
                        title: 'Play to Earn',
                        linkText: 'Show all games',
                        onTap: () => onNavTap(1),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Games row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.tapTapGame,
                              title: 'Tap Tap',
                              coins: '+200 RBX',
                              bgColor: const Color(0xFFEAF3FF),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.quizMasterGame,
                              title: 'Quiz Master',
                              coins: '+150 RBX',
                              bgColor: const Color(0xFFE3F8EB),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.memoryMatchGame,
                              title: 'Memory Match',
                              coins: '+250 RBX',
                              bgColor: const Color(0xFFEBE7FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tasks & Offers header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SectionHeader(
                        title: 'Task & Offers',
                        linkText: 'Show all offers',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Task banner
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EAFD),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D6235F6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.network(
                                  AppAssets.clipboardIcon,
                                  width: 60,
                                  height: 60,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.assignment,
                                    size: 50,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Complete tasks & earn\nRBX Coins!',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF0A0F2C),
                                          height: 1.38,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Finish offers and daily tasks to\nget amazing rewards.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF475569),
                                          height: 1.38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6235F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Start Earning',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: RbxBottomNav(currentIndex: 0, onTap: onNavTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String linkText;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.linkText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF131326),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                linkText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.purple),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String iconUrl;
  final String title;
  final String badge;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.iconUrl,
    required this.title,
    required this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Image.network(
                iconUrl,
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.star,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF131326),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.purple,
                    letterSpacing: 0.275,
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

class _GameCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String coins;
  final Color bgColor;

  const _GameCard({
    required this.imageUrl,
    required this.title,
    required this.coins,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              height: 76,
              color: bgColor,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.sports_esports,
                  size: 50,
                  color: bgColor == const Color(0xFFEAF3FF)
                      ? Colors.blue
                      : bgColor == const Color(0xFFE3F8EB)
                          ? Colors.green
                          : AppColors.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF131326),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Image.network(
                        AppAssets.goldCoin,
                        width: 13,
                        height: 13,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.monetization_on,
                                size: 13, color: Color(0xFFFFCC44)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        coins,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF868A9F),
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
    );
  }
}
