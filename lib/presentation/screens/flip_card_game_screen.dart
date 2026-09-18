import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_prefs.dart';
import '../../widgets/interactive_button.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../models/ad_models.dart';
import '../../models/reward_config.dart';
import '../../core/utils/game_reward_helper.dart';
import '../../core/utils/reward_helper.dart';

class FlipCardGameScreen extends ConsumerStatefulWidget {
  const FlipCardGameScreen({super.key});

  @override
  ConsumerState<FlipCardGameScreen> createState() => _FlipCardGameScreenState();
}

class _FlipCardGameScreenState extends ConsumerState<FlipCardGameScreen>
    with TickerProviderStateMixin {
  // Game States: 'MENU', 'PLAYING', 'GAMEOVER'
  String _gameState = 'MENU';

  // Game Metrics
  int _matchesFound = 0;
  final int _totalPairs = 8;
  int _moves = 0;
  int _coinsEarned = 0;
  int _originalCoinsEarned = 0;
  bool _hasClaimed = false;
  bool _isProcessingPlayAgain = false;
  bool _isProcessingClaim = false;

  bool get _isProcessingAd => _isProcessingPlayAgain || _isProcessingClaim;
  int _comboStreak = 0;
  int _maxCombo = 0;
  String? _sessionId;
  DateTime? _gameStartTime;

  // Timer
  int _secondsLeft = 90;
  Timer? _gameTimer;
  double _timerProgress = 1.0;

  // Card Data
  List<_FlipCard> _cards = [];
  int? _firstFlippedIndex;
  int? _secondFlippedIndex;
  bool _isChecking = false;

  // Card symbols (emoji pairs)
  final List<String> _symbols = [
    '💎',
    '🎮',
    '🏆',
    '⭐',
    '🔥',
    '🎯',
    '💰',
    '🚀',
  ];

  // Animations
  late AnimationController _floatController;
  late AnimationController _matchPopController;
  late Animation<double> _matchPopScale;
  final math.Random _random = math.Random();

  // Particle effects
  final List<_MatchParticle> _particles = [];
  Timer? _particleTimer;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _matchPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _matchPopScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _matchPopController, curve: Curves.elasticOut),
    );
    Future.microtask(() {
      ref.read(adServiceProvider).preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _particleTimer?.cancel();
    _floatController.dispose();
    _matchPopController.dispose();
    super.dispose();
  }


  // --- Game Flow ---
  void _startGame() {
    // Build shuffled deck
    final List<String> deck = [];
    for (final symbol in _symbols) {
      deck.add(symbol);
      deck.add(symbol);
    }
    deck.shuffle(_random);

    setState(() {
      _gameState = 'PLAYING';
      _matchesFound = 0;
      _moves = 0;
      _coinsEarned = 0;
      _originalCoinsEarned = 0;
      _hasClaimed = false;
      _isProcessingPlayAgain = false;
      _isProcessingClaim = false;
      _comboStreak = 0;
      _maxCombo = 0;
      _secondsLeft = 90;
      _timerProgress = 1.0;
      _firstFlippedIndex = null;
      _secondFlippedIndex = null;
      _isChecking = false;
      _particles.clear();

      _cards = List.generate(
          deck.length,
          (i) => _FlipCard(
                symbol: deck[i],
                isFlipped: false,
                isMatched: false,
              ));
    });

    _sessionId = ref.read(gameServiceProvider).generateSessionId();
    _gameStartTime = DateTime.now();
    _startSessionTimer();
  }

  void _startSessionTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _gameState != 'PLAYING') {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
          _timerProgress = _secondsLeft / 90.0;
        });
      } else {
        timer.cancel();
        _triggerGameOver();
      }
    });
  }

  void _onCardTap(int index) {
    if (_isChecking) return;
    if (_cards[index].isFlipped || _cards[index].isMatched) return;
    if (_gameState != 'PLAYING') return;

    HapticFeedback.lightImpact();

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
    } else {
      _secondFlippedIndex = index;
      _moves++;
      _isChecking = true;

      // Check for match
      final first = _cards[_firstFlippedIndex!];
      final second = _cards[_secondFlippedIndex!];

      if (first.symbol == second.symbol) {
        // Match found!
        _comboStreak++;
        if (_comboStreak > _maxCombo) _maxCombo = _comboStreak;

        HapticFeedback.mediumImpact();

        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() {
            _cards[_firstFlippedIndex!].isMatched = true;
            _cards[_secondFlippedIndex!].isMatched = true;
            _matchesFound++;
            _firstFlippedIndex = null;
            _secondFlippedIndex = null;
            _isChecking = false;
          });

          // Check win condition
          if (_matchesFound >= _totalPairs) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _triggerGameOver();
            });
          }
        });
      } else {
        // No match - flip both back
        _comboStreak = 0;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() {
            _cards[_firstFlippedIndex!].isFlipped = false;
            _cards[_secondFlippedIndex!].isFlipped = false;
            _firstFlippedIndex = null;
            _secondFlippedIndex = null;
            _isChecking = false;
          });
        });
      }
    }
  }

  Future<void> _triggerGameOver() async {
    _gameTimer?.cancel();

    // Performance-tiered reward based on matches found and time remaining
    final maxBase = ref.read(dailyCapServiceProvider).getBaseReward('flip_card');
    final total = RewardConfig.calculateFlipCardBaseReward(
      matchesFound: _matchesFound,
      timeLeftSeconds: _secondsLeft,
      totalPairs: _totalPairs,
      maxBase: maxBase,
    );

    setState(() {
      _originalCoinsEarned = total;
      _coinsEarned = total;
      _gameState = 'GAMEOVER';
    });

    if (!mounted) return;

    _matchPopController.reset();
    _matchPopController.forward();
    ref.read(adServiceProvider).preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
  }

  void _claimCoins() async {
    if (_originalCoinsEarned <= 0 || _hasClaimed || _isProcessingClaim) {
      if (_hasClaimed && mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isProcessingClaim = true;
    });

    await GamePrefs.incrementGamePlayCount('flip_card');

    if (!mounted) return;

    final premiumReward = _originalCoinsEarned * 4;

    await showRewardChoice(
      context: context,
      featureName: 'Memory Match Reward',
      baseReward: _originalCoinsEarned,
      premiumReward: premiumReward,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.memoryMatchGame,
      multiplier: 4,
      onSuccess: (coins) async {
        final multiplier = coins > _originalCoinsEarned
            ? (coins / _originalCoinsEarned).round().clamp(1, 4)
            : 1;
        final duration = _gameStartTime != null
            ? DateTime.now().difference(_gameStartTime!).inSeconds
            : 1;

        try {
          final result = await ref.read(gameServiceProvider).submitGameResult(
            gameName: 'flip_card',
            score: coins,
            durationSeconds: duration.clamp(1, 3600),
            sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
            originalScore: _originalCoinsEarned,
            multiplier: multiplier,
          );
          if (!mounted) return;
          if (result.success) {
            final earned = result.coinsEarned;
            if (earned > 0) {
              if (result.newBalance != null && result.newBalance! > 0) {
                ref.read(coinProvider.notifier).setAuthoritativeBalance(result.newBalance!);
              } else {
                await ref.read(coinProvider.notifier).credit(earned, 'flip_card');
              }
              ref.read(dailyCapServiceProvider).addCoins(earned, 'flip_card');
            }

            if (mounted) {
              setState(() {
                _hasClaimed = true;
                _coinsEarned = earned;
              });
            }
          } else {
            final isCap = result.error?.toLowerCase().contains('cap') ?? false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isCap ? "You're playing in bonus mode!" : (result.error ?? 'Failed to save game reward'),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save game reward')),
            );
          }
        }
      },
    );

    if (mounted) {
      setState(() {
        _isProcessingClaim = false;
      });
    }
  }

  Future<void> _autoCreditCoinsOnPlayAgain() async {
    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 1;
    try {
      final result = await ref.read(gameServiceProvider).submitGameResult(
        gameName: 'flip_card',
        score: _originalCoinsEarned,
        durationSeconds: duration.clamp(1, 3600),
        sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
        originalScore: _originalCoinsEarned,
        multiplier: 1,
      );
      if (result.success) {
        final earned = result.coinsEarned;
        if (earned > 0) {
          if (result.newBalance != null && result.newBalance! > 0) {
            ref.read(coinProvider.notifier).setAuthoritativeBalance(result.newBalance!);
          } else {
            await ref.read(coinProvider.notifier).credit(earned, 'flip_card');
          }
          ref.read(dailyCapServiceProvider).addCoins(earned, 'flip_card');
        }
        if (mounted) {
          setState(() {
            _hasClaimed = true;
            _coinsEarned = earned;
          });
        }
      }
    } catch (_) {}
  }

  void _playAgain() async {
    if (_isProcessingAd) return;
    setState(() {
      _isProcessingPlayAgain = true;
    });

    if (!_hasClaimed && _originalCoinsEarned > 0) {
      await _autoCreditCoinsOnPlayAgain();
    }

    if (!mounted) return;

    await showPlayAgainVideoAd(
      context: context,
      ref: ref,
      onComplete: () {
        if (mounted) {
          setState(() {
            _isProcessingPlayAgain = false;
          });
          _startGame();
        }
      },
    );
  }

  String _formatTimerText() {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _gameState == 'PLAYING';
    return PopScope(
      canPop: !isPlaying,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isPlaying) return;
        final navigator = Navigator.of(context);
        final shouldLeave = await showQuitConfirmationDialog(
          context,
          title: 'Quit Game?',
          message:
              'Are you sure you want to exit? You will lose unclaimed progress.',
        );
        if (shouldLeave && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              if (_gameState == 'MENU') _buildMenuDecorativeFloaters(),
              Column(
                children: [
                  _buildScreenHeader(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStateView(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenHeader() {
    String headerText = '';
    if (_gameState == 'PLAYING') {
      headerText = 'Matches $_matchesFound/$_totalPairs';
    } else if (_gameState == 'GAMEOVER') {
      headerText = 'Game Results';
    } else {
      headerText = 'Flip Cards';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () async {
                  if (_gameState == 'PLAYING') {
                    final shouldLeave = await showQuitConfirmationDialog(
                      context,
                      title: 'Quit Game?',
                      message:
                          'Are you sure you want to exit? You will lose unclaimed progress.',
                    );
                    if (!mounted) return;
                    if (shouldLeave) {
                      Navigator.of(context).pop();
                    }
                  } else {
                    Navigator.of(context).pop();
                  }
                },
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
            Text(
              headerText,
              style: const TextStyle(
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
    );
  }

  Widget _buildCurrentStateView() {
    switch (_gameState) {
      case 'PLAYING':
        return _buildGameplayScreen();
      case 'GAMEOVER':
        return _buildGameOverScreen();
      case 'MENU':
      default:
        return _buildMenuScreen();
    }
  }

  // --- 1. MENU SCREEN ---
  Widget _buildMenuScreen() {
    final maxBase = ref.watch(dailyCapServiceProvider).getBaseReward('flip_card');
    return SingleChildScrollView(
      key: const ValueKey('MENU'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          _buildLobbyCardsDeck(),
          const SizedBox(height: 18),
          _buildLobbyHeader(),
          const SizedBox(height: 14),
          _buildLobbyRewardPill(maxBase),
          const SizedBox(height: 16),
          _buildLobbyChips(),
          const SizedBox(height: 28),
          _buildLobbyStartButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLobbyCardsDeck() {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-45, 6),
            child: Transform.rotate(
              angle: -0.18,
              child: _buildMiniPreviewCard('💎', true),
            ),
          ),
          Transform.translate(
            offset: const Offset(45, 6),
            child: Transform.rotate(
              angle: 0.18,
              child: _buildMiniPreviewCard('⭐', true),
            ),
          ),
          _buildMiniPreviewCard('🔥', false),
        ],
      ),
    );
  }

  Widget _buildLobbyHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.psychology_rounded, size: 15, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                'MEMORY ARENA',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Memory Match',
          style: GoogleFonts.outfit(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Flip cards, track pairs, and earn RBX\nbefore the countdown expires!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildLobbyRewardPill(int maxBase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.goldRbxCoin, width: 22, height: 22),
          const SizedBox(width: 8),
          Text(
            'Earn up to +$maxBase RBX (4X with Boost)',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6D28D9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLobbySpecChip(Icons.dashboard_rounded, '8 Pairs'),
        const SizedBox(width: 8),
        _buildLobbySpecChip(Icons.timer_outlined, '90 Seconds'),
        const SizedBox(width: 8),
        _buildLobbySpecChip(Icons.local_fire_department_rounded, 'Streak Boost'),
      ],
    );
  }

  Widget _buildLobbySpecChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyStartButton() {
    return InteractiveButton(
      height: 56,
      icon: Icons.play_arrow_rounded,
      iconSize: 24,
      text: 'START GAME',
      fontSize: 16,
      fontWeight: FontWeight.w900,
      onTap: () {
        HapticFeedback.selectionClick();
        _startGame();
      },
    );
  }

  Widget _buildMiniPreviewCard(String text, bool isRevealed) {
    return Container(
      width: 58,
      height: 78,
      decoration: BoxDecoration(
        gradient: isRevealed
            ? null
            : const LinearGradient(
                colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isRevealed ? Colors.white : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRevealed
              ? const Color(0xFF6338F9).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6338F9).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isRevealed ? 26 : 22,
            fontWeight: FontWeight.w900,
            color: isRevealed ? null : Colors.white,
          ),
        ),
      ),
    );
  }

  // --- 2. GAMEPLAY SCREEN ---
  Widget _buildGameplayScreen() {
    return Column(
      key: const ValueKey('PLAYING'),
      children: [
        const SizedBox(height: 8),
        _buildGameplayHeaderStats(),
        const SizedBox(height: 12),
        Expanded(child: _buildCardGrid()),
        _buildGameplayBottomTimer(),
      ],
    );
  }

  Widget _buildGameplayHeaderStats() {
    final isLowTime = _secondsLeft <= 15;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatPill(Icons.touch_app_rounded, 'Moves', '$_moves'),
          const SizedBox(width: 8),
          _buildComboPill(),
          const Spacer(),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isLowTime ? const Color(0xFFFEE2E2) : const Color(0xFFF1F1FB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLowTime ? const Color(0xFFEF4444) : const Color(0xFFE2E2F5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_rounded,
                  color: isLowTime ? const Color(0xFFDC2626) : const Color(0xFF6338F9),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimerText(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isLowTime ? const Color(0xFFDC2626) : const Color(0xFF131326),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComboPill() {
    final hasCombo = _comboStreak >= 2;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: hasCombo ? const Color(0xFFFFF7ED) : const Color(0xFFF1F1FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasCombo ? const Color(0xFFF97316) : const Color(0xFFE2E2F5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: hasCombo ? const Color(0xFFEA580C) : const Color(0xFF6338F9),
            size: 17,
          ),
          const SizedBox(width: 5),
          Text(
            '${_comboStreak}x',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: hasCombo ? const Color(0xFFEA580C) : const Color(0xFF131326),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.74,
        ),
        itemCount: _cards.length,
        itemBuilder: (ctx, i) => _buildGameCard(i),
      ),
    );
  }

  Widget _buildGameplayBottomTimer() {
    final isLowTime = _secondsLeft <= 15;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 14,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _timerProgress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLowTime
                          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                          : [const Color(0xFF6338F9), const Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '$_matchesFound/$_totalPairs Pairs',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String label, String value) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E2F5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6338F9), size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF131326),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(int index) {
    final card = _cards[index];
    final bool showFace = card.isFlipped || card.isMatched;

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: showFace
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF2E1065), Color(0xFF6338F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: showFace
              ? (card.isMatched ? const Color(0xFFECFDF5) : Colors.white)
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: card.isMatched
                ? const Color(0xFF10B981)
                : (showFace
                    ? const Color(0xFF6338F9)
                    : const Color(0xFF8B64FF).withValues(alpha: 0.5)),
            width: card.isMatched ? 2.5 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: card.isMatched
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFF6338F9).withValues(alpha: showFace ? 0.12 : 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: showFace
                ? Text(
                    card.symbol,
                    key: ValueKey('face_$index'),
                    style: const TextStyle(fontSize: 30),
                  )
                : Container(
                    key: ValueKey('back_$index'),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // --- 3. GAMEOVER SCREEN ---
  Widget _buildGameOverScreen() {
    final bool didWin = _originalCoinsEarned > 0;
    final bool clearedBoard = _matchesFound >= _totalPairs;
    final tierName = !didWin
        ? 'Keep Practicing'
        : (_originalCoinsEarned >= 12
            ? 'Photographic Memory 🥇'
            : (_originalCoinsEarned >= 8 ? 'Memory Master 🥈' : 'Sharp Mind 🥉'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final useSmallStyle = screenHeight < 680;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Column(
                key: const ValueKey('GAMEOVER'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  _buildGameOverHero(didWin, useSmallStyle),
                  SizedBox(height: useSmallStyle ? 10 : 16),
                  _buildStarRating(didWin, clearedBoard),
                  SizedBox(height: useSmallStyle ? 6 : 10),
                  _buildGameOverTitle(didWin, clearedBoard, useSmallStyle),
                  SizedBox(height: useSmallStyle ? 12 : 20),
                  _buildGameOverBreakdown(didWin, tierName, useSmallStyle),
                  const Spacer(),
                  _buildGameOverButtons(didWin, useSmallStyle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameOverHero(bool didWin, bool useSmallStyle) {
    final size = useSmallStyle ? 72.0 : 88.0;
    return ScaleTransition(
      scale: _matchPopScale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: didWin ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (didWin ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
                  .withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          didWin ? Icons.emoji_events_rounded : Icons.close_rounded,
          color: didWin ? const Color(0xFFD97706) : const Color(0xFFDC2626),
          size: useSmallStyle ? 38 : 46,
        ),
      ),
    );
  }

  Widget _buildStarRating(bool didWin, bool clearedBoard) {
    int stars = 0;
    if (clearedBoard && _secondsLeft >= 45) {
      stars = 3;
    } else if (clearedBoard) {
      stars = 2;
    } else if (didWin) {
      stars = 1;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isFilled = i < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.star_rounded,
            size: 26,
            color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
          ),
        );
      }),
    );
  }

  Widget _buildGameOverTitle(bool didWin, bool clearedBoard, bool useSmallStyle) {
    final headerTitle = !didWin
        ? (clearedBoard ? 'Board Cleared!' : "Time's Up!")
        : (_originalCoinsEarned >= 12
            ? 'Photographic Memory!'
            : (_originalCoinsEarned >= 8 ? 'Memory Master!' : 'Sharp Mind!'));

    return Column(
      children: [
        Text(
          headerTitle,
          style: GoogleFonts.outfit(
            fontSize: useSmallStyle ? 24 : 30,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_matchesFound/$_totalPairs Pairs Matched  •  $_moves Moves',
          style: GoogleFonts.inter(
            fontSize: useSmallStyle ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverBreakdown(bool didWin, String tierName, bool useSmallStyle) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: useSmallStyle ? 20 : 36),
      child: Container(
        padding: EdgeInsets.all(useSmallStyle ? 14 : 18),
        decoration: BoxDecoration(
          color: didWin ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: didWin ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            _buildRewardRow('Pairs Matched', '$_matchesFound / $_totalPairs'),
            const SizedBox(height: 8),
            _buildRewardRow('Time Remaining', '${_secondsLeft}s'),
            const SizedBox(height: 8),
            _buildRewardRow('Performance Tier', tierName),
            const SizedBox(height: 8),
            _buildRewardRow('Base Reward', '+$_originalCoinsEarned RBX'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFDDD6FE)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Earned',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF181C32),
                  ),
                ),
                Row(
                  children: [
                    Image.asset(AppAssets.goldRbxCoin, width: 20, height: 20),
                    const SizedBox(width: 5),
                    Text(
                      '+$_coinsEarned RBX',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverButtons(bool didWin, bool useSmallStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          if (didWin && !_hasClaimed) ...[
            _buildPrimaryClaimButton(useSmallStyle),
            SizedBox(height: useSmallStyle ? 10 : 12),
            _buildSecondaryPlayAgainButton(useSmallStyle),
          ] else ...[
            _buildPrimaryPlayAgainButton(didWin, useSmallStyle),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrimaryClaimButton(bool useSmallStyle) {
    return InteractiveButton(
      height: useSmallStyle ? 50 : 56,
      isLoading: _isProcessingClaim,
      onTap: _isProcessingAd ? null : _claimCoins,
      text: 'Claim Reward (+$_originalCoinsEarned RBX)',
      fontSize: useSmallStyle ? 14 : 15,
      fontWeight: FontWeight.w900,
    );
  }

  Widget _buildSecondaryPlayAgainButton(bool useSmallStyle) {
    return InteractiveButton(
      height: useSmallStyle ? 44 : 50,
      isLoading: _isProcessingPlayAgain,
      onTap: _isProcessingAd ? null : _playAgain,
      backgroundColor: AppColors.primarySoft,
      border: Border.all(color: AppColors.cardBorder, width: 1.5),
      textColor: AppColors.purple,
      text: 'Play Again',
      fontSize: useSmallStyle ? 13 : 15,
      fontWeight: FontWeight.w800,
    );
  }

  Widget _buildPrimaryPlayAgainButton(bool didWin, bool useSmallStyle) {
    return InteractiveButton(
      height: useSmallStyle ? 50 : 56,
      isLoading: _isProcessingPlayAgain,
      onTap: _isProcessingAd ? null : _playAgain,
      text: didWin ? 'Play Again' : 'Try Again',
      fontSize: useSmallStyle ? 14 : 16,
      fontWeight: FontWeight.w900,
    );
  }

  Widget _buildRewardRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF181C32),
          ),
        ),
      ],
    );
  }

  // --- Background Decorative Drift Elements ---
  Widget _buildMenuDecorativeFloaters() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatOffset = math.sin(_floatController.value * 2 * math.pi) * 12.0;
        return Stack(
          children: [
            Positioned(
              top: 80 + floatOffset,
              left: 30,
              child: _buildDecorativeSymbol('🃏', 48, const Color(0xFF6338F9).withValues(alpha: 0.7)),
            ),
            Positioned(
              top: 40 - floatOffset,
              right: 140,
              child: _buildDecorativeSymbol('✨', 40, const Color(0xFF8B64FF).withValues(alpha: 0.7)),
            ),
            Positioned(
              top: 100 + floatOffset,
              right: 40,
              child: _buildDecorativeSymbol('🎴', 44, const Color(0xFF6338F9).withValues(alpha: 0.7)),
            ),
            Positioned(
              bottom: 120 + floatOffset,
              left: 45,
              child: _buildDecorativeSymbol('🃏', 46, const Color(0xFF6338F9).withValues(alpha: 0.7)),
            ),
            Positioned(
              bottom: 80 - floatOffset,
              right: 120,
              child: _buildDecorativeSymbol('✨', 38, const Color(0xFF8B64FF).withValues(alpha: 0.7)),
            ),
            Positioned(
              bottom: 140 + floatOffset,
              right: 50,
              child: _buildDecorativeSymbol('🎴', 42, const Color(0xFF6338F9).withValues(alpha: 0.7)),
            ),
            Positioned(
              top: 160 - floatOffset,
              right: -20,
              child: Transform.rotate(
                angle: 0.4,
                child: Image.asset(AppAssets.goldCoin, width: 80, height: 80),
              ),
            ),
            Positioned(
              bottom: 160 + floatOffset,
              left: -20,
              child: Transform.rotate(
                angle: -0.3,
                child: Image.asset(AppAssets.goldCoin, width: 70, height: 70),
              ),
            ),
            Positioned(
              bottom: 40 - floatOffset,
              right: -10,
              child: Transform.rotate(
                angle: 0.25,
                child: Image.asset(AppAssets.goldCoin, width: 85, height: 85),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDecorativeSymbol(String symbol, double size, Color color) {
    return Transform.rotate(
      angle: 0.15,
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: size,
          shadows: [
            Shadow(
              blurRadius: 10,
              color: color.withValues(alpha: 0.18),
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Data Model ---
class _FlipCard {
  final String symbol;
  bool isFlipped;
  bool isMatched;

  _FlipCard({
    required this.symbol,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class _MatchParticle {
  double x, y, vx, vy;
  double age = 0.0;
  double lifeTime;
  Color color;

  _MatchParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.lifeTime,
    required this.color,
  });
}
