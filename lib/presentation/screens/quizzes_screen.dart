import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/ad_models.dart';
import '../../widgets/two_tier_reward_dialog.dart';
import '../../widgets/congratulations_dialog.dart';
import '../../core/utils/reward_helper.dart';
import '../providers/coin_provider.dart';
import '../providers/data_providers.dart';

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

  int _score = 0;
  int _correctCount = 0;
  int _questionIndex = 1;
  final int _totalQuestions = 10;
  int _coinsEarned = 0;

  late QuizQuestion _currentQuestion;
  int? _selectedAnswer;
  bool? _isCorrectAnswer;

  int _secondsLeft = 90;
  Timer? _quizTimer;
  double _timerProgress = 1.0;

  late AnimationController _floatController;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
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
    super.dispose();
  }

  void _startQuizRound(QuizCategory category) {
    _activeCategory = category;
    final shuffled = List<QuizQuestion>.from(category.questions)
      ..shuffle(_random);
    final count = math.min(_totalQuestions, shuffled.length);
    _sessionQuestions = shuffled.take(count).toList();

    setState(() {
      _gameState = 'PLAYING';
      _correctCount = 0;
      _questionIndex = 1;
      _score = 0;
      _coinsEarned = 0;
      _secondsLeft = 90;
      _timerProgress = 1.0;
      _selectedAnswer = null;
      _isCorrectAnswer = null;
      _currentQuestion = _sessionQuestions[0];
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
      _isCorrectAnswer = isCorrect;
    });

    if (isCorrect) {
      _correctCount++;
      _score += 10;
    }

    HapticFeedback.lightImpact();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_questionIndex < _sessionQuestions.length) {
        setState(() {
          _questionIndex++;
          _currentQuestion = _sessionQuestions[_questionIndex - 1];
          _selectedAnswer = null;
          _isCorrectAnswer = null;
        });
      } else {
        _triggerQuizComplete();
      }
    });
  }

  void _triggerQuizComplete() {
    _quizTimer?.cancel();
    final coins = (_correctCount * 3).clamp(0, 30); // 3 coins per correct, max 30 base
    setState(() {
      _coinsEarned = coins;
      _gameState = 'GAMEOVER';
    });
  }

  Future<void> _processQuizClaim(int baseReward, {required VoidCallback onComplete}) async {
    if (baseReward <= 0) {
      onComplete();
      return;
    }

    await showRewardChoice(
       context: context,
       featureName: 'Quiz Reward',
      baseReward: baseReward,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.miniGameCompletion,
      onSuccess: (coins) async {
        await ref.read(coinProvider.notifier).credit(coins, 'quiz');
        onComplete();
      },
      onCancel: () {
        onComplete();
      },
    );
  }

  void _claimQuizCoins() async {
    await _processQuizClaim(_coinsEarned, onComplete: () {
      if (mounted) {
        Navigator.of(context).pop(_coinsEarned);
      }
    });
  }

  void _playAgain() async {
    await _processQuizClaim(_coinsEarned, onComplete: () {
      if (mounted) {
        if (_activeCategory != null) {
          _startQuizRound(_activeCategory!);
        } else {
          _backToMenu();
        }
      }
    });
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
    return PopScope(
      canPop: !isPlaying,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isPlaying) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Quit Quiz?',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: const Color(0xFF131326),
              ),
            ),
            content: Text(
              'Are you sure you want to exit? You will lose unclaimed progress.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF4A4B60),
                height: 1.4,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: _InteractiveCard(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF868A9F),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InteractiveCard(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1744).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Quit',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (shouldLeave == true && mounted) {
          Navigator.of(context).pop();
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
                onTap: () {
                  if (_gameState == 'PLAYING') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        title: Text(
                          'Quit Quiz?',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: const Color(0xFF131326),
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to exit? You will lose unclaimed progress.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF4A4B60),
                            height: 1.4,
                          ),
                        ),
                        actionsPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        actions: [
                          Row(
                            children: [
                              Expanded(
                                child: _InteractiveCard(
                                  onTap: () => Navigator.pop(ctx),
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F1FB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF868A9F),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InteractiveCard(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _backToMenu();
                                  },
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF5252),
                                          Color(0xFFFF1744)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF1744)
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Quit',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
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

  // --- MENU SCREEN ---
  Widget _buildMenuScreen() {
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
            const Spacer(),
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
            Flexible(
              flex: 0,
              child: ListView.separated(
                shrinkWrap: true,
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
            const Spacer(),
          ],
        );
      },
    );
  }

  // --- GAMEPLAY SCREEN ---
  Widget _buildGameplayScreen() {
    return Column(
      key: const ValueKey('PLAYING'),
      children: [
        const Spacer(),
        const SizedBox(height: 10),
        // Question Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0077B6).withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _currentQuestion.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),

        // Answer Options (vertical list)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _currentQuestion.options.length,
            itemBuilder: (ctx, idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAnswerButton(idx),
              );
            },
          ),
        ),

        // Timer bar
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
                        color: const Color(0xFF0077B6),
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
        height: 56,
        decoration: BoxDecoration(
          color: bgC,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderC, width: 2.0),
        ),
        alignment: Alignment.center,
        child: Text(
          optValue,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textC,
          ),
        ),
      ),
    );
  }

  // --- GAMEOVER SCREEN ---
  Widget _buildGameOverScreen() {
    return Column(
      key: const ValueKey('GAMEOVER'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Text(
          'Quiz Complete!',
          style: GoogleFonts.outfit(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '$_correctCount/${_sessionQuestions.length} Correct',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Earned:',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.goldCoin,
              width: 28,
              height: 28,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.monetization_on,
                color: Color(0xFFFFB000),
                size: 28,
              ),
            ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              GestureDetector(
                onTap: _playAgain,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0077B6).withOpacity(0.3),
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
              GestureDetector(
                onTap: _claimQuizCoins,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F4FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Claim Reward',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0077B6),
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
        border: Border.all(color: const Color(0xFFF3F4F6)),
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

