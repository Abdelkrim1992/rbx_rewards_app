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
import '../state/ad_state.dart';
import '../models/ad_models.dart';

class FlipCardGameScreen extends StatefulWidget {
  const FlipCardGameScreen({super.key});

  @override
  State<FlipCardGameScreen> createState() => _FlipCardGameScreenState();
}

class _FlipCardGameScreenState extends State<FlipCardGameScreen>
    with TickerProviderStateMixin {
  // Game States: 'MENU', 'PLAYING', 'GAMEOVER'
  String _gameState = 'MENU';

  // Game Metrics
  int _matchesFound = 0;
  final int _totalPairs = 8;
  int _moves = 0;
  int _coinsEarned = 0;
  int _originalCoinsEarned = 0;
  bool _adWatched = false;
  int _userCoins = 0;
  int _comboStreak = 0;
  int _maxCombo = 0;
  String? _sessionId;
  DateTime? _gameStartTime;
  static int _claimCount = 0;

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
    _loadHighScoreAndCoins();

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
    _gameTimer?.cancel();
    _particleTimer?.cancel();
    _floatController.dispose();
    _matchPopController.dispose();
    super.dispose();
  }

  Future<void> _loadHighScoreAndCoins() async {
    final appState = context.read<AppState>();
    setState(() {
      _userCoins = appState.coins;
    });
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
      _adWatched = false;
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

    _sessionId = GameService().generateSessionId();
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

    // Scoring: base 50 per match + time bonus + combo bonus
    int baseCoins = _matchesFound * 50;
    int timeBonus = (_secondsLeft > 0) ? (_secondsLeft * 2) : 0;
    int comboBonus = _maxCombo >= 3 ? (_maxCombo * 25) : 0;
    int total = baseCoins + timeBonus + comboBonus;

    // Score = matches * 100 + time bonus
    int score = _matchesFound * 100 + _secondsLeft;

    setState(() {
      _originalCoinsEarned = total;
      _coinsEarned = total;
      _gameState = 'GAMEOVER';
    });

    _loadHighScoreAndCoins();

    // Show interstitial before the result popup appears
    _claimCount++;
    if (_claimCount % 3 == 0 && mounted) {
      await context.read<AdState>().showInterstitialAfterClaim(AdPlacement.dailyReward);
    }
    if (!mounted) return;

    _matchPopController.reset();
    _matchPopController.forward();
  }

  void _claimCoins() async {
    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 1;
    final finalScore = _originalCoinsEarned * (_adWatched ? 2 : 1);

    if (finalScore > 0) {
      if (!mounted) return;
      try {
        final result = await GameService().submitGameResult(
          gameName: 'flip_card',
          score: finalScore,
          durationSeconds: duration.clamp(1, 3600),
          sessionId: _sessionId ?? GameService().generateSessionId(),
          originalScore: _originalCoinsEarned,
          multiplier: _adWatched ? 2 : 1,
        );
        if (!mounted) return;
        if (result['success'] == true && result['balance'] != null) {
          context
              .read<AppState>()
              .syncBalanceFromServer(result['balance'] as int);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error'] as String? ?? 'Failed to save game reward',
              ),
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save game reward')),
        );
        debugPrint('Failed to submit flip card result: $e');
        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pop(finalScore);
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
      canPop: !isPlaying,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isPlaying) return;
        final shouldLeave = await showQuitConfirmationDialog(
          context,
          title: 'Quit Game?',
          message:
              'Are you sure you want to exit? You will lose unclaimed progress.',
        );
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
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
                          'Quit Game?',
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
                                    Navigator.pop(context);
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

  // --- 1. MENU SCREEN ---
  Widget _buildMenuScreen() {
    return Column(
      key: const ValueKey('MENU'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        // Title
        Text(
          'Flip Cards',
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
          'Match pairs to earn\nRBX Coins!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),

        // Mini preview cards
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniPreviewCard('?', false),
            const SizedBox(width: 12),
            _buildMiniPreviewCard('💎', true),
            const SizedBox(width: 12),
            _buildMiniPreviewCard('💎', true),
            const SizedBox(width: 12),
            _buildMiniPreviewCard('?', false),
          ],
        ),

        const SizedBox(height: 50),

        // Glowing Big Pulse Play Button
        GestureDetector(
          onTap: _startGame,
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
                'Start Game',
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

  Widget _buildMiniPreviewCard(String text, bool isRevealed) {
    return Container(
      width: 52,
      height: 68,
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
              ? const Color(0xFF6338F9).withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6338F9).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isRevealed ? 24 : 20,
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

        // Stats row: Moves + Combo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildStatPill(Icons.touch_app, 'Moves', '$_moves'),
              const SizedBox(width: 12),
              _buildStatPill(Icons.bolt, 'Combo', '${_comboStreak}x'),
              const Spacer(),
              // Timer pill
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _secondsLeft <= 15
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFF1F1FB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _secondsLeft <= 15
                        ? const Color(0xFFE57373)
                        : const Color(0xFFE2E2F5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _secondsLeft <= 15
                          ? const Color(0xFFE57373)
                          : const Color(0xFF6338F9),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimerText(),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _secondsLeft <= 15
                            ? const Color(0xFFB71C1C)
                            : const Color(0xFF131326),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount: _cards.length,
              itemBuilder: (ctx, i) {
                return _buildGameCard(i);
              },
            ),
          ),
        ),

        // Bottom Timer Progress Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                        color: _secondsLeft <= 15
                            ? const Color(0xFFE57373)
                            : const Color(0xFF6338F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$_matchesFound/$_totalPairs',
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: showFace
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF6338F9), Color(0xFF8B64FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: showFace
              ? (card.isMatched ? const Color(0xFFE8F5E9) : Colors.white)
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: card.isMatched
                ? const Color(0xFF81C784)
                : (showFace
                    ? const Color(0xFF6338F9).withOpacity(0.3)
                    : Colors.transparent),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: card.isMatched
                  ? const Color(0xFF81C784).withOpacity(0.25)
                  : const Color(0xFF6338F9).withOpacity(showFace ? 0.12 : 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: showFace
                ? Text(
                    card.symbol,
                    key: ValueKey('face_$index'),
                    style: const TextStyle(fontSize: 32),
                  )
                : Container(
                    key: ValueKey('back_$index'),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          fontSize: 18,
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
    final bool didWin = _matchesFound >= _totalPairs;
    final int baseCoins = _matchesFound * 50;
    final int timeBonus = (_secondsLeft > 0) ? (_secondsLeft * 2) : 0;
    final int comboBonus = _maxCombo >= 3 ? (_maxCombo * 25) : 0;

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
              color: didWin ? const Color(0xFFFDF6E2) : const Color(0xFFF1F1FB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              didWin ? Icons.emoji_events : Icons.replay,
              color: didWin ? const Color(0xFFFFCC44) : const Color(0xFF6338F9),
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Result Header
        Text(
          didWin ? 'All Matched!' : 'Time\'s Up!',
          style: GoogleFonts.outfit(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 12),

        // Stats
        Text(
          '$_matchesFound/$_totalPairs Pairs  •  $_moves Moves',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),

        if (_maxCombo >= 2) ...[
          const SizedBox(height: 6),
          Text(
            'Best Combo: ${_maxCombo}x',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6338F9),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Breakdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1FB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E2F5)),
            ),
            child: Column(
              children: [
                _buildRewardRow('Matches', '+$baseCoins'),
                if (timeBonus > 0) ...[
                  const SizedBox(height: 8),
                  _buildRewardRow('Time Bonus', '+$timeBonus'),
                ],
                if (comboBonus > 0) ...[
                  const SizedBox(height: 8),
                  _buildRewardRow('Combo Bonus', '+$comboBonus'),
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
              // Watch Ad for 2x
              if (_coinsEarned > 0 && !_adWatched && context.watch<AdState>().canShowOptionalAd)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GestureDetector(
                    onTap: () async {
                      final adState = context.read<AdState>();
                      await adState.showInterstitialAfterClaim(AdPlacement.dailyReward);
                      adState.recordOptionalAdWatched();
                      if (!mounted) return;
                      setState(() {
                        _coinsEarned = _originalCoinsEarned * 2;
                        _adWatched = true;
                      });
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
                onTap: _startGame,
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
                onTap: _claimCoins,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE7FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Claim & Go Home',
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
        final floatOffset =
            math.sin(_floatController.value * 2 * math.pi) * 12.0;

        return Stack(
          children: [
            Positioned(
              top: 80 + floatOffset,
              left: 30,
              child: _buildDecorativeSymbol(
                  '🃏', 48, const Color(0xFF6338F9).withOpacity(0.7)),
            ),
            Positioned(
              top: 40 - floatOffset,
              right: 140,
              child: _buildDecorativeSymbol(
                  '✨', 40, const Color(0xFF8B64FF).withOpacity(0.7)),
            ),
            Positioned(
              top: 100 + floatOffset,
              right: 40,
              child: _buildDecorativeSymbol(
                  '🎴', 44, const Color(0xFF6338F9).withOpacity(0.7)),
            ),
            Positioned(
              bottom: 120 + floatOffset,
              left: 45,
              child: _buildDecorativeSymbol(
                  '🃏', 46, const Color(0xFF6338F9).withOpacity(0.7)),
            ),
            Positioned(
              bottom: 80 - floatOffset,
              right: 120,
              child: _buildDecorativeSymbol(
                  '✨', 38, const Color(0xFF8B64FF).withOpacity(0.7)),
            ),
            Positioned(
              bottom: 140 + floatOffset,
              right: 50,
              child: _buildDecorativeSymbol(
                  '🎴', 42, const Color(0xFF6338F9).withOpacity(0.7)),
            ),
            // Drifting Gold Coins
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
              color: color.withOpacity(0.18),
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
