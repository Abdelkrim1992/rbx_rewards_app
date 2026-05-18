import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';
import 'chest_screen.dart';
import 'tap_tap_game_screen.dart';
import 'flappy_jump_game_screen.dart';
import 'earn_more_screen.dart';
import '../widgets/game_prefs.dart';
import 'quizzes_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavTap;
  final VoidCallback onSpinTap;

  const HomeScreen({
    super.key,
    required this.onNavTap,
    required this.onSpinTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _balance = 525;
  bool _isDailyClaimed = false;
  bool _isMegaChestClaimed = false;
  DateTime? _lastClaimTime;
  Timer? _countdownTimer;
  Duration _timeUntilNextClaim = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final coins = await GamePrefs.getCoins();
    final isMegaChestClaimed = await GamePrefs.isMegaChestClaimed();
    setState(() {
      _balance = coins;
      _isMegaChestClaimed = isMegaChestClaimed;
    });
  }

  Future<void> _claimMegaChest() async {
    const reward = 500;
    final newBalance = _balance + reward;

    setState(() {
      _balance = newBalance;
      _isMegaChestClaimed = true;
    });

    await GamePrefs.saveCoins(newBalance);
    await GamePrefs.setMegaChestClaimed(true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mega Chest opened! You earned 500 RBX 🎉'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _lastClaimTime = DateTime.now();
    _countdownTimer?.cancel();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (!mounted) return;
    if (_lastClaimTime == null) return;
    final now = DateTime.now();
    final nextClaimTime = _lastClaimTime!.add(const Duration(hours: 24));

    if (now.isAfter(nextClaimTime)) {
      _countdownTimer?.cancel();
      setState(() {
        _isDailyClaimed = false;
        _timeUntilNextClaim = Duration.zero;
      });
    } else {
      setState(() {
        _timeUntilNextClaim = nextClaimTime.difference(now);
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _showRewardPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Daily Reward!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF131326),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You have earned',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF868A9F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        AppAssets.goldRbxCoin,
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.monetization_on,
                          color: Color(0xFFFFCC44),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '+100 RBX',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _InteractiveCard(
                  onTap: () {
                    Navigator.of(context).pop();
                    _completeClaim();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _completeClaim() {
    setState(() {
      _isDailyClaimed = true;
      _balance += 100;
    });
    GamePrefs.saveCoins(_balance);
    _startCountdown();
  }

  void _claimDaily() {
    if (_isDailyClaimed) return;
    _showRewardPopup();
  }

  Future<void> _showSurveyDialog() async {
    final coinsEarned = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SurveyDialog(),
    );

    if (!mounted) return;
    if (coinsEarned != null && coinsEarned > 0) {
      await _loadBalance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully claimed +250 RBX Coins! 📋'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showScratchDialog() async {
    final coinsEarned = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ScratchRewardDialog(),
    );

    if (!mounted) return;
    if (coinsEarned != null && coinsEarned > 0) {
      await _loadBalance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scratch reward claimed +$coinsEarned RBX Coins! 🎁'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 20, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: widget.onNavTap),
                    // Welcome greeting
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131326),
                              letterSpacing: -0.55,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('👋', style: TextStyle(fontSize: 22)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Balance Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _InteractiveCard(
                        onTap: () => widget.onNavTap(2), // Navigate to Rewards
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    AppAssets.goldRbxCoin,
                                    width: 50,
                                    height: 50,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.monetization_on,
                                      size: 50,
                                      color: Color(0xFFFFCC44),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'YOUR RBX BALANCE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF868A9F),
                                          letterSpacing: 0.8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('$_balance',
                                              style: const TextStyle(
                                                fontSize: 27,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF131326),
                                                letterSpacing: 0,
                                                height: 1.0,
                                              )),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'RBX Coins',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF868A9F),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFFD1D5DB),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Daily Reward Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.dailyCardGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 68, 41, 159)
                                  .withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 20, 0, 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isDailyClaimed
                                          ? 'Reward Claimed\nSee you tomorrow'
                                          : 'Daily Reward',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF131326),
                                        letterSpacing: -0.5,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isDailyClaimed
                                          ? 'You earned 100 coins today.'
                                          : 'Come back every day and claim awesome rewards.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4A4B60),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _InteractiveCard(
                                      onTap:
                                          _isDailyClaimed ? null : _claimDaily,
                                      child: Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        decoration: BoxDecoration(
                                          gradient: _isDailyClaimed
                                              ? null
                                              : AppColors.primaryGradient,
                                          color: _isDailyClaimed
                                              ? Colors.white.withOpacity(0.5)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: _isDailyClaimed
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withOpacity(0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  )
                                                ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (_isDailyClaimed)
                                              const Icon(Icons.timer_outlined,
                                                  size: 16,
                                                  color: AppColors.primary),
                                            if (_isDailyClaimed)
                                              const SizedBox(width: 6),
                                            Text(
                                              _isDailyClaimed
                                                  ? 'Ends ${_formatDuration(_timeUntilNextClaim)}'
                                                  : 'Claim Now',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: _isDailyClaimed
                                                    ? AppColors.primary
                                                    : Colors.white,
                                                letterSpacing: 0.3,
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
                            Expanded(
                              flex: 5,
                              child: Container(
                                height: 160,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 12),
                                child: Opacity(
                                  opacity: _isDailyClaimed ? 0.7 : 1.0,
                                  child: Image.network(
                                    AppAssets.purpleGiftBox,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.card_giftcard,
                                      size: 100,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Quick Actions header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: const _SectionHeader(
                        title: 'Quick Actions',
                      ),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // Quick Actions grid
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        children: [
                          _QuickActionCard(
                            iconUrl: AppAssets.chestIcon,
                            title: 'Chest',
                            badge: 'Ready',
                            onTap: () async {
                              final earned =
                                  await Navigator.of(context).push<int>(
                                MaterialPageRoute(
                                    builder: (_) => const ChestScreen()),
                              );
                              if (earned != null && earned > 0) {
                                await _loadBalance();
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            iconUrl: AppAssets.spinWheelIcon,
                            title: 'Spin & Win',
                            badge: 'Ready',
                            onTap: widget.onSpinTap,
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            iconUrl: AppAssets.quizMasterQuickActions,
                            title: 'Quizzes',
                            badge: 'Ready',
                            onTap: () async {
                              final earned =
                                  await Navigator.of(context).push<int>(
                                MaterialPageRoute(
                                    builder: (_) => const QuizzesScreen()),
                              );
                              if (earned != null && earned > 0) {
                                await _loadBalance();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Play to Earn header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(
                        title: 'Play to Earn',
                        linkText: 'View All',
                        onTap: () => widget.onNavTap(1),
                      ),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // Games row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.tapTapGame,
                              title: 'Tap Tap',
                              subtitle: 'Tap & earn',
                              coins: '+200 RBX',
                              bgColor: const Color(0xFFEAF3FF),
                              onTap: () async {
                                final earned =
                                    await Navigator.of(context).push<int>(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TapTapGameScreen(),
                                  ),
                                );
                                if (earned != null && earned > 0) {
                                  setState(() {
                                    _balance += earned;
                                  });
                                  GamePrefs.saveCoins(_balance);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.quizMasterGame,
                              title: 'Math Quiz',
                              subtitle: 'Answer & win',
                              coins: '+200 RBX',
                              bgColor: const Color(0xFFE3F8EB),
                              onTap: () => widget.onNavTap(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GameCard(
                              imageUrl: AppAssets.flappyJumpGame,
                              title: 'Flappy Jump',
                              subtitle: 'Fly & earn',
                              coins: '+200 RBX',
                              bgColor: const Color(0xFFFFF3E3),
                              onTap: () async {
                                final earned =
                                    await Navigator.of(context).push<int>(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FlappyJumpGameScreen(),
                                  ),
                                );
                                if (earned != null && earned > 0) {
                                  setState(() {
                                    _balance += earned;
                                  });
                                  GamePrefs.saveCoins(_balance);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Earn More header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(
                        title: 'Earn More',
                        linkText: 'View All',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EarnMoreScreen(onNavTap: widget.onNavTap),
                          ),
                        ).then((_) => _loadBalance()),
                      ),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // Earn More list
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _EarnMoreVerticalCard(
                                iconUrl: AppAssets.quizMasterEarnMore,
                                title: 'Quiz Master',
                                subtitle: 'Answer & earn',
                                badge: 'Up to 400',
                                onTap: () async {
                                  final earned = await Navigator.of(context).push<int>(
                                    MaterialPageRoute(builder: (_) => const QuizzesScreen()),
                                  );
                                  if (earned != null && earned > 0 && context.mounted) {
                                    _loadBalance();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _EarnMoreVerticalCard(
                                iconUrl: AppAssets.tapTapGame,
                                title: 'Scratch',
                                subtitle: 'Reveal rewards',
                                badge: 'Up to 350',
                                onTap: _showScratchDialog,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _EarnMoreVerticalCard(
                                iconUrl: 'https://cdn3d.iconscout.com/3d/premium/thumb/clipboard-survey-9937084-8134762.png',
                                title: 'Surveys',
                                subtitle: 'Answer polls',
                                badge: 'Up to 250',
                                onTap: _showSurveyDialog,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Mega Chest Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _MegaChestCard(
                        balance: _balance,
                        isClaimed: _isMegaChestClaimed,
                        onClaim: _claimMegaChest,
                      ),
                    ),
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
          child: RbxBottomNav(currentIndex: 0, onTap: widget.onNavTap),
        ),
      ),
    );
  }
}

class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InteractiveCard({required this.child, this.onTap});

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        if (widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? linkText;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.title,
    this.linkText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF131326),
          ),
        ),
        if (linkText != null && onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  linkText!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
      child: _InteractiveCard(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              iconUrl.startsWith('http')
                  ? Image.network(
                      iconUrl,
                      width: 56,
                      height: 56,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.star,
                        size: 46,
                        color: AppColors.primary,
                      ),
                    )
                  : Image.asset(
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
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF131326),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purple,
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

class _EarnMoreVerticalCard extends StatelessWidget {
  final String iconUrl;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _EarnMoreVerticalCard({
    required this.iconUrl,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _InteractiveCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image container at the top
              Container(
                height: 70,
                width: double.infinity,
                color: AppColors.primarySoft,
                child: iconUrl.startsWith('http')
                    ? Image.network(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.star,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      )
                    : Image.asset(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.star,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                child: Column(
                  children: [
                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131326),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Subtitle
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF868A9F),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(width: 4),
                          Image.asset(
                            AppAssets.goldCoin,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monetization_on,
                              size: 20,
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
      ),
    );
  }
}

class _MegaChestCard extends StatelessWidget {
  static const int coinGoal = 2000;
  final int balance;
  final bool isClaimed;
  final VoidCallback onClaim;

  const _MegaChestCard({
    required this.balance,
    required this.isClaimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (balance / coinGoal).clamp(0.0, 1.0);
    final canClaim = balance >= coinGoal && !isClaimed;

    return _InteractiveCard(
      onTap: canClaim ? onClaim : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131326),
                      ),
                      children: [
                        TextSpan(
                          text: isClaimed
                              ? 'Mega Chest claimed'
                              : canClaim
                                  ? 'Mega Chest unlocked! Tap to claim'
                                  : 'Earn more coins to unlock Mega Chest',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppColors.primarySoft,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.purple),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${balance.clamp(0, coinGoal)} / $coinGoal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF868A9F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Image.asset(
              AppAssets.megaChestIcon,
              width: 60,
              height: 60,
              errorBuilder: (_, __, ___) => const Icon(Icons.inventory,
                  size: 56, color: AppColors.purple),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String coins;
  final Color bgColor;
  final VoidCallback? onTap;

  const _GameCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _InteractiveCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                height: 70, // Matched with _EarnMoreVerticalCard image height
                width: double.infinity,
                color: bgColor,
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.sports_esports,
                          size: 44,
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                      )
                    : Image.asset(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.sports_esports,
                          size: 44,
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                      ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13, // Increased from 13
                        fontWeight: FontWeight.w800, // Bolder
                        color: Color(0xFF131326),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF868A9F),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            coins,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(width: 4),
                          Image.asset(
                            AppAssets.goldCoin,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monetization_on,
                              size: 20,
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
      ),
    );
  }
}
