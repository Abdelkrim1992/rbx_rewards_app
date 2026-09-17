import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../widgets/feature_top_bar.dart';
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
  bool _isLoadingLimit = true;

  @override
  void initState() {
    super.initState();
    _loadScratchLimit();
    _generateReward();
  }

  Future<void> _loadScratchLimit() async {
    final remaining = await GamePrefs.getScratchesRemaining();
    if (mounted) {
      setState(() {
        _scratchesRemaining = remaining;
        _isLoadingLimit = false;
      });
    }
  }

  Future<void> _watchAdForExtraScratch() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    await ref.read(adProvider.notifier).showOptionalAd(
      AdPlacement.scratchExtra,
      onReward: (amount) async {
        if (!mounted) return;
        await GamePrefs.incrementScratchesRemaining();
        final scratchesUpdated = await GamePrefs.getScratchesRemaining();
        if (mounted) {
          setState(() {
            _scratchesRemaining = scratchesUpdated;
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
                  await GamePrefs.incrementScratchesRemaining();
                  final scratchesUpdated = await GamePrefs.getScratchesRemaining();
                  if (mounted) {
                    setState(() {
                      _scratchesRemaining = scratchesUpdated;
                      _isProcessing = false;
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
    if (_isScratched || _isProcessing || _scratchesRemaining <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScratchSoundTime > 220) {
      _lastScratchSoundTime = now;
      SoundService.instance.playScratch();
    }
  }

  Future<void> _handleScratchWin() async {
    if (_isScratched || _isProcessing) return;

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
              // Unified Feature Top Bar
              FeatureTopBar(
                title: 'Scratch & Win',
                onBack: _handleBack,
                isBackEnabled: !_isProcessing,
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
                      // Scratches Left Indicator / Ad Refill Status Pill
                      if (!_isLoadingLimit) ...[
                        if (_scratchesRemaining <= 0) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 12 : 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.smart_display_rounded,
                                      size: 17,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '0 Scratches Left • Watch Video to Refill',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
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
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 12 : 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      size: 17,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Free Scratches: $_scratchesRemaining',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
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
                              _scratchesRemaining <= 0
                                  ? 'Watch video below to scratch!'
                                  : 'Scratch below to reveal!',
                              style: TextStyle(
                                fontSize: isCompact ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: isCompact ? 12 : 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  IgnorePointer(
                                    ignoring: _scratchesRemaining <= 0 || _isLoadingLimit,
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
                                  if (_scratchesRemaining <= 0 && !_isLoadingLimit)
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.black.withValues(alpha: 0.38),
                                        child: InkWell(
                                          onTap: _isProcessing ? null : _watchAdForExtraScratch,
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.primary.withValues(alpha: 0.35),
                                                        blurRadius: 14,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_circle_fill,
                                                    size: 32,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                const Text(
                                                  'WATCH VIDEO TO SCRATCH',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  'Tap to unlock card',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
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
                          ],
                        ),
                      ),

                      SizedBox(height: isCompact ? 16 : 24),

                      // Watch Ad button for extra scratch
                      InteractiveButton(
                        height: isCompact ? 48 : 52,
                        gradient: AppColors.primaryGradient,
                        textColor: Colors.white,
                        isLoading: _isProcessing && !_hasActiveScratch,
                        onTap: _isProcessing ? null : _watchAdForExtraScratch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: isCompact ? 18 : 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _scratchesRemaining <= 0
                                      ? 'Watch Video for Free Scratch'
                                      : 'Watch Video for Extra Scratch',
                                  style: TextStyle(
                                    fontSize: isCompact ? 13 : 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
