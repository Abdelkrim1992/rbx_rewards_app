import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/ad_reward_dialog.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../../widgets/interactive_button.dart';
import '../providers/spin_provider.dart';
import '../providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/game_prefs.dart';
import '../../core/utils/reward_helper.dart';

class SpinScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SpinScreen({super.key, required this.onBack});

  @override
  ConsumerState<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends ConsumerState<SpinScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  bool _isSpinning = false;
  bool _isProcessing = false;
  int _extraSpinsRemaining = GamePrefs.maxExtraSpinsPerDay;

  final List<_WheelSegment> segments = const [
    _WheelSegment(label: '5', sublabel: 'RBX', color: Color(0xFF9B5CFF)),
    _WheelSegment(label: '8', sublabel: 'RBX', color: Color(0xFF7B3FE4)),
    _WheelSegment(label: '10', sublabel: 'RBX', color: Color(0xFFB370FF)),
    _WheelSegment(label: '20', sublabel: 'RBX', color: Color(0xFF6A2FD8)),
    _WheelSegment(
        label: 'JACKPOT',
        sublabel: '25 RBX!',
        color: Color.fromARGB(255, 160, 122, 16)),
    _WheelSegment(label: '15', sublabel: 'RBX', color: Color(0xFF8847F5)),
  ];

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animation = const AlwaysStoppedAnimation(0.0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _loadExtraSpinsRemaining();
  }

  Future<void> _loadExtraSpinsRemaining() async {
    final remaining = await GamePrefs.getExtraSpinsRemaining();
    if (mounted) {
      setState(() {
        _extraSpinsRemaining = remaining;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Duration _getEffectiveCooldown(Duration cooldownRemaining, bool isSpinBlocked) {
    if (cooldownRemaining > Duration.zero) {
      return cooldownRemaining;
    }
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = nextMidnight.difference(now);
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _pickWeightedSegment(Random random) {
    final weights = [25, 25, 20, 10, 5, 15]; // 100, 300, 500, 2K, JACKPOT, 1K
    final total = weights.fold<int>(0, (sum, w) => sum + w);
    var roll = random.nextInt(total);
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return 0;
  }

  Future<void> _spin() async {
    final freeSpins = ref.read(spinProvider).spinsRemaining;
    final isSpinBlocked = ref.read(dailyCapServiceProvider).isCapReachedFor('spin') || ref.read(dailyCapServiceProvider).isFeaturesCapReached;
    if (_isSpinning || _isProcessing || freeSpins == 0 || isSpinBlocked) return;
    final random = Random();
    final targetSegment = _pickWeightedSegment(random);
    final baseRotations = 2 + random.nextInt(6);
    const segmentAngle = (2 * pi) / 6;
    final targetAngle = baseRotations * 2 * pi +
        targetSegment * segmentAngle +
        segmentAngle / 2;

    _animation = Tween<double>(
      begin: _animation.value,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    setState(() {
      _isSpinning = true;
      _isProcessing = true;
    });

    _pulseController.stop();

    _controller.reset();
    _controller.forward().then((_) async {
      final prizeIndex =
          (segments.length - 1 - targetSegment) % segments.length;
      final prize = segments[prizeIndex].label;
      final reward = _prizeToCoins(prize);

      if (!mounted) return;

      setState(() {
        _isSpinning = false;
      });
      _pulseController.repeat(reverse: true);
      await _showWinDialog(prize, reward);
    });
  }

  int _prizeToCoins(String prize) {
    switch (prize) {
      case 'JACKPOT':
        return 25;
      default:
        return int.tryParse(prize) ?? 5;
    }
  }

  Future<void> _showWinDialog(String prize, int reward) async {
    try {
      await _handleWin(reward);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleWin(int reward) async {
    if (!mounted) return;
    await showRewardChoice(
      context: context,
      featureName: 'Spin Reward',
      baseReward: reward,
      quickPlacement: AdPlacement.spinExtra,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.spinWheelIcon,
      onSuccess: (coins) async {
        if (!mounted) return;
        final result = await ref.read(spinProvider.notifier).spin();
        if (result != null) {
          await ref.read(coinProvider.notifier).credit(coins, 'spin');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spinState = ref.watch(spinProvider);
    final freeSpins = spinState.spinsRemaining;
    final cooldownRemaining =
        ref.watch(spinProvider.notifier).cooldownRemaining;
    final capService = ref.watch(dailyCapServiceProvider);
    final isSpinCapReached = capService.isCapReachedFor('spin');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isSpinBlocked = isSpinCapReached || isFeaturesCapReached;
    final effectiveCooldown = _getEffectiveCooldown(cooldownRemaining, isSpinBlocked);

    final screenWidth = MediaQuery.of(context).size.width;
    final wheelSize = screenWidth * 0.78;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isSpinning || _isProcessing) {
          // Action is in progress — block navigation completely
          return;
        }
        widget.onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Nav bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: (_isSpinning || _isProcessing) ? null : widget.onBack,
                          child: Opacity(
                            opacity: (_isSpinning || _isProcessing) ? 0.4 : 1.0,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: AppColors.purple,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'Spin & Win',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF131326),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Consumer(
                          builder: (context, ref, child) {
                            final coinBalance = ref.watch(coinProvider);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    AppAssets.goldRbxCoin,
                                    width: 18,
                                    height: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    coinBalance.toString(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: RefreshableScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.screenPadding),
                  child: Column(
                    children: [
                      // 3D Wheel Container
                      SizedBox(
                        height: wheelSize + 60,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            // Perspective Shadow
                            Positioned(
                              top: 50,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateX(1.1),
                                alignment: Alignment.center,
                                child: Container(
                                  width: wheelSize * 0.9,
                                  height: wheelSize * 0.9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.2),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // The Main Wheel with 3D Tilt
                            Positioned(
                              top: 30,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateX(-0.35), // The 3D tilt
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Wheel Base/Depth Effect
                                    Container(
                                      width: wheelSize + 10,
                                      height: wheelSize + 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF4A2BC2),
                                            Color(0xFF2E1B7A),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Rotating Part
                                    AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        final value =
                                            _isSpinning || _controller.value > 0
                                                ? _animation.value
                                                : 0.0;
                                        return Transform.rotate(
                                          angle: value,
                                          child: child,
                                        );
                                      },
                                      child: SizedBox(
                                        width: wheelSize,
                                        height: wheelSize,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter:
                                                    _WheelPainter(segments),
                                              ),
                                            ),
                                            ...List.generate(segments.length,
                                                (i) {
                                              final segmentAngle =
                                                  (2 * pi) / segments.length;
                                              final startAngle =
                                                  i * segmentAngle - pi / 2;
                                              final textAngle =
                                                  startAngle + segmentAngle / 2;

                                              final center = wheelSize / 2;
                                              final imgRadius = center * 0.42;
                                              final imgX = center +
                                                  imgRadius * cos(textAngle);
                                              final imgY = center +
                                                  imgRadius * sin(textAngle);

                                              return Positioned(
                                                left: imgX - 15,
                                                top: imgY - 12,
                                                child: Transform.rotate(
                                                  angle: textAngle + pi / 2,
                                                  child: Image.asset(
                                                    AppAssets.goldRbxCoin,
                                                    width: 25,
                                                    height: 25,
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Center SPIN button (Fixed, not rotating)
                                    GestureDetector(
                                      onTap: (isSpinBlocked || _isProcessing || _isSpinning || freeSpins == 0) ? null : _spin,
                                      child: AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale:
                                                _isSpinning || _isProcessing || (freeSpins == 0) || isSpinBlocked
                                                    ? 1.0
                                                    : _pulseAnimation.value,
                                            child: child,
                                          );
                                        },
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            gradient: const RadialGradient(
                                              colors: [
                                                Colors.white,
                                                Color(0xFFF8F9FF)
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withOpacity(0.3),
                                                blurRadius: 2,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _isSpinning || _isProcessing
                                                    ? const Text(
                                                        '...',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color:
                                                              AppColors.primary,
                                                          letterSpacing: 1,
                                                        ),
                                                      )
                                                    : (isSpinBlocked || freeSpins == 0)
                                                        ? Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment.center,
                                                            children: [
                                                              Text(
                                                                _formatDuration(effectiveCooldown),
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight.w900,
                                                                  color: Colors.grey,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 2),
                                                              const Icon(
                                                                Icons.lock_clock,
                                                                size: 14,
                                                                color: Colors.grey,
                                                              ),
                                                            ],
                                                          )
                                                        : const Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment.center,
                                                            children: [
                                                              Text(
                                                                'SPIN',
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight.w900,
                                                                  color: AppColors
                                                                      .primary,
                                                                  letterSpacing: 1,
                                                                ),
                                                              ),
                                                              Icon(
                                                                Icons.touch_app,
                                                                size: 14,
                                                                color: AppColors
                                                                    .primaryText,
                                                              ),
                                                            ],
                                                          ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Top Indicator
                            Positioned(
                              top: 5,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: AppColors.primary, size: 44),
                                    Positioned(
                                      top: 8,
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      // Free spins info / 24h Limit Countdown Banner
                      if (isSpinBlocked || freeSpins == 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFD4E5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: Color(0xFFFF52A2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isSpinBlocked
                                    ? 'Daily Limit Reached • Resets in ${_formatDuration(effectiveCooldown)}'
                                    : 'Limit Reached • Resets in ${_formatDuration(effectiveCooldown)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFF52A2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Free Spins: $freeSpins',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF131326),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Watch Ad button with daily 8-spin cap
                      InteractiveButton(
                        height: 52,
                        gradient: (_extraSpinsRemaining <= 0 || isSpinBlocked)
                            ? null
                            : AppColors.primaryGradient,
                        backgroundColor: (_extraSpinsRemaining <= 0 || isSpinBlocked)
                            ? const Color(0xFFF1F2F8)
                            : null,
                        textColor: (_extraSpinsRemaining <= 0 || isSpinBlocked)
                            ? const Color(0xFF868A9F)
                            : Colors.white,
                        onTap: (_isProcessing || _isSpinning || _extraSpinsRemaining <= 0 || isSpinBlocked)
                            ? null
                            : () async {
                                setState(() {
                                  _isProcessing = true;
                                });
                                // Show rewarded ad
                                await ref.read(adProvider.notifier).showOptionalAd(
                                  AdPlacement.spinExtra,
                                  onReward: (amount) async {
                                    if (!mounted) return;
                                    await GamePrefs.decrementExtraSpinsRemaining();
                                    final updated = await GamePrefs.getExtraSpinsRemaining();
                                    if (mounted) {
                                      setState(() {
                                        _extraSpinsRemaining = updated;
                                      });
                                    }
                                    // Award the free spin after the ad is successfully watched
                                    await ref.read(spinProvider.notifier).addFreeSpinLocal();
                                  },
                                  onAdDismissed: () {
                                    if (mounted) {
                                      setState(() {
                                        _isProcessing = false;
                                      });
                                    }
                                  },
                                  onAdFailed: (error) async {
                                    if (mounted) {
                                      final isDevMode = ref.read(adServiceProvider).developerModeEnabled;
                                      if (isDevMode || kDebugMode) {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => AdRewardDialog(
                                            onRewardGranted: () async {
                                              await GamePrefs.decrementExtraSpinsRemaining();
                                              final updated = await GamePrefs.getExtraSpinsRemaining();
                                              if (mounted) {
                                                setState(() {
                                                  _extraSpinsRemaining = updated;
                                                });
                                              }
                                              await ref.read(spinProvider.notifier).addFreeSpinLocal();
                                            },
                                          ),
                                        ).then((_) {
                                          if (mounted) {
                                            setState(() {
                                              _isProcessing = false;
                                            });
                                          }
                                        });
                                      } else {
                                        setState(() {
                                          _isProcessing = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error)),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _extraSpinsRemaining <= 0
                                  ? Icons.check_circle_outline
                                  : (isSpinBlocked ? Icons.lock : Icons.play_circle_fill),
                              color: (_extraSpinsRemaining <= 0 || isSpinBlocked)
                                  ? const Color(0xFF868A9F)
                                  : Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _extraSpinsRemaining <= 0
                                  ? 'Extra Spins Limit Reached (0/${GamePrefs.maxExtraSpinsPerDay})'
                                  : isSpinBlocked
                                      ? 'Daily Spin Cap Reached'
                                      : 'Watch Ad for Extra Spin ($_extraSpinsRemaining/${GamePrefs.maxExtraSpinsPerDay} left)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: (_extraSpinsRemaining <= 0 || isSpinBlocked)
                                    ? const Color(0xFF868A9F)
                                    : Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // How to Play Section
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How to Spin & Win',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131326),
                            ),
                          ),
                          SizedBox(height: 10),
                          _HowToStep(
                            icon: Icons.auto_awesome,
                            title: 'Try Your Luck',
                            description: 'Spin daily to win up to 5,000 RBX.',
                            color: Color(0xFF9B5CFF),
                          ),
                          SizedBox(height: 8),
                          _HowToStep(
                            icon: Icons.play_circle_outline,
                            title: 'Get More Spins',
                            description:
                                'Watch a short video to get another chance.',
                            color: Color(0xFF6B4BF4),
                          ),
                          SizedBox(height: 8),
                          _HowToStep(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Collect & Redeem',
                            description: 'Exchange coins for real items.',
                            color: Color(0xFF4A2BC2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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

class _HowToStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _HowToStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131326),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF868A9F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelSegment {
  final String label;
  final String sublabel;
  final Color color;

  const _WheelSegment({
    required this.label,
    required this.sublabel,
    required this.color,
  });
}

class _WheelPainter extends CustomPainter {
  final List<_WheelSegment> segments;

  _WheelPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = (2 * pi) / segments.length;

    // Outer ring shadow
    final shadowPaint = Paint()
      ..color = const Color(0x22664DFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, shadowPaint);

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * segmentAngle - pi / 2;

      // Gradient for segment
      final segmentGradient = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          segments[i].color,
          segments[i].color.withOpacity(0.8),
        ],
      );

      final paint = Paint()
        ..shader = segmentGradient
            .createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Segment border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Label
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius =
          radius * 0.72; // Moved slightly outward to give space for the coin
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: TextStyle(
            color: segments[i].color == const Color(0xFFFFCC44)
                ? const Color.fromARGB(255, 50, 33, 0)
                : Colors.white,
            fontSize: segments[i].label.length > 3 ? 13 : 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Outer Gold rim
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 5, rimPaint);

    // Decorative dots around the rim
    final dotPaint = Paint()..color = Colors.white;
    const dotCount = 12;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * pi) / dotCount;
      final dotX = center.dx + (radius - 5) * cos(angle);
      final dotY = center.dy + (radius - 5) * sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);

      // Add a glow to dots
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
