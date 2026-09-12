import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/ad_models.dart';
import '../../core/utils/game_reward_helper.dart';
import '../../core/utils/reward_helper.dart';
import '../../widgets/game_prefs.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../providers/coin_provider.dart';
import '../providers/data_providers.dart';
import '../providers/providers.dart';

class QuizQuestion {
  final String text;
  final String correctAnswer;
  final List<String> options;

  QuizQuestion({
    required this.text,
    required this.correctAnswer,
    required this.options,
  });
}

class QuizCategory {
  final String id;
  final String title;
  final String description;
  final String icon;
  final Color bgColor;
  final List<QuizQuestion> questions;

  QuizCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.bgColor,
    required this.questions,
  });
}

class QuizzesScreen extends ConsumerStatefulWidget {
  const QuizzesScreen({super.key});

  @override
  ConsumerState<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends ConsumerState<QuizzesScreen>
    with TickerProviderStateMixin {
  String _gameState = 'MENU';

  int _correctCount = 0;
  int _questionIndex = 1;
  final int _totalQuestions = 10;
  int _coinsEarned = 0;
  int _originalCoinsEarned = 0;
  bool _hasClaimed = false;
  bool _isProcessingPlayAgain = false;
  bool _isProcessingClaim = false;

  bool get _isProcessingAd => _isProcessingPlayAgain || _isProcessingClaim;

  late QuizQuestion _currentQuestion;
  int? _selectedAnswer;

  int _secondsLeft = 90;
  Timer? _quizTimer;
  double _timerProgress = 1.0;

  late AnimationController _floatController;
  final math.Random _random = math.Random();

  // Scale pop animation for results screen
  late AnimationController _matchPopController;
  late Animation<double> _matchPopScale;

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

  // Categories
  List<QuizCategory> _categories = [];
  late List<QuizQuestion> _sessionQuestions;
  QuizCategory? _activeCategory;

  void _parseCategories(List<Map<String, dynamic>> data) {
    _categories = data.map((cat) {
      final qs = (cat['questions'] as List?)?.map((q) {
            return QuizQuestion(
              text: q['text'] ?? '',
              correctAnswer: q['correctAnswer'] ?? '',
              options: List<String>.from(q['options'] ?? []),
            );
          }).toList() ??
          [];
      
      // Parse hex color if needed
      Color parsedColor = const Color(0xFF9B5CFF);
      if (cat['bgColor'] != null) {
        String hex = cat['bgColor'].toString().replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        parsedColor = Color(int.parse(hex, radix: 16));
      }

      return QuizCategory(
        id: cat['id'] ?? '',
        title: cat['title'] ?? '',
        description: cat['description'] ?? '',
        icon: cat['icon'] ?? '🧠',
        bgColor: parsedColor,
        questions: qs,
      );
    }).toList();
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _floatController.dispose();
    _matchPopController.dispose();
    super.dispose();
  }

  void _startQuizRound(QuizCategory category) {
    final isQuizBlocked = ref.read(dailyCapServiceProvider).isCapReachedFor('quiz') || ref.read(dailyCapServiceProvider).isFeaturesCapReached;
    if (isQuizBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily quiz limit or feature cap reached today.'),
          backgroundColor: AppColors.purple,
        ),
      );
      return;
    }
    _activeCategory = category;
    final shuffled = List<QuizQuestion>.from(category.questions)
      ..shuffle(_random);
    final count = math.min(_totalQuestions, shuffled.length);
    _sessionQuestions = shuffled.take(count).toList();

    setState(() {
      _gameState = 'PLAYING';
      _correctCount = 0;
      _questionIndex = 1;
      _coinsEarned = 0;
      _originalCoinsEarned = 0;
      _secondsLeft = 90;
      _timerProgress = 1.0;
      _selectedAnswer = null;
      _currentQuestion = _sessionQuestions[0];
      _hasClaimed = false;
      _isProcessingPlayAgain = false;
      _isProcessingClaim = false;
    });

    _startSessionTimer();
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
          _timerProgress = _secondsLeft / 90.0;
        });
      } else {
        timer.cancel();
        _triggerQuizComplete();
      }
    });
  }

  void _checkAnswer(int optIdx) {
    if (_selectedAnswer != null) return;

    final selected = _currentQuestion.options[optIdx];
    final isCorrect = selected == _currentQuestion.correctAnswer;

    if (isCorrect) {
      SystemSound.play(SystemSoundType.click);
      Future.delayed(const Duration(milliseconds: 70), () {
        SystemSound.play(SystemSoundType.click);
      });
    } else {
      HapticFeedback.vibrate();
    }

    setState(() {
      _selectedAnswer = optIdx;
    });

    if (isCorrect) {
      _correctCount++;
    }

    HapticFeedback.lightImpact();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_questionIndex < _sessionQuestions.length) {
        setState(() {
          _questionIndex++;
          _currentQuestion = _sessionQuestions[_questionIndex - 1];
          _selectedAnswer = null;
        });
      } else {
        _triggerQuizComplete();
      }
    });
  }

  void _triggerQuizComplete() {
    _quizTimer?.cancel();
    final coins = (_correctCount * 2).clamp(0, 20); // 2 coins per correct, max 20 base
    setState(() {
      _originalCoinsEarned = coins;
      _coinsEarned = coins;
      _gameState = 'GAMEOVER';
    });
    _matchPopController.reset();
    _matchPopController.forward();
    ref.read(adServiceProvider).preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
  }

  void _claimQuizCoins() async {
    if (_originalCoinsEarned <= 0 || _hasClaimed || _isProcessingClaim) {
      if (_hasClaimed && mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isProcessingClaim = true;
    });

    await GamePrefs.incrementGamePlayCount('quizzes');

    if (!mounted) return;

    await showRewardChoice(
      context: context,
      featureName: 'Quiz Master Reward',
      baseReward: _originalCoinsEarned,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.quizMasterGame,
      onSuccess: (coins) async {
        try {
          await ref.read(coinProvider.notifier).credit(coins, 'quiz');
          if (mounted) {
            setState(() {
              _hasClaimed = true;
              _coinsEarned = coins;
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save quiz reward')),
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

  void _playAgain() async {
    if (_isProcessingAd) return;
    setState(() {
      _isProcessingPlayAgain = true;
    });

    if (!_hasClaimed && _originalCoinsEarned > 0) {
      try {
        await ref.read(coinProvider.notifier).credit(_originalCoinsEarned, 'quiz');
      } catch (_) {}
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
          if (_activeCategory != null) {
            _startQuizRound(_activeCategory!);
          } else {
            _backToMenu();
          }
        }
      },
    );
  }

  void _backToMenu() {
    setState(() {
      _gameState = 'MENU';
      _activeCategory = null;
    });
  }

  String _formatTimerText() {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _gameState == 'PLAYING';
    final capService = ref.watch(dailyCapServiceProvider);
    final isQuizCapReached = capService.isCapReachedFor('quiz');
    final isFeaturesCapReached = capService.isFeaturesCapReached;
    final isQuizBlocked = isQuizCapReached || isFeaturesCapReached;

    return PopScope(
      canPop: !isPlaying,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isPlaying) return;
        final shouldLeave = await showQuitConfirmationDialog(
          context,
          title: 'Quit Quiz?',
          message: 'Are you sure you want to exit? You will lose unclaimed progress.',
        );
        if (shouldLeave && mounted) {
          _backToMenu();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildScreenHeader(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStateView(isQuizBlocked),
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
      headerText = 'Question $_questionIndex/${_sessionQuestions.length}';
    } else if (_gameState == 'GAMEOVER') {
      headerText = 'Quiz Results';
    } else {
      headerText = 'Quizzes';
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
                          'Are you sure you want to exit? You will lose unclaimed progress.',
                    );
                    if (shouldLeave && mounted) {
                      _backToMenu();
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

  Widget _buildCurrentStateView(bool isQuizBlocked) {
    switch (_gameState) {
      case 'PLAYING':
        return _buildGameplayScreen();
      case 'GAMEOVER':
        return _buildGameOverScreen();
      case 'MENU':
      default:
        return _buildMenuScreen(isQuizBlocked);
    }
  }

  // --- MENU SCREEN ---
  Widget _buildMenuScreen(bool isQuizBlocked) {
    final asyncQuizzes = ref.watch(quizzesProvider);
    
    return asyncQuizzes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load quizzes: $e')),
      data: (data) {
        if (_categories.isEmpty && data.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _parseCategories(data);
              });
            }
          });
        }
        
        return Column(
          key: const ValueKey('MENU'),
          children: [
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Quizzes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isQuizBlocked
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_clock, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            'Daily Limit Reached',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You have reached the quiz daily limit.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (ctx, i) {
                        final cat = _categories[i];
                        return _QuizCategoryItem(
                          category: cat,
                          onStart: () => _startQuizRound(cat),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // --- GAMEPLAY SCREEN ---
  Widget _buildGameplayScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final useSmallStyle = screenHeight < 680;

        // Dynamic sizes
        final cardHeight = useSmallStyle ? 160.0 : 230.0;
        final cardPadding = useSmallStyle ? 16.0 : 28.0;
        final spacingBetween = useSmallStyle ? 12.0 : 24.0;
        final timerPadding = useSmallStyle ? 12.0 : 24.0;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                key: const ValueKey('PLAYING'),
                children: [
                  const Spacer(),
                  SizedBox(height: useSmallStyle ? 4 : 10),
                  // Question Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      height: cardHeight,
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(useSmallStyle ? 24 : 32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6338F9).withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        child: Text(
                          _currentQuestion.text,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: useSmallStyle ? 18 : 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacingBetween),

                  // Answer Options (vertical list)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: List.generate(_currentQuestion.options.length, (idx) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: useSmallStyle ? 8 : 12),
                          child: _buildAnswerButton(idx, useSmallStyle),
                        );
                      }),
                    ),
                  ),

                  const Spacer(),

                  // Timer bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: timerPadding),
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnswerButton(int idx, bool useSmallStyle) {
    final optValue = _currentQuestion.options[idx];
    final isSelected = _selectedAnswer == idx;
    final isCorrectOption = optValue == _currentQuestion.correctAnswer;

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
      onTap: () => _checkAnswer(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: useSmallStyle ? 46 : 56,
        decoration: BoxDecoration(
          color: bgC,
          borderRadius: BorderRadius.circular(useSmallStyle ? 24 : 28),
          border: Border.all(color: borderC, width: 2.0),
        ),
        alignment: Alignment.center,
        child: Text(
          optValue,
          style: GoogleFonts.outfit(
            fontSize: useSmallStyle ? 15 : 18,
            fontWeight: FontWeight.w800,
            color: textC,
          ),
        ),
      ),
    );
  }

  // --- GAMEOVER SCREEN ---
  Widget _buildGameOverScreen() {
    final bool didWin = _correctCount >= 5;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final useSmallStyle = screenHeight < 680;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                key: const ValueKey('GAMEOVER'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  SizedBox(height: useSmallStyle ? 12 : 24),
                  
                  // Trophy icon with pop animation
                  ScaleTransition(
                    scale: _matchPopScale,
                    child: Container(
                      width: useSmallStyle ? 70 : 90,
                      height: useSmallStyle ? 70 : 90,
                      decoration: BoxDecoration(
                        color: didWin ? const Color(0xFFFDF6E2) : const Color(0xFFEFECFF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        didWin ? Icons.emoji_events : Icons.replay,
                        color: didWin ? const Color(0xFFFFCC44) : const Color(0xFF6E3AFF),
                        size: useSmallStyle ? 38 : 50,
                      ),
                    ),
                  ),
                  SizedBox(height: useSmallStyle ? 12 : 20),

                  // Result Header
                  Text(
                    'Quiz Complete!',
                    style: GoogleFonts.outfit(
                      fontSize: useSmallStyle ? 30 : 42,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF181C32),
                    ),
                  ),
                  SizedBox(height: useSmallStyle ? 6 : 12),

                  // Stats Summary Subtitle
                  Text(
                    '$_correctCount/${_sessionQuestions.length} Correct',
                    style: GoogleFonts.inter(
                      fontSize: useSmallStyle ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: useSmallStyle ? 14 : 24),

                  // Breakdown Card
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: useSmallStyle ? 24 : 40),
                    child: Container(
                      padding: EdgeInsets.all(useSmallStyle ? 14 : 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFECFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E2F5)),
                      ),
                      child: Column(
                        children: [
                          _buildRewardRow('Correct Answers', '$_correctCount/${_sessionQuestions.length}'),
                          const SizedBox(height: 8),
                          _buildRewardRow('Base Reward', '+$_originalCoinsEarned RBX'),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: useSmallStyle ? 8 : 10),
                            child: const Divider(color: Color(0xFFE2E2F5)),
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
                  SizedBox(height: useSmallStyle ? 16 : 24),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Play Again
                        GestureDetector(
                          onTap: _isProcessingAd ? null : _playAgain,
                          child: Container(
                            width: double.infinity,
                            height: useSmallStyle ? 50 : 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7A4BFF), Color(0xFF562EE6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(useSmallStyle ? 25 : 30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF562EE6).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isProcessingPlayAgain
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Play Again',
                                      style: GoogleFonts.outfit(
                                        fontSize: useSmallStyle ? 16 : 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (!_hasClaimed) ...[
                          SizedBox(height: useSmallStyle ? 10 : 14),

                          // Claim Reward
                          GestureDetector(
                            onTap: _isProcessingAd ? null : _claimQuizCoins,
                            child: Container(
                              width: double.infinity,
                              height: useSmallStyle ? 50 : 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFECFF),
                                borderRadius: BorderRadius.circular(useSmallStyle ? 25 : 30),
                              ),
                              child: Center(
                                child: _isProcessingClaim
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF562EE6),
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Claim Reward',
                                        style: GoogleFonts.outfit(
                                          fontSize: useSmallStyle ? 16 : 18,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF562EE6),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: useSmallStyle ? 16 : 30),
                      ],
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
}

class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InteractiveCard({required this.child, this.onTap});

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        if (widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

class _QuizCategoryItem extends StatelessWidget {
  final QuizCategory category;
  final VoidCallback onStart;

  const _QuizCategoryItem({
    required this.category,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
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
          // Icon
          Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: category.bgColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: category.bgColor.withOpacity(0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Start Button
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onStart,
                  child: Container(
                    width: 75,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x446035EE),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Start Quiz',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
    );
  }
}

