import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/ad_models.dart';
import '../../models/reward_config.dart';
import '../../core/utils/game_reward_helper.dart';
import '../../core/utils/reward_helper.dart';
import '../../widgets/game_prefs.dart';
import '../../widgets/interactive_button.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../widgets/feature_top_bar.dart';
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
    final maxBase = ref.read(dailyCapServiceProvider).getBaseReward('quiz');
    final coins = RewardConfig.calculateMathQuizBaseReward(
      _correctCount,
      _sessionQuestions.length,
      maxBase: maxBase,
      timeLeftSeconds: _secondsLeft,
    );
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

    final premiumReward = _originalCoinsEarned * 4;

    await showRewardChoice(
      context: context,
      featureName: 'Quiz Master Reward',
      baseReward: _originalCoinsEarned,
      premiumReward: premiumReward,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.quizMasterGame,
      multiplier: 4,
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
        if (shouldLeave && context.mounted) {
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
    String headerText = 'Quizzes';
    if (_gameState == 'PLAYING') {
      headerText = 'Question $_questionIndex/${_sessionQuestions.length}';
    } else if (_gameState == 'GAMEOVER') {
      headerText = 'Quiz Results';
    }

    return FeatureTopBar(
      title: headerText,
      onBack: () async {
        if (_gameState == 'PLAYING') {
          final shouldLeave = await showQuitConfirmationDialog(
            context,
            title: 'Quit Quiz?',
            message:
                'Are you sure you want to exit? You will lose unclaimed progress.',
          );
          if (shouldLeave && context.mounted) {
            _backToMenu();
          }
        } else {
          Navigator.of(context).pop();
        }
      },
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
    final maxBase = ref.watch(dailyCapServiceProvider).getBaseReward('quiz');

    return asyncQuizzes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load quizzes: $e')),
      data: (data) {
        if (_categories.isEmpty && data.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _parseCategories(data));
            }
          });
        }

        return Column(
          key: const ValueKey('MENU'),
          children: [
            const SizedBox(height: 12),
            _buildMenuRewardPill(maxBase, isQuizBlocked),
            const SizedBox(height: 14),
            Expanded(
              child: isQuizBlocked
                  ? _buildCapReachedView()
                  : _buildCategoryList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuRewardPill(int maxBase, bool isQuizBlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isQuizBlocked ? const Color(0xFFF1F5F9) : const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isQuizBlocked ? const Color(0xFFE2E8F0) : const Color(0xFFDDD6FE),
          ),
        ),
        child: Row(
          children: [
            Image.asset(AppAssets.goldRbxCoin, width: 22, height: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isQuizBlocked
                    ? 'Quiz limit or daily cap reached today'
                    : 'Earn up to +$maxBase RBX per quiz (4X with Boost)',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isQuizBlocked ? const Color(0xFF64748B) : const Color(0xFF6D28D9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapReachedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, size: 36, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Text(
            'Daily Limit Reached',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF181C32),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Come back tomorrow or play other arcade mini-games!',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final cat = _categories[i];
        return _QuizCategoryItem(
          category: cat,
          onStart: () => _startQuizRound(cat),
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

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Column(
                key: const ValueKey('PLAYING'),
                children: [
                  const SizedBox(height: 6),
                  _buildGameplayTopHUD(),
                  const Spacer(),
                  _buildQuestionCard(useSmallStyle),
                  SizedBox(height: useSmallStyle ? 12 : 20),
                  _buildAnswerOptionsList(useSmallStyle),
                  const Spacer(),
                  _buildGameplayBottomTimer(useSmallStyle),
                ],
              ),
            ),
          ),
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
                  '$_questionIndex / ${_sessionQuestions.length}',
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

  Widget _buildQuestionCard(bool useSmallStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: useSmallStyle ? 20 : 32,
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF6338F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF8B64FF).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6338F9).withValues(alpha: 0.3),
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
            fontSize: useSmallStyle ? 18 : 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerOptionsList(bool useSmallStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_currentQuestion.options.length, (idx) {
          return Padding(
            padding: EdgeInsets.only(bottom: useSmallStyle ? 8 : 10),
            child: _buildAnswerButton(idx, useSmallStyle),
          );
        }),
      ),
    );
  }

  Widget _buildAnswerButton(int idx, bool useSmallStyle) {
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
      onTap: () => _checkAnswer(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: useSmallStyle ? 48 : 56,
        decoration: BoxDecoration(
          color: bgC,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderC, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: borderC.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          optValue,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: useSmallStyle ? 14 : 16,
            fontWeight: FontWeight.w800,
            color: textC,
          ),
        ),
      ),
    );
  }

  Widget _buildGameplayBottomTimer(bool useSmallStyle) {
    final isLowTime = _secondsLeft <= 15;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: useSmallStyle ? 12 : 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 12,
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
            _formatTimerText(),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // --- GAMEOVER SCREEN ---
  Widget _buildGameOverScreen() {
    final bool didWin = _originalCoinsEarned > 0;
    final tierName = !didWin
        ? 'Target Not Reached'
        : (_originalCoinsEarned <= 3
            ? 'Bronze Mind 🥉'
            : (_originalCoinsEarned <= 7 ? 'Silver Scholar 🥈' : 'Gold Genius 🥇'));

    final accuracy = _sessionQuestions.isNotEmpty
        ? ((_correctCount / _sessionQuestions.length) * 100).round()
        : 0;

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
                  _buildStarRating(accuracy),
                  SizedBox(height: useSmallStyle ? 6 : 10),
                  _buildGameOverTitle(didWin, accuracy, useSmallStyle),
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

  Widget _buildStarRating(int accuracy) {
    int stars = 0;
    if (accuracy >= 80) {
      stars = 3;
    } else if (accuracy >= 50) {
      stars = 2;
    } else if (accuracy >= 20) {
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

  Widget _buildGameOverTitle(bool didWin, int accuracy, bool useSmallStyle) {
    final headerTitle = !didWin
        ? 'Quiz Incomplete'
        : (_originalCoinsEarned >= 12
            ? 'Genius Score! 🥇'
            : (_originalCoinsEarned >= 7 ? 'Great Job! 🥈' : 'Good Effort! 🥉'));

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
          '$_correctCount/${_sessionQuestions.length} Correct • $accuracy% Accuracy',
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
            _buildRewardRow('Correct Answers', '$_correctCount/${_sessionQuestions.length}'),
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
            SizedBox(height: useSmallStyle ? 10 : 12),
            _buildChooseTopicButton(useSmallStyle),
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
      onTap: _isProcessingAd ? null : _claimQuizCoins,
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

  Widget _buildChooseTopicButton(bool useSmallStyle) {
    return InteractiveButton(
      height: useSmallStyle ? 44 : 50,
      onTap: _isProcessingAd ? null : _backToMenu,
      backgroundColor: AppColors.primarySoft,
      border: Border.all(color: AppColors.cardBorder, width: 1.5),
      textColor: AppColors.purple,
      text: 'Choose Another Topic',
      fontSize: useSmallStyle ? 13 : 15,
      fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: category.bgColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: category.bgColor.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: category.bgColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: category.bgColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                category.icon,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF181C32),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onStart();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6338F9).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 2),
                  Text(
                    'PLAY',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

