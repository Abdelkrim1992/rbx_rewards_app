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
  double _scratchProgress = 0.0;
  int _ticketNumber = 7824;
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
    
    _ticketNumber = 1000 + random.nextInt(9000);
    _scratchProgress = 0.0;

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
      _scratchProgress = 0.0;
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

  void _showHowToPlay(BuildContext context) {
    final maxPrize = ref.read(dailyCapServiceProvider).getRewardLimits('scratch').$2;
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
                          'How to Play Scratch & Win',
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
                    icon: Icons.touch_app,
                    title: 'Scratch the Card',
                    description: 'Use your finger to scratch away the cover and reveal the prize.',
                    color: Color(0xFF9B5CFF),
                  ),
                  const SizedBox(height: 8),
                  _HowToStep(
                    icon: Icons.monetization_on,
                    title: 'Reveal the Prize',
                    description: 'Match symbols to win up to $maxPrize RBX instantly.',
                    color: const Color(0xFF6B4BF4),
                  ),
                  const SizedBox(height: 8),
                  const _HowToStep(
                    icon: Icons.play_circle_outline,
                    title: 'Unlimited Cards',
                    description: 'Watch a short video to refill your scratch cards whenever you want.',
                    color: Color(0xFF4A2BC2),
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
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenWidth < 360;
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
              // Unified Feature Top Bar with Info (?) modal button
              FeatureTopBar(
                title: 'Scratch & Win',
                onBack: _handleBack,
                isBackEnabled: !_isProcessing,
                onInfoTap: () => _showHowToPlay(context),
              ),

              // Responsive Fixed Viewport
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableHeight = constraints.maxHeight;
                    final availableWidth = constraints.maxWidth;
                    final isShortScreen = availableHeight < 560;
                    final bottomPadding = isShortScreen ? 14.0 : 20.0;
                    final topPadding = isShortScreen ? 4.0 : 8.0;

                    // Dynamic card height guaranteeing 0 vertical overflow
                    final cardMaxHeight = (availableHeight - (isShortScreen ? 185 : 215) - bottomPadding).clamp(195.0, 350.0);
                    final cardMaxWidth = (availableWidth * (isCompact ? 0.94 : 0.90)).clamp(280.0, 430.0);

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        topPadding,
                        horizontalPadding,
                        bottomPadding,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1. Daily Scratch Goal / Token Chips Banner
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
                                    color: Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Daily Scratch Goal',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        _scratchesRemaining > 0
                                            ? '$_scratchesRemaining of ${GamePrefs.maxScratchesPerDay} Cards Left'
                                            : 'Daily Goal Completed!',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 3 Thematic Ticket Token Chips
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(GamePrefs.maxScratchesPerDay, (i) {
                                    final isAvailable = (GamePrefs.maxScratchesPerDay - _scratchesRemaining) <= i &&
                                        _scratchesRemaining > 0;
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
                                        isAvailable
                                            ? Icons.confirmation_number_rounded
                                            : Icons.check_rounded,
                                        size: 13,
                                        color: isAvailable ? Colors.white : const Color(0xFF94A3B8),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),

                          // 2. Refill / Free Scratches Status Pill
                          if (!_isLoadingLimit) ...[
                            if (_scratchesRemaining <= 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '0 Scratches Left • Watch Video to Refill',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Free Scratches: $_scratchesRemaining',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],

                          // 3. The Hero Lottery Ticket Scratch Card
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: cardMaxWidth,
                                maxHeight: cardMaxHeight,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFF5B21B6),
                                    Color(0xFF4C1D95),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(isCompact ? 10 : 12),
                                      child: Column(
                                        children: [
                                          // Ticket Top Header Row
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.confirmation_number_rounded,
                                                color: Color(0xFFFFD700),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              const Expanded(
                                                child: Text(
                                                  'GOLDEN SCRATCH',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.6,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                  ),
                                                ),
                                                child: Text(
                                                  '#TKT-$_ticketNumber',
                                                  style: const TextStyle(
                                                    color: Color(0xFFFFE082),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 6),

                                          // Perforated Divider Line
                                          Row(
                                            children: List.generate(32, (index) => Expanded(
                                              child: Container(
                                                color: index.isEven ? Colors.white.withValues(alpha: 0.35) : Colors.transparent,
                                                height: 1.2,
                                              ),
                                            )),
                                          ),

                                          const SizedBox(height: 6),

                                          // Guide Text
                                          Text(
                                            _scratchesRemaining <= 0
                                                ? 'Watch video below to scratch!'
                                                : 'Scratch below to reveal!',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          // The Scratch Window Frame
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(14),
                                              child: Stack(
                                                children: [
                                                  IgnorePointer(
                                                    ignoring: _scratchesRemaining <= 0 || _isLoadingLimit,
                                                    child: Listener(
                                                      onPointerMove: (_) => _onScratchMove(),
                                                      child: Scratcher(
                                                        key: _scratcherKey,
                                                        brushSize: isCompact ? 36 : 42,
                                                        threshold: 50,
                                                        color: const Color(0xFF6D28D9),
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
                                                          if (mounted) {
                                                            setState(() {
                                                              _scratchProgress = value;
                                                            });
                                                          }
                                                        },
                                                        onThreshold: () {
                                                          _handleScratchWin();
                                                        },
                                                        child: Container(
                                                          width: double.infinity,
                                                          height: double.infinity,
                                                          decoration: const BoxDecoration(
                                                            gradient: RadialGradient(
                                                              center: Alignment.center,
                                                              radius: 0.85,
                                                              colors: [
                                                                Color(0xFFFFFBEB),
                                                                Color(0xFFFEF3C7),
                                                              ],
                                                            ),
                                                          ),
                                                          child: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Container(
                                                                padding: EdgeInsets.all(isCompact ? 4 : 6),
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
                                                                      blurRadius: 16,
                                                                      spreadRadius: 2,
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Image.asset(
                                                                  AppAssets.goldRbxCoin,
                                                                  width: isCompact ? 54 : 68,
                                                                  height: isCompact ? 54 : 68,
                                                                ),
                                                              ),
                                                              SizedBox(height: isCompact ? 3 : 6),
                                                              FittedBox(
                                                                fit: BoxFit.scaleDown,
                                                                child: Text(
                                                                  '$_rewardAmount RBX',
                                                                  style: TextStyle(
                                                                    fontSize: isCompact ? 24 : 28,
                                                                    fontWeight: FontWeight.w900,
                                                                    color: const Color(0xFF92400E),
                                                                    letterSpacing: 0.5,
                                                                  ),
                                                                ),
                                                              ),
                                                              Container(
                                                                margin: const EdgeInsets.only(top: 2),
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                                child: const Text(
                                                                  '🎉 WINNER!',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w800,
                                                                    color: Color(0xFF78350F),
                                                                    letterSpacing: 0.5,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  // Locked Overlay when 0 scratches left
                                                  if (_scratchesRemaining <= 0 && !_isLoadingLimit)
                                                    Positioned.fill(
                                                      child: Material(
                                                        color: Colors.black.withValues(alpha: 0.45),
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
                                          ),

                                          const SizedBox(height: 8),

                                          // Real-time Scratch Meter
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.auto_awesome_rounded,
                                                size: 13,
                                                color: Color(0xFFFFD700),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${(_scratchProgress * 2).clamp(0, 100).toInt()}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: (_scratchProgress / 50).clamp(0.0, 1.0),
                                                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                                                    minHeight: 5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'Goal: 50%',
                                                style: TextStyle(
                                                  color: Color(0xFFFFE082),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
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
                            ),
                          ),

                          // 4. Live Jackpot Info Ticker
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFDE68A).withValues(alpha: 0.7),
                                width: 1.0,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Jackpot: Win up to ${ref.watch(dailyCapServiceProvider).getRewardLimits('scratch').$2} RBX!',
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

                          // 5. Fixed Bottom Action Button Dock
                          InteractiveButton(
                            height: 52,
                            gradient: _scratchesRemaining <= 0
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  )
                                : AppColors.primaryGradient,
                            textColor: Colors.white,
                            isLoading: _isProcessing && !_hasActiveScratch,
                            onTap: _isProcessing ? null : _watchAdForExtraScratch,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
