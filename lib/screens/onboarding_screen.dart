import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onGetStarted;

  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Hero Illustration
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Image.network(
                        AppAssets.heroIllustration,
                        height: 311,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 311,
                          decoration: BoxDecoration(
                            gradient: AppColors.dailyCardGradient,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.celebration,
                              size: 120, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF141620),
                            letterSpacing: -0.7,
                            height: 1.2,
                          ),
                          children: [
                            TextSpan(text: 'Earn '),
                            TextSpan(
                              text: 'RBX Rewards',
                              style: TextStyle(color: Color(0xFF5637E6)),
                            ),
                            TextSpan(text: '\nDaily'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Subtitle
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Play mini games, spin the wheel,\nand collect reward coins.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF717688),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Feature cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        children: [
                          _FeatureCard(
                            iconUrl: AppAssets.gamepadIcon,
                            title: 'Play Games',
                            subtitle: 'Fun mini games\nto earn coins',
                          ),
                          const SizedBox(width: 10),
                          _FeatureCard(
                            iconUrl: AppAssets.prizeWheelIcon,
                            title: 'Spin & Win',
                            subtitle: 'Spin the wheel\nfor big prizes',
                          ),
                          const SizedBox(width: 10),
                          _FeatureCard(
                            iconUrl: AppAssets.treasureChestIcon,
                            title: 'Unlock Rewards',
                            subtitle: 'Redeem coins\nfor amazing\nrewards',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: GestureDetector(
                onTap: onGetStarted,
                child: Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x736035EE),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.425,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String iconUrl;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.iconUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 19, 7, 17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F141432),
              blurRadius: 24,
              offset: Offset(0, 8),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  iconUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.star, color: AppColors.primary, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF181A24),
                letterSpacing: -0.125,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8E93A2),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
