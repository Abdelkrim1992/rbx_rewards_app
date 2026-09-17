import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scratcher/scratcher.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_button.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../widgets/ad_reward_dialog.dart';
import '../../core/utils/reward_helper.dart';
import '../../widgets/game_prefs.dart';
import '../../business/sound_service.dart';

class ScratchCardScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ScratchCardScreen({super.key, required this.onBack});

  @override
  ConsumerState<ScratchCardScreen> createState() => _ScratchCardScreenState();
}

class _ScratchCardScreenState extends ConsumerState<ScratchCardScreen> {
  final GlobalKey<ScratcherState> _scratcherKey = GlobalKey<ScratcherState>();
  bool _isScratched = false;
  bool _hasStartedScratching = false;
  bool _isProcessing = false;
  late int _rewardAmount;
  
  int _scratchesRemaining = GamePrefs.maxScratchesPerDay;
  int _extraScratchesRemaining = GamePrefs.maxExtraScratchesPerDay;
  bool _isLoadingLimit = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadScratchLimit();
    _generateReward();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadScratchLimit() async {
    final remaining = await GamePrefs.getScratchesRemaining();
    final extraRemaining = await GamePrefs.getExtraScratchesRemaining();
    if (mounted) {
      setState(() {
        _scratchesRemaining = remaining;
        _extraScratchesRemaining = extraRemaining;
        _isLoadingLimit = false;
      });
    }
  }

  Duration _getEffectiveCooldown(bool isScratchBlocked) {
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

  void _generateReward() {
    final capService = ref.read(dailyCapServiceProvider);
    final limits = capService.getRewardLimits('scratch');
    final min = limits.$1;
    final max = limits.$2;
    final random = Random();
    
    if (max > min) {
      _rewardAmount = min + random.nextInt((max - min) + 1);
    } else {
      _rewardAmount = min;
    }
  }

  void _resetScratchCard() {
    setState(() {
      _isScratched = false;
      _hasStartedScratching = false;
      _generateReward();
    });
    _scratcherKey.currentState?.reset(duration: const Duration(milliseconds: 300));
  }

  int _lastScratchSoundTime = 0;

  void _onScratchMove() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScratchSoundTime > 220) {
      _lastScratchSoundTime = now;
      SoundService.instance.playScratch();
    }
  }

  Future<void> _handleScratchWin() async {
    if (_isScratched || _isProcessing) return;
    
    SoundService.instance.playJackpot();

    setState(() {
      _isScratched = true;
      _hasStartedScratching = false;
      _isProcessing = true;
    });

    // Brief delay to let user see the reward fully before dialog pops up
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await showRewardChoice(
      context: context,
      featureName: 'Scratch Card Reward',
      baseReward: _rewardAmount,
      quickPlacement: AdPlacement.scratchCard,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.goldRbxCoin,
      multiplier: 4,
      onSuccess: (coins) async {
        await ref.read(coinProvider.notifier).credit(coins, 'scratch');
        await GamePrefs.decrementScratchesRemaining();
        if (mounted) {
          _resetScratchCard();
          await _loadScratchLimit();
          setState(() {
            _isProcessing = false;
          });
        }
      },
      onCancel: () async {
        await GamePrefs.decrementScratchesRemaining();
        if (mounted) {
          _resetScratchCard();
          await _loadScratchLimit();
          setState(() {
            _isProcessing = false;
          });
        }
      },
    );
  }

  bool get _hasActiveScratch => !_isScratched && _hasStartedScratching;

  Future<void> _handleBack() async {
    if (_isProcessing) return;
    if (_hasActiveScratch) {
      final shouldLeave = await showQuitConfirmationDialog(
        context,
        title: 'Quit Scratching?',
        message: 'You have an active scratch card. Are you sure you want to leave?',
      );
      if (shouldLeave && mounted) {
        widget.onBack();
      }
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final capService = ref.watch(dailyCapServiceProvider);
    final isScratchCapReached = capService.isCapReachedFor('scratch');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isScratchBlocked = isScratchCapReached || isFeaturesCapReached;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isCompact = screenWidth < 360;
    final isShort = screenHeight < 680;
    final horizontalPadding = isCompact ? 12.0 : 16.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Nav bar
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  0,
                ),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: _handleBack,
                          child: Container(
                            width: isCompact ? 38 : 44,
                            height: isCompact ? 38 : 44,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.purple,
                              size: isCompact ? 16 : 18,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 48 : 64,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Scratch & Win',
                            style: TextStyle(
                              fontSize: isCompact ? 18 : 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF131326),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Consumer(
                          builder: (context, ref, child) {
                            final coinBalance = ref.watch(coinProvider);
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 8 : 10,
                                vertical: isCompact ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    AppAssets.goldRbxCoin,
                                    width: isCompact ? 16 : 18,
                                    height: isCompact ? 16 : 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    coinBalance.toString(),
                                    style: TextStyle(
                                      fontSize: isCompact ? 13 : 14,
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
              SizedBox(height: isCompact ? 12 : 20),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                    children: [
                      // Scratches Left Indicator / Countdown Banner
                      if (!_isLoadingLimit) ...[
                        if (isScratchBlocked || (_scratchesRemaining <= 0 && _extraScratchesRemaining <= 0)) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 12 : 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFFD4E5)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
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
                                      isScratchBlocked
                                          ? 'Daily Scratch Cap Reached • Resets in ${_formatDuration(_getEffectiveCooldown(isScratchBlocked))}'
                                          : 'Limit Reached • Resets in ${_formatDuration(_getEffectiveCooldown(isScratchBlocked))}',
                                      style: GoogleFonts.outfit(
                                        fontSize: isCompact ? 13 : 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFFF52A2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else if (_scratchesRemaining <= 0) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 12 : 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFFD4E5)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline,
                                      size: 18,
                                      color: Color(0xFFFF52A2),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '0 Scratches Left • Watch ad below for extra scratch',
                                      style: GoogleFonts.outfit(
                                        fontSize: isCompact ? 12 : 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFFF52A2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Free Scratches: $_scratchesRemaining',
                                style: TextStyle(
                                  fontSize: isCompact ? 14 : 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF131326),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],

                      // Scratch Card Container
                      Container(
                        padding: EdgeInsets.all(isCompact ? 12 : 16),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Scratch below to reveal!',
                              style: TextStyle(
                                fontSize: isCompact ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: isCompact ? 12 : 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: IgnorePointer(
                                ignoring: _scratchesRemaining <= 0 || _isLoadingLimit || isScratchBlocked,
                                child: Listener(
                                  onPointerMove: (_) => _onScratchMove(),
                                  child: Scratcher(
                                    key: _scratcherKey,
                                    brushSize: isCompact ? 34 : 40,
                                    threshold: 50,
                                    color: AppColors.primaryLight,
                                    image: Image.asset(
                                      AppAssets.dailyRewardImage,
                                      fit: BoxFit.cover,
                                    ),
                                    onChange: (value) {
                                      _onScratchMove();
                                      if (value > 0 && !_hasStartedScratching) {
                                        setState(() {
                                          _hasStartedScratching = true;
                                        });
                                      }
                                    },
                                    onThreshold: () {
                                      _handleScratchWin();
                                    },
                                    child: Container(
                                    height: isCompact ? 210 : (isShort ? 230 : 250),
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          AppAssets.goldRbxCoin,
                                          width: isCompact ? 64 : 80,
                                          height: isCompact ? 64 : 80,
                                        ),
                                        SizedBox(height: isCompact ? 8 : 12),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$_rewardAmount RBX',
                                            style: TextStyle(
                                              fontSize: isCompact ? 26 : 32,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primaryText,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'You Won!',
                                          style: TextStyle(
                                            fontSize: isCompact ? 14 : 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                      SizedBox(height: isCompact ? 16 : 24),

                      // Watch Ad button for extra scratch
                      InteractiveButton(
                        height: isCompact ? 48 : 52,
                        gradient: (_extraScratchesRemaining <= 0 || isScratchBlocked)
                            ? null
                            : AppColors.primaryGradient,
                        backgroundColor: (_extraScratchesRemaining <= 0 || isScratchBlocked)
                            ? const Color(0xFFF1F2F8)
                            : null,
                        textColor: (_extraScratchesRemaining <= 0 || isScratchBlocked)
                            ? const Color(0xFF868A9F)
                            : Colors.white,
                        onTap: (_isProcessing || _extraScratchesRemaining <= 0 || isScratchBlocked)
                            ? null
                            : () async {
                                setState(() {
                                  _isProcessing = true;
                                });
                                // Show rewarded ad
                                await ref.read(adProvider.notifier).showOptionalAd(
                                  AdPlacement.scratchExtra,
                                  onReward: (amount) async {
                                    if (!mounted) return;
                                    await GamePrefs.decrementExtraScratchesRemaining();
                                    final updated = await GamePrefs.getExtraScratchesRemaining();
                                    await GamePrefs.incrementScratchesRemaining();
                                    final scratchesUpdated = await GamePrefs.getScratchesRemaining();
                                    if (mounted) {
                                      setState(() {
                                        _extraScratchesRemaining = updated;
                                        _scratchesRemaining = scratchesUpdated;
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
                                              await GamePrefs.decrementExtraScratchesRemaining();
                                              final updated = await GamePrefs.getExtraScratchesRemaining();
                                              await GamePrefs.incrementScratchesRemaining();
                                              final scratchesUpdated = await GamePrefs.getScratchesRemaining();
                                              if (mounted) {
                                                setState(() {
                                                  _extraScratchesRemaining = updated;
                                                  _scratchesRemaining = scratchesUpdated;
                                                });
                                              }
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _extraScratchesRemaining <= 0
                                      ? Icons.check_circle_outline
                                      : (isScratchBlocked ? Icons.lock : Icons.play_circle_fill),
                                  color: (_extraScratchesRemaining <= 0 || isScratchBlocked)
                                      ? const Color(0xFF868A9F)
                                      : Colors.white,
                                  size: isCompact ? 18 : 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _extraScratchesRemaining <= 0
                                      ? 'Extra Scratches Limit Reached (0/${GamePrefs.maxExtraScratchesPerDay})'
                                      : isScratchBlocked
                                          ? 'Daily Scratch Cap Reached'
                                          : 'Watch Ad for Extra Scratch ($_extraScratchesRemaining/${GamePrefs.maxExtraScratchesPerDay} left)',
                                  style: TextStyle(
                                    fontSize: isCompact ? 13 : 14,
                                    fontWeight: FontWeight.w700,
                                    color: (_extraScratchesRemaining <= 0 || isScratchBlocked)
                                        ? const Color(0xFF868A9F)
                                        : Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 16 : 24),

                      // How to Play Section
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'How to Play',
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF131326),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _HowToStep(
                        icon: Icons.touch_app,
                        title: 'Scratch the Card',
                        description: 'Use your finger to scratch away the cover and reveal what\'s underneath.',
                        color: const Color(0xFF9B5CFF),
                        isCompact: isCompact,
                      ),
                      const SizedBox(height: 8),
                      _HowToStep(
                        icon: Icons.monetization_on,
                        title: 'Reveal the Prize',
                        description: 'Match the hidden symbols to win up to ${ref.watch(dailyCapServiceProvider).getRewardLimits('scratch').$2} RBX instantly.',
                        color: const Color(0xFF6B4BF4),
                        isCompact: isCompact,
                      ),
                      const SizedBox(height: 8),
                      _HowToStep(
                        icon: Icons.play_circle_outline,
                        title: 'Get More Cards',
                        description: 'Watch a short video to get another scratch card.',
                        color: const Color(0xFF4A2BC2),
                        isCompact: isCompact,
                      ),
                      const SizedBox(height: 20),
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
    );
  }
}

class _HowToStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isCompact;

  const _HowToStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = isCompact ? 40.0 : 48.0;
    final iconSize = isCompact ? 20.0 : 24.0;
    final spacing = isCompact ? 12.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
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
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF131326),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isCompact ? 11.5 : 12,
                    color: const Color(0xFF868A9F),
                    height: 1.35,
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
