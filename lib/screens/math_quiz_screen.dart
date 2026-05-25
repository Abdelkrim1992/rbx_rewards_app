import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_reward_dialog.dart';
import '../widgets/quit_confirmation_dialog.dart';

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

class MathQuizScreen extends StatefulWidget {
  const MathQuizScreen({super.key});

  @override
  State<MathQuizScreen> createState() => _MathQuizScreenState();
}

class _MathQuizScreenState extends State<MathQuizScreen>
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
  bool _adWatched = false;
  final int _highScore = 0;
  int _userCoins = 0;
  String? _sessionId;
  DateTime? _gameStartTime;
  bool _isQuitting = false;

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

  @override
  void initState() {
    super.initState();
    _loadHighScoreAndCoins();

    // Loop floating animation for floating background elements
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadHighScoreAndCoins() async {
    final appState = context.read<AppState>();
    setState(() {
      _userCoins = appState.coins;
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
    setState(() {
      _gameState = 'PLAYING';
      _correctCount = 0;
      _questionIndex = 1;
      _score = 0;
      _coinsEarned = 0;
      _originalCoinsEarned = 0;
      _adWatched = false;
      _secondsLeft = 60;
      _timerProgress = 1.0;
      _selectedAnswer = null;
      _isCorrectAnswer = null;
    });

    _sessionId = GameService().generateSessionId();
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

      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
          _timerProgress = _secondsLeft / 60.0;
        } else {
          timer.cancel();
          _triggerQuizComplete();
        }
      });
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

    // Z = _correctCount * 50 coins (as seen in screenshot: 8/10 Correct = 400 RBX Coins)
    final coins = _correctCount * 50;

    setState(() {
      _originalCoinsEarned = coins;
      _coinsEarned = coins;
      _gameState = 'GAMEOVER';
    });

    _loadHighScoreAndCoins();
  }

  Future<bool> _syncQuizResult(int finalScore, int duration) async {
    try {
      final result = await GameService().submitGameResult(
        gameName: 'math_quiz',
        score: finalScore,
        durationSeconds: duration.clamp(1, 3600),
        sessionId: _sessionId ?? GameService().generateSessionId(),
        originalScore: _originalCoinsEarned,
        multiplier: _adWatched ? 2 : 1,
      );
      if (!mounted) return false;
      if (result['success'] == true && result['balance'] != null) {
        context
            .read<AppState>()
            .syncBalanceFromServer(result['balance'] as int);
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error'] as String? ?? 'Failed to save game reward',
          ),
        ),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save game reward')),
      );
      debugPrint('Failed to submit quiz result: $e');
      return false;
    }
  }

  void _claimQuizCoins() async {
    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 1;
    final finalScore = _originalCoinsEarned * (_adWatched ? 2 : 1);

    if (!mounted) return;
    final saved = await _syncQuizResult(finalScore, duration);
    if (!saved) return;

    if (mounted) {
      Navigator.of(context).pop(finalScore);
    }
  }

  void _playAgain() async {
    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 1;
    final finalScore = _originalCoinsEarned * (_adWatched ? 2 : 1);

    if (finalScore > 0) {
      if (!mounted) return;
      final saved = await _syncQuizResult(finalScore, duration);
      if (!saved) return;
    }

    if (mounted) {
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
    return Column(
      key: const ValueKey('MENU'),
      mainAxisAlignment: MainAxisAlignment.center,
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
          'Challenge your brain &\nearn RBX Coins!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 50),

        // Glowing Big Pulse Play Button
        GestureDetector(
          onTap: _startQuizRound,
          child: Column(
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6338F9).withOpacity(0.35),
                      blurRadius: 25,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Start Quiz',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF181C32),
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
    return Column(
      key: const ValueKey('GAMEOVER'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        // Quiz Complete Header
        Text(
          'Quiz Complete!',
          style: GoogleFonts.outfit(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 24),

        // Subtitle: X/10 Correct
        Text(
          '$_correctCount/$_totalQuestions Correct',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 12),
        // Earned:
        Text(
          'Earned:',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),

        // Coins Won Display Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.currency_bitcoin,
                color: Color(0xFFFFB000), size: 28),
            const SizedBox(width: 8),
            Text(
              '+$_coinsEarned RBX Coins',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF181C32),
              ),
            ),
          ],
        ),

        const Spacer(),

        // bottom action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Watch Ad for 2x
              if (_coinsEarned > 0 && !_adWatched)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => AdRewardDialog(
                          onRewardGranted: () {
                            setState(() {
                              _coinsEarned = _originalCoinsEarned * 2;
                              _adWatched = true;
                            });
                          },
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8C00), Color(0xFFFFCC44)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFCC44).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle,
                                color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Watch Ad for 2x Coins',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Play Again
              GestureDetector(
                onTap: _playAgain,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6338F9).withOpacity(0.3),
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
              const SizedBox(height: 14),

              // Go to Home
              GestureDetector(
                onTap: _claimQuizCoins,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE7FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Go to Home',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6338F9),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
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
