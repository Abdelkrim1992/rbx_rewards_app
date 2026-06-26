import 'dart:math';
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
import '../../core/utils/reward_helper.dart';
import '../../widgets/game_prefs.dart';

class ScratchCardScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ScratchCardScreen({super.key, required this.onBack});

  @override
  ConsumerState<ScratchCardScreen> createState() => _ScratchCardScreenState();
}

class _ScratchCardScreenState extends ConsumerState<ScratchCardScreen> {
  final GlobalKey<ScratcherState> _scratcherKey = GlobalKey<ScratcherState>();
  bool _isScratched = false;
  bool _isProcessing = false;
  late int _rewardAmount;
  static int _scratchCount = 0; // Track scratches for ad display
  
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

  void _generateReward() {
    final random = Random();
    final weights = [30, 30, 20, 15, 5]; // 5, 10, 15, 20, 50
    final rewards = [5, 10, 15, 20, 50];
    final total = weights.fold<int>(0, (sum, w) => sum + w);
    var roll = random.nextInt(total);
    int selectedIndex = 0;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        selectedIndex = i;
        break;
      }
    }
    _rewardAmount = rewards[selectedIndex];
  }

  void _resetScratchCard() {
    setState(() {
      _isScratched = false;
      _generateReward();
    });
    _scratcherKey.currentState?.reset(duration: const Duration(milliseconds: 300));
  }

  Future<void> _handleScratchWin() async {
    if (_isScratched || _isProcessing) return;
    
    setState(() {
      _isScratched = true;
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
      onSuccess: (coins) async {
        await ref.read(coinProvider.notifier).credit(coins, 'scratch');
        await GamePrefs.decrementScratchesRemaining();
        _scratchCount++;
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
        _scratchCount++;
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

  @override
  Widget build(BuildContext context) {
    final capService = ref.watch(dailyCapServiceProvider);
    final isScratchCapReached = capService.isCapReachedFor('scratch');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isScratchBlocked = isScratchCapReached || isFeaturesCapReached;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_isScratched && _scratcherKey.currentState?.progress != 0.0) {
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
                          onTap: widget.onBack,
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
                      const Text(
                        'Scratch & Win',
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
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
                  child: Column(
                    children: [
                      // Scratches Left Indicator
                      if (!_isLoadingLimit)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            isScratchBlocked
                                ? 'Daily limit or feature cap reached today.'
                                : 'Scratches remaining today: $_scratchesRemaining/${GamePrefs.maxScratchesPerDay}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),

                      // Scratch Card Container
                      Container(
                        padding: const EdgeInsets.all(16),
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
                            const Text(
                              'Scratch below to reveal!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: IgnorePointer(
                                ignoring: _scratchesRemaining <= 0 || _isLoadingLimit || isScratchBlocked,
                                child: Scratcher(
                                  key: _scratcherKey,
                                  brushSize: 40,
                                  threshold: 50,
                                  color: AppColors.primaryLight,
                                  image: Image.asset(
                                    AppAssets.dailyRewardImage,
                                    fit: BoxFit.cover,
                                  ),
                                onChange: (value) {
                                  // Can optionally play sound or haptics here
                                },
                                onThreshold: () {
                                  _handleScratchWin();
                                },
                                child: Container(
                                  height: 250,
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        AppAssets.goldRbxCoin,
                                        width: 80,
                                        height: 80,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '$_rewardAmount RBX',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      const Text(
                                        'You Won!',
                                        style: TextStyle(
                                          fontSize: 16,
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Button showing current status
                      InteractiveButton(
                        height: 52,
                        gradient: AppColors.primaryGradient,
                        textColor: Colors.white,
                        onTap: null, // Card resets automatically now
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              (_scratchesRemaining <= 0 || isScratchBlocked) ? Icons.timer : Icons.touch_app, 
                              color: Colors.white, 
                              size: 22
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (_scratchesRemaining <= 0 || isScratchBlocked) 
                                  ? 'Limit Reached for Today' 
                                  : 'Scratch the card above!',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // How to Play Section
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'How to Play',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF131326),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _HowToStep(
                        icon: Icons.touch_app,
                        title: 'Scratch the Card',
                        description: 'Use your finger to scratch away the cover and reveal what\'s underneath.',
                        color: Color(0xFF9B5CFF),
                      ),
                      const SizedBox(height: 8),
                      const _HowToStep(
                        icon: Icons.monetization_on,
                        title: 'Reveal the Prize',
                        description: 'Match the hidden symbols to win up to 50 RBX instantly.',
                        color: Color(0xFF6B4BF4),
                      ),
                      const SizedBox(height: 8),
                      const _HowToStep(
                        icon: Icons.play_circle_outline,
                        title: 'Get More Cards',
                        description: 'Watch a short video to get another scratch card.',
                        color: Color(0xFF4A2BC2),
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
        border: Border.all(color: const Color(0xFFF1F2F8)),
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
              color: color.withValues(alpha: 0.1),
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
