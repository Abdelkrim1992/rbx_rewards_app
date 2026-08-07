import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../providers/ad_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../models/ad_models.dart';
import '../../core/utils/game_reward_helper.dart';
import '../../widgets/congratulations_dialog.dart';

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
  int _score = 0;
  int _correctCount = 0;
  int _questionIndex = 1;
  final int _totalQuestions = 10;
  int _coinsEarned = 0;
  int _originalCoinsEarned = 0;
  final int _highScore = 0;
  int _userCoins = 0;
  String? _sessionId;
  DateTime? _gameStartTime;
  bool _isQuitting = false;
  bool _watchedRewardedAd = false;
  bool _hasClaimed = false;
  static final int _claimCount = 0;

  // Active question details
  late MathQuestion _currentQuestion;
  int? _selectedAnswer;
  bool? _isCorrectAnswer;

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
    _loadHighScoreAndCoins();

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
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _floatController.dispose();
    _matchPopController.dispose();
    super.dispose();
  }

  Future<void> _loadHighScoreAndCoins() async {
    final currentCoins = ref.read(coinProvider);
    setState(() {
      _userCoins = currentCoins;
    });
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
      _score = 0;
      _coinsEarned = 0;
      _originalCoinsEarned = 0;
      _secondsLeft = 60;
      _timerProgress = 1.0;
      _selectedAnswer = null;
      _isCorrectAnswer = null;
      _watchedRewardedAd = false;
      _hasClaimed = false;
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
      _isCorrectAnswer = null;
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
      _isCorrectAnswer = isCorrect;
    });

    if (isCorrect) {
      _correctCount++;
      _score += 10;
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

    // 2 coins per correct answer, max 20 base coins
    final coins = (_correctCount * 2).clamp(0, 20);

    setState(() {
      _originalCoinsEarned = coins;
      _coinsEarned = coins;
      _gameState = 'GAMEOVER';
    });

    _loadHighScoreAndCoins();

    _matchPopController.reset();
    _matchPopController.forward();
  }

  void _claimQuizCoins() async {
    if (_originalCoinsEarned <= 0 || _hasClaimed) {
      Navigator.of(context).pop();
      return;
    }

    final detailsDescription = 'Correct Answers: $_correctCount/$_totalQuestions\n\nSupercharge your math quiz rewards!';

    await showGameRewardChoice(
      context: context,
      featureName: 'Math Quiz',
      description: detailsDescription,
      baseReward: _originalCoinsEarned,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.doubleReward,
      icon: Icons.calculate,
      iconBgColor: AppColors.primarySoft,
      iconColor: AppColors.primary,
      premiumGradient: AppColors.primaryGradient,
      quickTextColor: AppColors.primary,
      quickBorderColor: const Color(0xFFE5E7EB),
      onSuccess: (coins) {
        Future.delayed(Duration.zero, () async {
          if (!mounted) return;
          setState(() {
            _watchedRewardedAd = (coins == _originalCoinsEarned * 2);
            _coinsEarned = coins;
          });

          final duration = _gameStartTime != null
              ? DateTime.now().difference(_gameStartTime!).inSeconds
              : 1;

          try {
            final result = await ref.read(gameServiceProvider).submitGameResult(
              gameName: 'math_quiz',
              score: coins,
              durationSeconds: duration.clamp(1, 3600),
              sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
              originalScore: _originalCoinsEarned,
              multiplier: _watchedRewardedAd ? 2 : 1,
            );
            if (result.success || result.queued) {
              final earned = result.coinsEarned > 0 ? result.coinsEarned : coins;
              ref.read(coinProvider.notifier).updateBalance(ref.read(coinProvider) + earned);
              ref.read(dailyCapServiceProvider).addCoins(earned, 'math_quiz');
              
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => CongratulationsDialog(earnedCoins: earned),
              );

              if (mounted) {
                setState(() {
                  _hasClaimed = true;
                  _coinsEarned = earned;
                });
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.error ?? 'Failed to save game reward')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to save game reward')),
              );
            }
          }
        });
        return Future.value();
      },
    );
  }

  void _playAgain() async {
    if (_originalCoinsEarned > 0 && !_hasClaimed) {
      await showGameRewardChoice(
        context: context,
        featureName: 'Math Quiz',
        description: 'Supercharge your math quiz rewards!',
        baseReward: _originalCoinsEarned,
        quickPlacement: AdPlacement.miniGameCompletion,
        premiumPlacement: AdPlacement.doubleReward,
        icon: Icons.calculate,
        iconBgColor: AppColors.primarySoft,
        iconColor: AppColors.primary,
        premiumGradient: AppColors.primaryGradient,
        quickTextColor: AppColors.primary,
        quickBorderColor: const Color(0xFFE5E7EB),
        onSuccess: (coins) {
          Future.delayed(Duration.zero, () async {
            if (!mounted) return;
            setState(() {
              _watchedRewardedAd = (coins == _originalCoinsEarned * 2);
              _coinsEarned = coins;
            });

            final duration = _gameStartTime != null
                ? DateTime.now().difference(_gameStartTime!).inSeconds
                : 1;

            try {
              final result = await ref.read(gameServiceProvider).submitGameResult(
                gameName: 'math_quiz',
                score: coins,
                durationSeconds: duration.clamp(1, 3600),
                sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
                originalScore: _originalCoinsEarned,
                multiplier: _watchedRewardedAd ? 2 : 1,
              );
              if (result.success || result.queued) {
                final earned = result.coinsEarned > 0 ? result.coinsEarned : coins;
                ref.read(coinProvider.notifier).updateBalance(ref.read(coinProvider) + earned);
                ref.read(dailyCapServiceProvider).addCoins(earned, 'math_quiz');
                
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => CongratulationsDialog(earnedCoins: earned),
                );

                if (mounted) {
                  _startQuizRound();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.error ?? 'Failed to save game reward')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to save game reward')),
                );
              }
            }
          });
          return Future.value();
        },
      );
    } else {
      _startQuizRound();
    }
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
        if (shouldLeave && mounted) {
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
                    if (shouldLeave && context.mounted) {
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
    return Column(
      key: const ValueKey('MENU'),
      children: [
        const Spacer(),
        // Title
        Text(
          'Math Quiz',
          style: GoogleFonts.outfit(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        // Subtitle
        Text(
          isMathBlocked 
              ? 'Daily limit or feature cap reached today.'
              : 'Challenge your brain &\nearn RBX Coins!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: isMathBlocked ? Colors.redAccent : const Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 50),

        // Glowing Big Pulse Play Button
        GestureDetector(
          onTap: isMathBlocked ? null : _startQuizRound,
          child: Column(
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isMathBlocked
                        ? [Colors.grey, Colors.grey.shade400]
                        : [const Color(0xFF6338F9), const Color(0xFF8B64FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMathBlocked
                          ? Colors.grey.withOpacity(0.2)
                          : const Color(0xFF6338F9).withOpacity(0.35),
                      blurRadius: 25,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isMathBlocked ? Icons.lock_clock_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isMathBlocked ? 'Cap Reached' : 'Start Quiz',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isMathBlocked ? Colors.grey : const Color(0xFF181C32),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // --- 2. GAMEPLAY SCREEN ---
  Widget _buildGameplayScreen() {
    return Column(
      key: const ValueKey('PLAYING'),
      children: [
        const Spacer(),
        const SizedBox(height: 10),

        // Giant Rounded Purple Question Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6338F9).withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${_currentQuestion.text} = ?',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 25),

        // 2x2 Grid of Option Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildAnswerButton(0)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildAnswerButton(1)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildAnswerButton(2)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildAnswerButton(3)),
                ],
              ),
            ],
          ),
        ),

        const Spacer(),

        // Bottom Timer Progress Bar & Time text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 16,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEFF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _timerProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6338F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _formatTimerText(),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerButton(int idx) {
    final optValue = _currentQuestion.options[idx];
    final isSelected = _selectedAnswer == idx;
    final isCorrectOption = optValue == _currentQuestion.correctAnswer;

    // Normal State
    Color bgC = const Color(0xFFF1F1FB);
    Color borderC = const Color(0xFFE2E2F5);
    Color textC = const Color(0xFF1E1E2C);

    if (_selectedAnswer != null) {
      if (isCorrectOption) {
        bgC = const Color(0xFFE2FBE9);
        borderC = const Color(0xFF81C784);
        textC = const Color(0xFF1B5E20);
      } else if (isSelected) {
        bgC = const Color(0xFFFFEBEE);
        borderC = const Color(0xFFE57373);
        textC = const Color(0xFFB71C1C);
      }
    }

    return GestureDetector(
      onTap: () => _checkAnswer(idx, optValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 60,
        decoration: BoxDecoration(
          color: bgC,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderC, width: 2.0),
        ),
        alignment: Alignment.center,
        child: Text(
          '$optValue',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: textC,
          ),
        ),
      ),
    );
  }

  // --- 3. GAMEOVER SCREEN ---
  Widget _buildGameOverScreen() {
    final bool didWin = _correctCount >= 5;
    
    return Column(
      key: const ValueKey('GAMEOVER'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),

        // Trophy icon with pop animation
        ScaleTransition(
          scale: _matchPopScale,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: didWin ? const Color(0xFFFDF6E2) : const Color(0xFFEFECFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              didWin ? Icons.emoji_events : Icons.replay,
              color: didWin ? const Color(0xFFFFCC44) : const Color(0xFF6E3AFF),
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Result Header
        Text(
          'Quiz Complete!',
          style: GoogleFonts.outfit(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 12),

        // Stats Summary Subtitle
        Text(
          '$_correctCount/$_totalQuestions Correct',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),

        // Breakdown Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFECFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E2F5)),
            ),
            child: Column(
              children: [
                _buildRewardRow('Correct Answers', '$_correctCount/$_totalQuestions'),
                const SizedBox(height: 8),
                _buildRewardRow('Base Reward', '+$_originalCoinsEarned RBX'),
                if (_coinsEarned > _originalCoinsEarned) ...[
                  const SizedBox(height: 8),
                  _buildRewardRow('Ad Multiplier', '2x'),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFE2E2F5)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF181C32),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.currency_bitcoin,
                            color: Color(0xFFFFB000), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '+$_coinsEarned RBX',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF181C32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Play Again
              GestureDetector(
                onTap: _playAgain,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7A4BFF), Color(0xFF562EE6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF562EE6).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Play Again',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              if (!_hasClaimed) ...[
                const SizedBox(height: 14),

                // Claim Reward
                GestureDetector(
                  onTap: _claimQuizCoins,
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFECFF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        'Claim Reward',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF562EE6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
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
            color: const Color(0xFF6E3AFF),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF131326),
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
        final floatOffset =
            math.sin(_floatController.value * 2 * math.pi) * 12.0;

        return Stack(
          children: [
            // Top Left Division Floater
            Positioned(
              top: 80 + floatOffset,
              left: 30,
              child: _buildDecorativeSymbol(
                  '÷', 48, const Color(0xFF6338F9).withOpacity(0.7)),
            ),
            // Top Center Equal Floater
            Positioned(
              top: 40 - floatOffset,
              right: 140,
              child: _buildDecorativeSymbol(
                  '=', 40, const Color(0xFF8B64FF).withOpacity(0.7)),
            ),
            // Top Right Plus Floater
            Positioned(
              top: 100 + floatOffset,
              right: 40,
              child: _buildDecorativeSymbol(
                  '+', 44, const Color(0xFF6338F9).withOpacity(0.7)),
            ),
            // Bottom Left Plus Floater
            Positioned(
              bottom: 120 + floatOffset,
              left: 45,
              child: _buildDecorativeSymbol(
                  '÷', 46, const Color(0xFF6338F9).withOpacity(0.7)),
            ),
            // Bottom Center Minus Floater
            Positioned(
              bottom: 80 - floatOffset,
              right: 120,
              child: _buildDecorativeSymbol(
                  '=', 38, const Color(0xFF8B64FF).withOpacity(0.7)),
            ),
            // Bottom Right Multiply Floater
            Positioned(
              bottom: 140 + floatOffset,
              right: 50,
              child: _buildDecorativeSymbol(
                  '×', 42, const Color(0xFF6338F9).withOpacity(0.7)),
            ),

            // Drifting Gold Coins (drifting absolute positioned images)
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
              color: color.withOpacity(0.18),
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}
