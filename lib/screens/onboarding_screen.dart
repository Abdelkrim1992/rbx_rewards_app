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
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  // Hero Illustration
                  Flexible(
                    flex: 50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                              horizontal: AppLayout.screenPadding)
                          .copyWith(top: 40),
                      child: Image.asset(
                        AppAssets.onboardingHero,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.dailyCardGradient,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Center(
                            child: Icon(Icons.celebration,
                                size: 100, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF141620),
                            letterSpacing: -0.7,
                            height: 1.2,
                          ),
                          children: [
                            TextSpan(text: 'Earn '),
                            TextSpan(
                              text: 'RBX Rewards ',
                              style: TextStyle(color: Color(0xFF5637E6)),
                            ),
                            TextSpan(text: 'Daily'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Subtitle
                  const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Play mini games, spin the wheel,\nand collect reward coins.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF717688),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  // Feature cards
                  const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _FeatureCard(
                              imagePath:
                                  'assets/images/first_feature_card.jpeg',
                              title: 'Play Games',
                              subtitle: 'Fun mini games to earn coins',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FeatureCard(
                              imagePath:
                                  'assets/images/second_feature_card.jpeg',
                              title: 'Spin & Win',
                              subtitle: 'Spin the wheel for big prizes',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FeatureCard(
                              imagePath:
                                  'assets/images/thirty_feature_card.jpeg',
                              title: 'Unlock Rewards',
                              subtitle: 'Redeem coins for amazing rewards',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 5),
                ],
              ),
            ),
            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppLayout.screenPadding, 0, AppLayout.screenPadding, 30),
              child: Center(
                child: _GetStartedButton(onTap: onGetStarted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  final VoidCallback onTap;

  const _GetStartedButton({required this.onTap});

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.0,
    upperBound: 0.05,
  );

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - _controller.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          height: 55,
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
                  letterSpacing: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 1,
                      offset: Offset(0, 1),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    imagePath,
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.star,
                        color: AppColors.primary, size: 24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF181A24),
              letterSpacing: -0.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8E93A2),
                height: 1.3,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
