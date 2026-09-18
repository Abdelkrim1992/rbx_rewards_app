import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../models/ad_models.dart';
import '../../models/reward_config.dart';
import '../../widgets/game_prefs.dart';
import '../../core/utils/game_reward_helper.dart';
import '../../core/utils/reward_helper.dart';

class MathQuestion {
  final String text;
  final int correctAnswer;
  final List<int> options;

  MathQuestion({
    required this.text,
    required this.correctAnswer,
    required this.options,
  });
}

class MathQuizScreen extends ConsumerStatefulWidget {
  const MathQuizScreen({super.key});

  @override
  ConsumerState<MathQuizScreen> createState() => _MathQuizScreenState();
}

class _MathQuizScreenState extends ConsumerState<MathQuizScreen>
    with TickerProviderStateMixin {
  // Game States: 'MENU', 'PLAYING', 'GAMEOVER'
  String _gameState = 'MENU';

  // Game Metrics
  int _correctCount = 0;
  int _questionIndex = 1;
  final int _totalQuestions = 10;
  int _originalCoinsEarned = 0;
  String? _sessionId;
  DateTime? _gameStartTime;
  bool _isQuitting = false;
  bool _hasClaimed = false;
  bool _isProcessingPlayAgain = false;
  bool _isProcessingClaim = false;

  bool get _isProcessingAd => _isProcessingPlayAgain || _isProcessingClaim;

  // Active question details
  late MathQuestion _currentQuestion;
  int? _selectedAnswer;

  // Session Timer (60 seconds total countdown)
  int _secondsLeft = 60;
  Timer? _quizTimer;
  double _timerProgress = 1.0;

  // Decorative floaters animations
  late AnimationController _floatController;
  final math.Random _random = math.Random();

  // Scale pop animation for results screen
  late AnimationController _matchPopController;
  late Animation<double> _matchPopScale;

  @override
  void initState() {
    super.initState();

    // Loop floating animation for floating background elements
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final adService = ref.read(adServiceProvider);
        adService.preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
        adService.preloadInterstitial(AdPlacement.miniGameCompletion);
      }
    });
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _floatController.dispose();
    _matchPopController.dispose();
    super.dispose();
  }

  // --- Audio Feedback Synthetics ---
  void _playFeedbackTone(bool isCorrect) {
    if (isCorrect) {
      SystemSound.play(SystemSoundType.click);
      Future.delayed(const Duration(milliseconds: 70), () {
        SystemSound.play(SystemSoundType.click);
      });
    } else {
      HapticFeedback.vibrate();
    }
  }

  // --- Game Flow Mechanics ---
  void _startQuizRound() {
    final isMathBlocked = ref.read(dailyCapServiceProvider).isCapReachedFor('math_quiz') || ref.read(dailyCapServiceProvider).isFeaturesCapReached;
    if (isMathBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily math quiz limit or feature cap reached today.'),
          backgroundColor: AppColors.purple,
        ),
      );
      return;
    }
    setState(() {
      _gameState = 'PLAYING';
      _correctCount = 0;
      _questionIndex = 1;
      _originalCoinsEarned = 0;
      _secondsLeft = 60;
      _timerProgress = 1.0;
      _selectedAnswer = null;
      _hasClaimed = false;
      _isProcessingPlayAgain = false;
      _isProcessingClaim = false;
    });

    _sessionId = ref.read(gameServiceProvider).generateSessionId();
    _gameStartTime = DateTime.now();
    _generateQuestion();
    _startSessionTimer();
  }

  void _generateQuestion() {
    // Alternate operation modes to offer variety
    final modes = ['+', '-', '×', '÷'];
    final mode = modes[_random.nextInt(modes.length)];

    String questionText = '';
    int correctAnswer = 0;

    if (mode == '+') {
      final a = _random.nextInt(15) + 3;
      final b = _random.nextInt(15) + 3;
      questionText = '$a + $b';
      correctAnswer = a + b;
    } else if (mode == '-') {
      final a = _random.nextInt(25) + 8;
      final b = _random.nextInt(a - 2) + 2;
      questionText = '$a - $b';
      correctAnswer = a - b;
    } else if (mode == '×') {
      final a = _random.nextInt(10) + 2;
      final b = _random.nextInt(8) + 2;
      questionText = '$a × $b';
      correctAnswer = a * b;
    } else {
      final b = _random.nextInt(8) + 2;
      correctAnswer = _random.nextInt(9) + 2; // ensure clean quotient division
      final a = b * correctAnswer;
      questionText = '$a ÷ $b';
    }

    // Generate 4 randomized options (unique)
    final Set<int> optionsSet = {correctAnswer};
    while (optionsSet.length < 4) {
      int offset = _random.nextInt(10) - 5;
      if (offset == 0) offset = _random.nextBool() ? 2 : -2;
      final alt = correctAnswer + offset;
      if (alt >= 0) optionsSet.add(alt);
    }

    final List<int> sortedOptions = optionsSet.toList()..shuffle();

    setState(() {
      _currentQuestion = MathQuestion(
        text: questionText,
        correctAnswer: correctAnswer,
        options: sortedOptions,
      );
      _selectedAnswer = null;
    });
  }

  void _startSessionTimer() {
    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _gameState != 'PLAYING') {
        timer.cancel();
        return;
      }

      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
          _timerProgress = _secondsLeft / 60.0;
        });
      } else {
        timer.cancel();
        _triggerQuizComplete();
      }
    });
  }

  void _checkAnswer(int optIdx, int selectedValue) {
    if (_selectedAnswer != null) return; // Answer already submitted

    final isCorrect = selectedValue == _currentQuestion.correctAnswer;
    _playFeedbackTone(isCorrect);

    setState(() {
      _selectedAnswer = optIdx;
    });

    if (isCorrect) {
      _correctCount++;
    }

    HapticFeedback.lightImpact();

    // Wait briefly and proceed to next question or end
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_questionIndex < _totalQuestions) {
        setState(() {
          _questionIndex++;
        });
        _generateQuestion();
      } else {
        _triggerQuizComplete();
      }
    });
  }

  void _triggerQuizComplete() {
    _quizTimer?.cancel();

    final maxBase = ref.read(dailyCapServiceProvider).getBaseReward('math_quiz');
    final coins = RewardConfig.calculateMathQuizBaseReward(
      _correctCount,
      _totalQuestions,
      maxBase: maxBase,
      timeLeftSeconds: _secondsLeft,
    );

    setState(() {
      _originalCoinsEarned = coins;
      _gameState = 'GAMEOVER';
    });

    ref.read(adServiceProvider).preloadRewardedInterstitial(AdPlacement.miniGameCompletion);

    _matchPopController.reset();
    _matchPopController.forward();
  }

  Future<bool> _submitAndRecordReward({int multiplier = 1, int? coinsToAward}) async {
    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 1;

    final targetCoins = coinsToAward ?? _originalCoinsEarned * multiplier;

    try {
      final result = await ref.read(gameServiceProvider).submitGameResult(
        gameName: 'math_quiz',
        score: targetCoins,
        durationSeconds: duration.clamp(1, 3600),
        sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
        originalScore: _originalCoinsEarned,
        multiplier: multiplier,
      );
      if (!mounted) return false;
      if (result.success) {
        final earned = result.coinsEarned;
        if (earned > 0) {
          if (result.newBalance != null && result.newBalance! > 0) {
            ref.read(coinProvider.notifier).setAuthoritativeBalance(result.newBalance!);
          } else {
            await ref.read(coinProvider.notifier).credit(earned, 'math_quiz');
          }
          ref.read(dailyCapServiceProvider).addCoins(earned, 'math_quiz');
        }

        if (mounted) {
          setState(() {
            _hasClaimed = true;
          });
        }
        return true;
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
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save game reward')),
        );
      }
      return false;
    }
  }

  void _claimQuizCoins() async {
    if (_originalCoinsEarned <= 0 || _hasClaimed || _isProcessingClaim) {
      if (_hasClaimed && mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isProcessingClaim = true;
    });

    await GamePrefs.incrementGamePlayCount('math_quiz');

    if (!mounted) return;

    final premiumReward = _originalCoinsEarned * 4;

    await showRewardChoice(
      context: context,
      featureName: 'Math Quiz Reward',
      baseReward: _originalCoinsEarned,
      premiumReward: premiumReward,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.quizMasterGame,
      multiplier: 4,
      onSuccess: (coins) async {
        final multiplier = coins > _originalCoinsEarned
            ? (coins / _originalCoinsEarned).round().clamp(1, 4)
            : 1;
        await _submitAndRecordReward(multiplier: multiplier, coinsToAward: coins);
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
        gameName: 'math_quiz',
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
            await ref.read(coinProvider.notifier).credit(earned, 'math_quiz');
          }
          ref.read(dailyCapServiceProvider).addCoins(earned, 'math_quiz');
        }
        if (mounted) {
          setState(() {
            _hasClaimed = true;
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
          _startQuizRound();
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
    final capService = ref.watch(dailyCapServiceProvider);
    final isMathCapReached = capService.isCapReachedFor('math_quiz');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isMathBlocked = isMathCapReached || isFeaturesCapReached;

    return PopScope(
      canPop: !isPlaying || _isQuitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isPlaying || _isQuitting) return;
        final shouldLeave = await showQuitConfirmationDialog(
          context,
          title: 'Quit Quiz?',
          message:
              'Are you sure you want to exit the Math Quiz? You will lose unclaimed progress.',
        );
        if (!mounted) return;
        if (shouldLeave) {
          setState(() => _isQuitting = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // Floating 3D decorative background elements (drifting mathematically)
              if (_gameState == 'MENU') _buildMenuDecorativeFloaters(),

              Column(
                children: [
                  _buildScreenHeader(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStateView(isMathBlocked),
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
      headerText = 'Question $_questionIndex/$_totalQuestions';
    } else if (_gameState == 'GAMEOVER') {
      headerText = 'Quiz Results';
    } else {
      headerText = 'Math Quiz';
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
                      title: 'Quit Quiz?',
                      message:
                          'Are you sure you want to exit the Math Quiz? You will lose unclaimed progress.',
                    );
                    if (!mounted) return;
                    if (shouldLeave) {
                      setState(() => _isQuitting = true);
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

  Widget _buildCurrentStateView(bool isMathBlocked) {
    switch (_gameState) {
      case 'PLAYING':
        return _buildGameplayScreen();
      case 'GAMEOVER':
        return _buildGameOverScreen();
      case 'MENU':
      default:
        return _buildMenuScreen(isMathBlocked);
    }
  }

  // --- 1. MENU SCREEN ---
  Widget _buildMenuScreen(bool isMathBlocked) {
    final maxBase = ref.watch(dailyCapServiceProvider).getBaseReward('math_quiz');
    return SingleChildScrollView(
      key: const ValueKey('MENU'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          _buildMenuIllustration(),
          const SizedBox(height: 18),
          _buildMenuHeader(isMathBlocked),
          const SizedBox(height: 14),
          _buildMenuRewardPill(maxBase, isMathBlocked),
          const SizedBox(height: 16),
          _buildMenuChips(),
          const SizedBox(height: 28),
          _buildMenuStartButton(isMathBlocked),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMenuIllustration() {
    return SizedBox(
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6338F9).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.calculate_rounded, color: Colors.white, size: 48),
            ),
          ),
          Transform.translate(
            offset: const Offset(-52, -18),
            child: _buildFloatingBadge('+', const Color(0xFF10B981)),
          ),
          Transform.translate(
            offset: const Offset(54, 18),
            child: _buildFloatingBadge('×', const Color(0xFFF59E0B)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBadge(String text, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }

  Widget _buildMenuHeader(bool isMathBlocked) {
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
              const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFF7C3AED)),
              const SizedBox(width: 5),
              Text(
                'BRAIN LAB ARENA',
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
          'Speed Math',
          style: GoogleFonts.outfit(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isMathBlocked
              ? 'Daily limit or feature cap reached today.'
              : 'Solve 10 fast math problems and\nearn instant RBX rewards!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isMathBlocked ? const Color(0xFFEF4444) : const Color(0xFF64748B),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuRewardPill(int maxBase, bool isMathBlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMathBlocked ? const Color(0xFFF1F5F9) : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMathBlocked ? const Color(0xFFE2E8F0) : const Color(0xFFDDD6FE),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.goldRbxCoin, width: 22, height: 22),
          const SizedBox(width: 8),
          Text(
            isMathBlocked ? 'Limit Reached' : 'Earn up to +$maxBase RBX (4X with Boost)',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isMathBlocked ? const Color(0xFF64748B) : const Color(0xFF6D28D9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuChips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildLobbySpecChip(Icons.format_list_numbered_rounded, '10 Questions'),
        _buildLobbySpecChip(Icons.timer_outlined, '60 Seconds'),
        _buildLobbySpecChip(Icons.military_tech_rounded, 'Score Tiers'),
      ],
    );
  }

  Widget _buildLobbySpecChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.purple),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuStartButton(bool isMathBlocked) {
    return GestureDetector(
      onTap: isMathBlocked
          ? null
          : () {
              HapticFeedback.selectionClick();
              _startQuizRound();
            },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: isMathBlocked
              ? const LinearGradient(
                  colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMathBlocked ? Icons.lock_clock_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isMathBlocked ? 'CAP REACHED' : 'START QUIZ',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. GAMEPLAY SCREEN ---
  Widget _buildGameplayScreen() {
    return LayoutBuilder(
      key: const ValueKey('PLAYING'),
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isSmall = availableHeight < 580;

        // On very small screens use a scroll view to prevent overflow
        if (isSmall) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildGameplayTopHUD(),
                const SizedBox(height: 24),
                _buildQuestionCard(),
                const SizedBox(height: 20),
                _buildAnswerGrid(),
                const SizedBox(height: 16),
                _buildGameplayBottomBar(),
              ],
            ),
          );
        }

        return Column(
          children: [
            const SizedBox(height: 8),
            _buildGameplayTopHUD(),
            const Spacer(),
            _buildQuestionCard(),
            const SizedBox(height: 24),
            _buildAnswerGrid(),
            const Spacer(),
            _buildGameplayBottomBar(),
          ],
        );
      },
    );
  }

  Widget _buildGameplayTopHUD() {
    final isLowTime = _secondsLeft <= 15;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E2F5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF6338F9)),
                const SizedBox(width: 6),
                Text(
                  '$_questionIndex / $_totalQuestions',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF131326),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 5),
                Text(
                  '$_correctCount',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildQuestionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF6338F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF8B64FF).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6338F9).withValues(alpha: 0.3),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '${_currentQuestion.text} = ?',
          style: GoogleFonts.outfit(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildAnswerButton(0)),
              const SizedBox(width: 12),
              Expanded(child: _buildAnswerButton(1)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildAnswerButton(2)),
              const SizedBox(width: 12),
              Expanded(child: _buildAnswerButton(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(int idx) {
    final optValue = _currentQuestion.options[idx];
    final isSelected = _selectedAnswer == idx;
    final isCorrectOption = optValue == _currentQuestion.correctAnswer;

    Color bgC = const Color(0xFFF8FAFC);
    Color borderC = const Color(0xFFE2E8F0);
    Color textC = const Color(0xFF1E293B);

    if (_selectedAnswer != null) {
      if (isCorrectOption) {
        bgC = const Color(0xFFECFDF5);
        borderC = const Color(0xFF10B981);
        textC = const Color(0xFF065F46);
      } else if (isSelected) {
        bgC = const Color(0xFFFEF2F2);
        borderC = const Color(0xFFEF4444);
        textC = const Color(0xFF991B1B);
      }
    }

    return GestureDetector(
      onTap: () => _checkAnswer(idx, optValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 62,
        decoration: BoxDecoration(
          color: bgC,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderC, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: borderC.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$optValue',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: textC),
        ),
      ),
    );
  }

  Widget _buildGameplayBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _timerProgress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '$_questionIndex/$_totalQuestions',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. GAMEOVER SCREEN ---
  Widget _buildGameOverScreen() {
    final bool didWin = _correctCount >= 2;
    final tierName = _correctCount < 2
        ? 'Target Not Reached'
        : (_correctCount <= 3
            ? 'Bronze Mind 🥉'
            : (_correctCount <= 7 ? 'Silver Scholar 🥈' : 'Math Genius 🥇'));

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
                  _buildStarRating(_correctCount),
                  SizedBox(height: useSmallStyle ? 6 : 10),
                  _buildGameOverTitle(didWin, useSmallStyle),
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

  Widget _buildStarRating(int correctCount) {
    int stars = 0;
    if (correctCount >= 8) {
      stars = 3;
    } else if (correctCount >= 5) {
      stars = 2;
    } else if (correctCount >= 2) {
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

  Widget _buildGameOverTitle(bool didWin, bool useSmallStyle) {
    final headerTitle = !didWin
        ? 'Quiz Incomplete'
        : (_correctCount >= 8
            ? 'Math Genius!'
            : (_correctCount >= 5 ? 'Great Performance!' : 'Good Effort!'));

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
          '$_correctCount/$_totalQuestions Correct • ${((_correctCount / _totalQuestions) * 100).round()}% Accuracy',
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
            _buildRewardRow('Correct Answers', '$_correctCount/$_totalQuestions'),
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
                      '+$_originalCoinsEarned RBX',
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
    return GestureDetector(
      onTap: _isProcessingAd ? null : _claimQuizCoins,
      child: Container(
        width: double.infinity,
        height: useSmallStyle ? 50 : 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: _isProcessingClaim
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  'Claim Reward (+$_originalCoinsEarned RBX)',
                  style: GoogleFonts.outfit(
                    fontSize: useSmallStyle ? 14 : 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSecondaryPlayAgainButton(bool useSmallStyle) {
    return GestureDetector(
      onTap: _isProcessingAd ? null : _playAgain,
      child: Container(
        width: double.infinity,
        height: useSmallStyle ? 44 : 50,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
        ),
        child: Center(
          child: _isProcessingPlayAgain
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: AppColors.purple, strokeWidth: 2.0),
                )
              : Text(
                  'Play Again',
                  style: GoogleFonts.outfit(
                    fontSize: useSmallStyle ? 13 : 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purple,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPrimaryPlayAgainButton(bool didWin, bool useSmallStyle) {
    return GestureDetector(
      onTap: _isProcessingAd ? null : _playAgain,
      child: Container(
        width: double.infinity,
        height: useSmallStyle ? 50 : 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: _isProcessingPlayAgain
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  didWin ? 'Play Again' : 'Try Again',
                  style: GoogleFonts.outfit(
                    fontSize: useSmallStyle ? 14 : 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
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
              child: _buildDecorativeSymbol('÷', 48, const Color(0xFF6338F9).withValues(alpha: 0.7)),
            ),
            Positioned(
              top: 40 - floatOffset,
              right: 140,
              child: _buildDecorativeSymbol('=', 40, const Color(0xFF8B64FF).withValues(alpha: 0.7)),
            ),
            Positioned(
              top: 100 + floatOffset,
              right: 40,
              child: _buildDecorativeSymbol('+', 44, const Color(0xFF6338F9).withValues(alpha: 0.7)),
            ),
            Positioned(
              bottom: 120 + floatOffset,
              left: 45,
              child: _buildDecorativeSymbol('÷', 46, const Color(0xFF6338F9).withValues(alpha: 0.7)),
            ),
            Positioned(
              bottom: 80 - floatOffset,
              right: 120,
              child: _buildDecorativeSymbol('=', 38, const Color(0xFF8B64FF).withValues(alpha: 0.7)),
            ),
            Positioned(
              bottom: 140 + floatOffset,
              right: 50,
              child: _buildDecorativeSymbol('×', 42, const Color(0xFF6338F9).withValues(alpha: 0.7)),
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
        style: GoogleFonts.outfit(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
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
