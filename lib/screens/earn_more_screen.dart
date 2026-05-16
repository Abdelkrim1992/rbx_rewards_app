import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'chest_screen.dart';

class EarnMoreScreen extends StatelessWidget {
  final Function(int)? onNavTap;

  const EarnMoreScreen({super.key, this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF131326), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Earn More',
          style: TextStyle(
            color: Color(0xFF131326),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            const Text(
              'More ways to earn points every day!',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF868A9F),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
                children: [
                  _EarnRowCard(
                    iconUrl: AppAssets.spinWheelIcon,
                    fallbackIcon: Icons.track_changes,
                    iconBgColor: const Color(0xFFF3EAFD),
                    iconColor: AppColors.primary,
                    title: 'Spin',
                    subtitle: 'Spin the wheel and\nwin points!',
                    badgeText: 'Up to 1,000',
                    onTap: () {
                      if (onNavTap != null) {
                        Navigator.pop(context);
                        onNavTap!(1); // Navigate to spin tab
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _EarnRowCard(
                    iconUrl: AppAssets.chestIcon,
                    fallbackIcon: Icons.work,
                    iconBgColor: const Color(0xFFF3EEFD),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Treasure Chest',
                    subtitle: 'Open chests and get\namazing rewards!',
                    badgeText: 'Up to 500',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChestScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _EarnRowCard(
                    iconUrl: AppAssets.missionsIcon,
                    fallbackIcon: Icons.assignment_turned_in,
                    iconBgColor: const Color(0xFFF3EEFD),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Missions',
                    subtitle: 'Complete tasks and\nearn big!',
                    badgeText: 'Up to 300',
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  _EarnRowCard(
                    iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/calculator-5591322-4652971.png',
                    fallbackIcon: Icons.calculate,
                    iconBgColor: const Color(0xFFF3EEFD),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Calculator',
                    subtitle: 'Solve simple calculations\nand earn rewards!',
                    badgeText: 'Up to 250',
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  _EarnRowCard(
                    iconUrl: AppAssets.quizMasterGame,
                    fallbackIcon: Icons.school,
                    iconBgColor: const Color(0xFFF3EEFD),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Quizzes',
                    subtitle: 'Answer quizzes and\nearn smart!',
                    badgeText: 'Up to 400',
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  _EarnRowCard(
                    iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/scratch-card-9477045-7687848.png', // Temporary placeholder for Scratch Cards
                    fallbackIcon: Icons.local_play,
                    iconBgColor: const Color(0xFFF3EEFD),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Scratch Cards',
                    subtitle: 'Scratch and reveal\nexciting rewards!',
                    badgeText: 'Up to 350',
                    onTap: () {},
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarnRowCard extends StatelessWidget {
  final String iconUrl;
  final IconData fallbackIcon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback onTap;

  const _EarnRowCard({
    required this.iconUrl,
    required this.fallbackIcon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Icon Container
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Image.network(
                  iconUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    fallbackIcon,
                    size: 32,
                    color: iconColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Middle Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131326),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF868A9F),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // Right Elements (Arrow + Badge)
            SizedBox(
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF), 
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EAFD), // light purple background
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary, 
                          ),
                        ),
                        const SizedBox(width: 4),
                        Image.network(
                          AppAssets.goldRbxCoin,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
