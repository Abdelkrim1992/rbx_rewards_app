import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/welcome_bonus_overlay.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onGetStarted;

  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _handleStartEarning() async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    HapticFeedback.mediumImpact();

    // Show the animated bonus overlay; actual navigation happens after
    // dismiss animation, while coin credit happens instantly on tap.
    if (!mounted) return;
    WelcomeBonusOverlay.show(
      context,
      onClaimStart: () => _startBonusCredit(),
      onClaimed: () => _claimBonusAndNavigate(),
    );

    // Reset so button is tappable again if user somehow dismisses
    if (mounted) setState(() => _isClaiming = false);
  }

  bool _bonusCredited = false;

  void _startBonusCredit() {
    if (_bonusCredited) return;
    _bonusCredited = true;

    // 1. Immediately & synchronously credit in-memory balance on the exact frame of the tap!
    try {
      final currentCoins = ref.read(coinProvider);
      final newBalance = currentCoins > 0 ? currentCoins + 50 : 50;
      ref.read(coinProvider.notifier).updateBalance(newBalance);
      ref.read(dailyCapServiceProvider).addCoins(50, 'welcome_bonus');
    } catch (e) {
      debugPrint('Error updating in-memory balance: $e');
    }

    // 2. Persist to storage and sync with backend in background
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('welcome_bonus_claimed', true);

        final currentCoins = ref.read(coinProvider);
        final newBalance = currentCoins > 0 ? currentCoins : 50;
        await ref.read(secureRepositoryProvider).saveBalance(newBalance);

        ref.read(supabaseRepositoryProvider).claimWelcomeBonus().then((result) {
          final balance =
              result['balance'] as int? ?? result['new_balance'] as int?;
          if (balance != null && balance > 0) {
            ref.read(coinProvider.notifier).updateBalance(balance);
          }
        }).catchError((e) {
          debugPrint('claimWelcomeBonus network error: $e');
        });
      } catch (e) {
        debugPrint('Error persisting bonus credit: $e');
      }
    }();
  }

  /// Credits the welcome bonus and navigates to home.
  Future<void> _claimBonusAndNavigate() async {
    _startBonusCredit();
    widget.onGetStarted();
  }

  Future<void> _handleSignInWithGoogle() async {
    try {
      final auth = ref.read(authServiceProvider);
      final isInitiated = await auth.signInWithGoogle();
      if (isInitiated && mounted) {
        widget.onGetStarted();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenHeight < 680;
    final logoHeight = screenHeight * 0.045;
    final topPadding = screenHeight * 0.018;
    final bottomPadding = screenHeight * 0.028;
    final dotsButtonGap = screenHeight * 0.018;
    final hPad = screenWidth * 0.055;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Centered Logo Header (no Sign In button)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    topPadding,
                    hPad,
                    topPadding * 0.5,
                  ),
                  child: Center(
                    child: Image.asset(
                      AppAssets.rbxLogo,
                      height: logoHeight.clamp(28.0, 44.0),
                      fit: BoxFit.contain,
                      cacheHeight: 140,
                      errorBuilder: (_, __, ___) => const Text(
                        'RBX Play & Earn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3-Step Interactive PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _StepOneContent(isCompact: isCompact),
                      _StepTwoContent(isCompact: isCompact),
                      _StepThreeContent(isCompact: isCompact),
                    ],
                  ),
                ),

                // Bottom Navigation Zone (Dots + Gradient CTA)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    dotsButtonGap * 0.6,
                    hPad,
                    bottomPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DotsIndicator(currentPage: _currentPage),
                      SizedBox(height: dotsButtonGap),
                      _PrimaryActionButton(
                        label: _currentPage == 0
                            ? 'Get Started'
                            : _currentPage == 1
                                ? 'Continue'
                                : 'Start Earning',
                        isLoading: _isClaiming && _currentPage == 2,
                        onTap: _currentPage < 2
                            ? _nextPage
                            : _handleStartEarning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Earn RBX Rewards Daily (Hero Avatar + 3 Mini Feature Cards)
// ---------------------------------------------------------------------------
class _StepOneContent extends StatelessWidget {
  final bool isCompact;

  const _StepOneContent({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroFlex = isCompact ? 5 : 6;
    final cardHeight = (screenHeight * 0.115).clamp(80.0, 110.0);
    final vGapSm = screenHeight * 0.014;
    final vGapMd = screenHeight * 0.022;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Hero 3D Roblox Avatar illustration
          Expanded(
            flex: heroFlex,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, isCompact ? 4 : 8, 8, 0),
              child: AppCachedImage(
                imageUrl: AppAssets.onboardingHero,
                fallbackAsset: AppAssets.onboardingHero,
                fit: BoxFit.contain,
                errorWidget: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.dailyCardGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.celebration,
                      size: 80,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: vGapSm),

          // Title & Subtitle
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF101828),
                  letterSpacing: -0.6,
                  height: 1.18,
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
          const SizedBox(height: 5),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Play mini games, complete activities,\nand collect reward coins.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667085),
                height: 1.3,
              ),
            ),
          ),

          SizedBox(height: vGapMd),

          // 3 Feature Cards Row
          SizedBox(
            height: cardHeight,
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MiniFeatureCard(
                    imagePath: AppAssets.firstFeatureCard,
                    title: 'Play Games',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _MiniFeatureCard(
                    imagePath: AppAssets.secondFeatureCard,
                    title: 'Spin & Win',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _MiniFeatureCard(
                    imagePath: AppAssets.thirtyFeatureCard,
                    title: 'Unlock Rewards',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: vGapSm),
        ],
      ),
    );
  }
}

class _MiniFeatureCard extends StatelessWidget {
  final String imagePath;
  final String title;

  const _MiniFeatureCard({
    required this.imagePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F5FD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x125637E6)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                imagePath,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                cacheWidth: 120,
                cacheHeight: 120,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.star,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D2939),
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Play. Earn. Redeem. (3 Vertical Step Cards with Badges)
// ---------------------------------------------------------------------------
class _StepTwoContent extends StatelessWidget {
  final bool isCompact;

  const _StepTwoContent({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final vGapTop = screenHeight * 0.012;
    final vGapCards = (screenHeight * 0.016).clamp(8.0, 18.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: vGapTop),

          // Title & Subtitle
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF101828),
                  letterSpacing: -0.6,
                  height: 1.18,
                ),
                children: [
                  TextSpan(text: 'Play. '),
                  TextSpan(
                    text: 'Earn. ',
                    style: TextStyle(color: Color(0xFF5637E6)),
                  ),
                  TextSpan(text: 'Redeem.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Three simple steps to exciting rewards.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667085),
              ),
            ),
          ),

          SizedBox(height: vGapCards),

          // 3 Step Cards — fill remaining space evenly
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepCard(
                  stepNumber: '1',
                  title: 'Play',
                  description: 'Complete mini games\nand activities.',
                  imagePath: AppAssets.onboardingGame,
                  isCompact: isCompact,
                ),
                SizedBox(height: vGapCards),
                _StepCard(
                  stepNumber: '2',
                  title: 'Earn',
                  description: 'Collect RBX Coins as\nyou complete activities.',
                  imagePath: AppAssets.onboardingCoin,
                  isCompact: isCompact,
                ),
                SizedBox(height: vGapCards),
                _StepCard(
                  stepNumber: '3',
                  title: 'Redeem',
                  description: 'Use your RBX Coins\ntoward available rewards.',
                  imagePath: AppAssets.onboardingReward,
                  isCompact: isCompact,
                ),
              ],
            ),
          ),
          SizedBox(height: vGapTop),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String description;
  final String imagePath;
  final bool isCompact;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final imageSize = isCompact ? 58.0 : 76.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Step number badge
          Container(
            width: isCompact ? 32 : 38,
            height: isCompact ? 32 : 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEEECFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  fontSize: isCompact ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5637E6),
                ),
              ),
            ),
          ),
          SizedBox(width: isCompact ? 12 : 16),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF101828),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 3D Feature Graphic
          SizedBox(
            width: imageSize,
            height: imageSize,
            child: AppCachedImage(
              imageUrl: imagePath,
              fallbackAsset: imagePath,
              fit: BoxFit.contain,
              width: imageSize,
              height: imageSize,
              errorWidget: const Icon(
                Icons.stars_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Your first reward is waiting (Bursting Gift Box + +50 Coins Bonus)
// ---------------------------------------------------------------------------
class _StepThreeContent extends StatelessWidget {
  final bool isCompact;

  const _StepThreeContent({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final vGapTop = screenHeight * 0.012;
    final vGapMd = screenHeight * 0.018;
    final coinSize = (screenHeight * 0.07).clamp(44.0, 62.0);
    final cardPad = (screenHeight * 0.02).clamp(10.0, 18.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(height: vGapTop),

          // Title & Subtitle
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF101828),
                  letterSpacing: -0.6,
                  height: 1.18,
                ),
                children: [
                  TextSpan(text: 'Your first '),
                  TextSpan(
                    text: 'reward\n',
                    style: TextStyle(color: Color(0xFF5637E6)),
                  ),
                  TextSpan(text: 'is waiting'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Start earning RBX Coins by completing your first activity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667085),
              ),
            ),
          ),

          // Bursting Open Gift Box with Coins & Confetti
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: vGapMd),
              child: AppCachedImage(
                imageUrl: AppAssets.onboardingGiftBox,
                fallbackAsset: AppAssets.onboardingGiftBox,
                fit: BoxFit.contain,
                errorWidget: Image.asset(
                  AppAssets.dailyRewardGift,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Welcome Bonus Card (+50 RBX Coins & Milestone)
          Container(
            padding: EdgeInsets.all(cardPad),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coins + +50 RBX Coins Row
                Row(
                  children: [
                    AppCachedImage(
                      imageUrl: AppAssets.goldRbxCoin,
                      fallbackAsset: AppAssets.goldRbxCoin,
                      width: coinSize,
                      height: coinSize,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+50',
                          style: TextStyle(
                            fontSize: isCompact ? 28 : 32,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF5637E6),
                            letterSpacing: -0.8,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          'RBX Coins',
                          style: TextStyle(
                            fontSize: isCompact ? 14 : 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF101828),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: isCompact ? 8 : 12),

                // Milestone Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F5FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0x185637E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          size: 14,
                          color: Color(0xFF5637E6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your first milestone',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5637E6),
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Complete an activity to claim it.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF667085),
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
          SizedBox(height: vGapTop),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3-Dots Indicator
// ---------------------------------------------------------------------------
class _DotsIndicator extends StatelessWidget {
  final int currentPage;

  const _DotsIndicator({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color:
                isActive ? const Color(0xFF5637E6) : const Color(0xFFE0DCFA),
            borderRadius: BorderRadius.circular(3.5),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Primary Action Button (Gradient with forward arrow & haptics)
// ---------------------------------------------------------------------------
class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _PrimaryActionButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 0.03,
  );

  void _onTapDown(TapDownDetails details) {
    if (widget.isLoading) return;
    HapticFeedback.lightImpact();
    _controller.forward();
  }

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
      onTap: widget.isLoading ? null : widget.onTap,
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
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D5637E6),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else ...[
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
