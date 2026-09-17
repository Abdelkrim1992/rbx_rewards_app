import 'dart:math';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/ad_reward_dialog.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../../widgets/interactive_button.dart';
import '../providers/spin_provider.dart';
import '../providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_prefs.dart';
import '../../widgets/feature_top_bar.dart';
import '../../core/utils/reward_helper.dart';
import '../../business/sound_service.dart';

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
  late AnimationController _flapperController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _flapperAnimation;

  bool _isSpinning = false;
  bool _isProcessing = false;
  int _extraSpinsRemaining = GamePrefs.maxExtraSpinsPerDay;

  List<_WheelSegment> get segments {
    final jackpotReward = ref.read(dailyCapServiceProvider).getPremiumReward('spin', fallback: 25);
    return [
      const _WheelSegment(label: '5', sublabel: 'RBX', color: Color(0xFF8B5CF6)),
      const _WheelSegment(label: '8', sublabel: 'RBX', color: Color(0xFF6D28D9)),
      const _WheelSegment(label: '10', sublabel: 'RBX', color: Color(0xFFA78BFA)),
      const _WheelSegment(label: '20', sublabel: 'RBX', color: Color(0xFF5B21B6)),
      _WheelSegment(
        label: 'JACKPOT',
        sublabel: '$jackpotReward RBX!',
        color: const Color(0xFFF59E0B), // Radiant Amber Gold
      ),
      const _WheelSegment(label: '15', sublabel: 'RBX', color: Color(0xFF7C3AED)),
    ];
  }

  Timer? _countdownTimer;
  int _lastPeg = 0;

  @override
  void initState() {
    super.initState();

    // Wheel spin rotation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    // Flapper needle bounce animation when crossing pegs
    _flapperController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _flapperAnimation = Tween<double>(begin: 0.0, end: -0.22).animate(
      CurvedAnimation(parent: _flapperController, curve: Curves.easeOut),
    );
    _flapperController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _flapperController.reverse();
      }
    });

    _controller.addListener(() {
      if (_isSpinning) {
        const segmentAngle = (2 * pi) / 6;
        final peg = (_animation.value / segmentAngle).floor();
        if (peg != _lastPeg) {
          _lastPeg = peg;
          SoundService.instance.playWheelTick();
          _flapperController.forward(from: 0.0);
        }
      }
    });

    // Idle pulse animation for central hub and primary CTA
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Don't auto-repeat in test environment so pumpAndSettle can settle cleanly
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animation = const AlwaysStoppedAnimation(0.0);

    // 1-second ticker for midnight / cooldown counter
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }

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
    _flapperController.dispose();
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
    final weights = [25, 25, 20, 10, 5, 15]; // 5, 8, 10, 20, JACKPOT, 15
    final total = weights.fold<int>(0, (sum, w) => sum + w);
    var roll = random.nextInt(total);
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return 0;
  }

  Future<void> _watchAdForExtraSpin() async {
    if (_isProcessing || _isSpinning) return;
    setState(() {
      _isProcessing = true;
    });

    await ref.read(adProvider.notifier).showOptionalAd(
      AdPlacement.spinExtra,
      onReward: (amount) async {
        if (!mounted) return;
        await ref.read(spinProvider.notifier).addFreeSpinLocal();
        await _loadExtraSpinsRemaining();
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
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
                  await ref.read(spinProvider.notifier).addFreeSpinLocal();
                  await _loadExtraSpinsRemaining();
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
  }

  Future<void> _spin() async {
    final freeSpins = ref.read(spinProvider).spinsRemaining;
    final isSpinBlocked = ref.read(dailyCapServiceProvider).isCapReachedFor('spin') ||
        ref.read(dailyCapServiceProvider).isFeaturesCapReached;
    if (_isSpinning || _isProcessing || freeSpins == 0 || isSpinBlocked) return;

    final random = Random();
    final targetSegment = _pickWeightedSegment(random);
    final baseRotations = 4 + random.nextInt(4);
    const segmentAngle = (2 * pi) / 6;
    final targetAngle = baseRotations * 2 * pi +
        targetSegment * segmentAngle +
        segmentAngle / 2;

    _lastPeg = (_animation.value / segmentAngle).floor();

    _animation = Tween<double>(
      begin: _animation.value % (2 * pi),
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    setState(() {
      _isSpinning = true;
      _isProcessing = true;
    });

    // Deduct spin usage immediately upon playing
    ref.read(spinProvider.notifier).spin();

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
        return ref.read(dailyCapServiceProvider).getPremiumReward('spin', fallback: 25);
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
      multiplier: 4,
      onSuccess: (coins) async {
        if (!mounted) return;
        await ref.read(coinProvider.notifier).credit(coins, 'spin');
      },
    );
  }

  void _showHowToPlay(BuildContext context) {
    final jackpotReward = ref.read(dailyCapServiceProvider).getPremiumReward('spin', fallback: 25);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'How to Play Spin & Win',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _HowToStep(
                    icon: Icons.casino_outlined,
                    title: 'Daily Free Spins',
                    description: 'Get 3 free spins every single day to win RBX Coins instantly.',
                    color: Color(0xFF9B5CFF),
                  ),
                  const SizedBox(height: 8),
                  _HowToStep(
                    icon: Icons.emoji_events_outlined,
                    title: 'Hit the Jackpot',
                    description: 'Land on the golden JACKPOT segment to win up to $jackpotReward RBX.',
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 8),
                  const _HowToStep(
                    icon: Icons.play_circle_outline,
                    title: 'Unlimited Refills',
                    description: 'Used all spins? Watch short video ads to refill extra spins anytime.',
                    color: Color(0xFF6B4BF4),
                  ),
                  const SizedBox(height: 16),
                  InteractiveButton(
                    height: 48,
                    gradient: AppColors.primaryGradient,
                    textColor: Colors.white,
                    onTap: () => Navigator.pop(context),
                    child: const Center(
                      child: Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spinState = ref.watch(spinProvider);
    final freeSpins = spinState.spinsRemaining;
    final cooldownRemaining = ref.watch(spinProvider.notifier).cooldownRemaining;
    final capService = ref.watch(dailyCapServiceProvider);
    final isSpinCapReached = capService.isCapReachedFor('spin');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isSpinBlocked = isSpinCapReached || isFeaturesCapReached;
    final effectiveCooldown = _getEffectiveCooldown(cooldownRemaining, isSpinBlocked);
    final jackpotReward = capService.getPremiumReward('spin', fallback: 25);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isSpinning || _isProcessing) return;
        widget.onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Unified Header with Coins Badge & (?) Help
              FeatureTopBar(
                title: 'Spin & Win',
                onBack: widget.onBack,
                onInfoTap: () => _showHowToPlay(context),
                isBackEnabled: !_isSpinning && !_isProcessing,
              ),

              // Responsive Fixed Body (No Scrolling)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableHeight = constraints.maxHeight;
                    final availableWidth = constraints.maxWidth;
                    final isCompact = availableHeight < 560 || availableWidth < 350;

                    final bottomPadding = isCompact ? 14.0 : 20.0;
                    final topPadding = isCompact ? 4.0 : 8.0;

                    // Wheel size dynamically calculated to fit with guaranteed zero overflow
                    final maxWheelByHeight = (availableHeight - (isCompact ? 180 : 220) - bottomPadding).clamp(170.0, 360.0);
                    final maxWheelByWidth = (availableWidth * (isCompact ? 0.78 : 0.82)).clamp(170.0, 360.0);
                    final wheelSize = min(maxWheelByHeight, maxWheelByWidth);
                    final centerHubSize = (wheelSize * 0.29).clamp(64.0, 84.0);

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 12 : AppLayout.screenPadding,
                        topPadding,
                        isCompact ? 12 : AppLayout.screenPadding,
                        bottomPadding,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1. Daily Spin Tokens / Refill Status Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x04000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primarySoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.casino_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Daily Spins',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        freeSpins > 0
                                            ? '$freeSpins of 3 Available'
                                            : '0 Free Spins Left',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 3 Token Chips
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(3, (index) {
                                    final isAvailable = index < freeSpins;
                                    return Container(
                                      margin: const EdgeInsets.only(left: 5),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: isAvailable
                                            ? const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                              )
                                            : null,
                                        color: isAvailable ? null : const Color(0xFFE2E8F0),
                                        boxShadow: isAvailable
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Icon(
                                        isAvailable ? Icons.star_rounded : Icons.lock_outline_rounded,
                                        size: 13,
                                        color: isAvailable ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),

                          // 2. The Hero Wheel Container (Centered & Proportionate)
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: wheelSize + 24,
                                height: wheelSize + 36,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Ambient Drop Shadow
                                    Positioned(
                                      top: 24,
                                      child: Container(
                                        width: wheelSize * 0.94,
                                        height: wheelSize * 0.94,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.10),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Outer Bezel Layer (Casino Gold / Purple)
                                    Positioned(
                                      top: 20,
                                      child: Container(
                                        width: wheelSize + 8,
                                        height: wheelSize + 8,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFF4A2BC2),
                                              Color(0xFF24125E),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Rotating Wheel Body
                                    Positioned(
                                      top: 24,
                                      child: AnimatedBuilder(
                                        animation: _controller,
                                        builder: (context, child) {
                                          final value = _isSpinning || _controller.value > 0
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
                                                  painter: _WheelPainter(segments),
                                                ),
                                              ),
                                              // Coin icons positioned on segments
                                              ...List.generate(segments.length, (i) {
                                                final segmentAngle = (2 * pi) / segments.length;
                                                final startAngle = i * segmentAngle - pi / 2;
                                                final textAngle = startAngle + segmentAngle / 2;

                                                final center = wheelSize / 2;
                                                final imgRadius = center * 0.40;
                                                final imgX = center + imgRadius * cos(textAngle);
                                                final imgY = center + imgRadius * sin(textAngle);
                                                final coinSize = (wheelSize * 0.082).clamp(18.0, 26.0);

                                                return Positioned(
                                                  left: imgX - (coinSize / 2),
                                                  top: imgY - (coinSize / 2),
                                                  child: Transform.rotate(
                                                    angle: textAngle + pi / 2,
                                                    child: Image.asset(
                                                      AppAssets.goldRbxCoin,
                                                      width: coinSize,
                                                      height: coinSize,
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Tactile Center SPIN Button (Fixed in place)
                                    Positioned(
                                      top: 24 + (wheelSize - centerHubSize) / 2,
                                      child: GestureDetector(
                                        onTap: (_isProcessing || _isSpinning)
                                            ? null
                                            : (freeSpins == 0 ? _watchAdForExtraSpin : _spin),
                                        child: AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, child) {
                                            return Transform.scale(
                                              scale: (_isSpinning || _isProcessing)
                                                  ? 1.0
                                                  : _pulseAnimation.value,
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            width: centerHubSize,
                                            height: centerHubSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const RadialGradient(
                                                colors: [
                                                  Colors.white,
                                                  Color(0xFFF3E8FF),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: const Color(0xFFFFD700),
                                                width: 3.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.35),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (_isSpinning || _isProcessing) ...[
                                                    const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ] else if (freeSpins == 0) ...[
                                                    const Icon(
                                                      Icons.play_circle_fill,
                                                      size: 22,
                                                      color: AppColors.primary,
                                                    ),
                                                    const SizedBox(height: 1),
                                                    const Text(
                                                      'REFILL',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.primary,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    const Text(
                                                      'SPIN',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppColors.primary,
                                                        letterSpacing: 1,
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons.touch_app_rounded,
                                                      size: 13,
                                                      color: AppColors.primaryText,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Top Mechanical Flapper / Pointer
                                    Positioned(
                                      top: 2,
                                      child: AnimatedBuilder(
                                        animation: _flapperAnimation,
                                        builder: (context, child) {
                                          return Transform.rotate(
                                            angle: _flapperAnimation.value,
                                            alignment: Alignment.topCenter,
                                            child: child,
                                          );
                                        },
                                        child: CustomPaint(
                                          size: const Size(28, 40),
                                          painter: _PointerPainter(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 3. Jackpot Teaser Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 15,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Top Prize: $jackpotReward RBX Jackpot • 4X Bonus!',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF92400E),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // 4. Single Unified Action CTA
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InteractiveButton(
                                height: 52,
                                gradient: isSpinBlocked
                                    ? const LinearGradient(
                                        colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                                      )
                                    : (freeSpins == 0
                                        ? const LinearGradient(
                                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                                          )
                                        : AppColors.primaryGradient),
                                textColor: Colors.white,
                                isLoading: _isProcessing && !_isSpinning,
                                onTap: (_isProcessing || _isSpinning)
                                    ? null
                                    : (isSpinBlocked
                                        ? null
                                        : (freeSpins == 0 ? _watchAdForExtraSpin : _spin)),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isSpinBlocked
                                              ? Icons.timer_outlined
                                              : (freeSpins == 0
                                                  ? Icons.play_circle_fill
                                                  : Icons.casino_rounded),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isSpinBlocked
                                              ? 'Daily Limit Reached (${_formatDuration(effectiveCooldown)})'
                                              : (freeSpins == 0
                                                  ? 'Watch Video for +1 Free Spin'
                                                  : 'SPIN WHEEL  ($freeSpins LEFT)'),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Subtitle quota / hint
                              Text(
                                freeSpins == 0
                                    ? '$_extraSpinsRemaining / ${GamePrefs.maxExtraSpinsPerDay} video refills remaining today'
                                    : 'Tap button or center of wheel to spin',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
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

    // Outer shadow ring
    final shadowPaint = Paint()
      ..color = const Color(0x22664DFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, shadowPaint);

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * segmentAngle - pi / 2;

      // Radial gradient for each segment
      final segmentGradient = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          segments[i].color,
          segments[i].color.withValues(alpha: 0.85),
        ],
      );

      final paint = Paint()
        ..shader = segmentGradient.createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Clean divider border between segments
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Label (Reward text)
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.73;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);

      final isJackpot = segments[i].label == 'JACKPOT';
      final textPainter = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: TextStyle(
            color: isJackpot ? const Color(0xFF78350F) : Colors.white,
            fontSize: isJackpot ? 12 : 14,
            fontWeight: FontWeight.w900,
            letterSpacing: isJackpot ? 0.8 : 0.5,
            shadows: isJackpot
                ? null
                : [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.35),
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

    // Outer Casino Gold Rim
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 5, rimPaint);

    // Decorative studs / bulbs around the rim
    final dotPaint = Paint()..color = Colors.white;
    const dotCount = 12;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * pi) / dotCount;
      final dotX = center.dx + (radius - 5) * cos(angle);
      final dotY = center.dy + (radius - 5) * sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);

      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Drop shadow
    final shadowPath = Path()
      ..moveTo(w / 2, h)
      ..lineTo(2, h * 0.3)
      ..quadraticBezierTo(0, 0, w / 2, 0)
      ..quadraticBezierTo(w, 0, w - 2, h * 0.3)
      ..close();

    canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.35), 6, true);

    // Metallic golden flapper
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF3B0),
          Color(0xFFFFB300),
          Color(0xFFE65100),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(shadowPath, bodyPaint);

    // Subtle edge highlight
    final strokePaint = Paint()
      ..color = const Color(0xFFFFFDE7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(shadowPath, strokePaint);

    // Center circular jewel / pivot pin
    final rivetPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0xFFFFA000)],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.30), radius: 5));
    canvas.drawCircle(Offset(w / 2, h * 0.30), 5, rivetPaint);

    final rivetRim = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(w / 2, h * 0.30), 5, rivetRim);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
