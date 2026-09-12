import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/game_prefs.dart';
import '../providers/providers.dart';
import '../providers/user_provider.dart';

// Game Screens
import 'leaderboard_screen.dart';
import 'tap_tap_game_screen.dart';
import 'flappy_jump_game_screen.dart';
import 'math_quiz_screen.dart';
import 'quizzes_screen.dart';
import 'flip_card_game_screen.dart';
import 'scratch_card_screen.dart';

// Modular Games Components
import 'games/models/game_item_data.dart';
import 'games/widgets/games_spotlight_banner.dart';
import 'games/widgets/games_category_chips.dart';
import 'games/widgets/game_card_enhanced.dart';
import 'games/widgets/game_preview_sheet.dart';

class GamesScreen extends ConsumerStatefulWidget {
  final Function(int) onNavTap;

  const GamesScreen({super.key, required this.onNavTap});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  GameCategory _selectedCategory = GameCategory.all;
  bool _isRefreshing = false;

  late final List<GameItemData> _allGames;

  @override
  void initState() {
    super.initState();
    _allGames = _buildGamesList();
  }

  List<GameItemData> _buildGamesList() {
    return [
      GameItemData(
        id: 'flappy_jump',
        title: 'Flappy Jump',
        subtitle: 'Fly through obstacles & grab coins',
        capKey: 'flappy_jump',
        imageUrl: AppAssets.flappyJumpGame,
        category: GameCategory.arcade,
        themeColor: const Color(0xFFF59E0B),
        softBgColor: const Color(0xFFFFF3E3),
        badgeText: '🔥 HOT',
        badgeColor: const Color(0xFFF59E0B),
        difficulty: 'Medium',
        avgTime: '1 min',
        description:
            'Tap to stay airborne, dodge moving obstacles, and collect gold coins before crashing.',
        rules: const [
          'Tap the screen to keep your character flying.',
          'Avoid touching barriers or hitting the ground.',
          'Coins earned are added directly to your RBX balance.',
        ],
        getPersonalBest: GamePrefs.getFlappyBestScore,
        personalBestUnit: 'pts',
        isSpotlight: true,
        screenBuilder: (ctx, onNav) => const FlappyJumpGameScreen(),
      ),
      GameItemData(
        id: 'tap_tap',
        title: 'Tap Tap',
        subtitle: '15-second fast reaction speed dash',
        capKey: 'tap_tap',
        imageUrl: AppAssets.tapTapGame,
        category: GameCategory.arcade,
        themeColor: const Color(0xFF2563EB),
        softBgColor: const Color(0xFFEAF3FF),
        badgeText: '⚡ 15s DASH',
        badgeColor: const Color(0xFF2563EB),
        difficulty: 'Easy',
        avgTime: '15s',
        description:
            'Tap target coins as fast as humanly possible before the 15-second timer runs out.',
        rules: const [
          'Tap the moving coin target rapidly to build your score.',
          'Maintain high combos to unlock multiplier bonuses.',
          'Earn instant coins with no waiting time.',
        ],
        getPersonalBest: () => GamePrefs.getBestScore('tap_tap'),
        personalBestUnit: 'hits',
        screenBuilder: (ctx, onNav) => const TapTapGameScreen(),
      ),
      GameItemData(
        id: 'math_quiz',
        title: 'Math Quiz',
        subtitle: 'Speed mental math brain challenge',
        capKey: 'math_quiz',
        imageUrl: AppAssets.quizMasterGame,
        category: GameCategory.brain,
        themeColor: const Color(0xFF10B981),
        softBgColor: const Color(0xFFE3F8EB),
        badgeText: '🧠 BRAIN IQ',
        badgeColor: const Color(0xFF10B981),
        difficulty: 'Medium',
        avgTime: '45s',
        description:
            'Test your mental math agility with rapid questions and earn coins for every correct answer.',
        rules: const [
          'Pick the right answer from 4 choices before time runs out.',
          'Each correct answer increases your RBX coin prize.',
          'Finish all questions to receive maximum bonus coins.',
        ],
        getPersonalBest: () => GamePrefs.getBestScore('math_quiz'),
        personalBestUnit: 'score',
        screenBuilder: (ctx, onNav) => const MathQuizScreen(),
      ),
      GameItemData(
        id: 'quizzes',
        title: 'Roblox Trivia',
        subtitle: 'Test your Roblox gaming knowledge',
        capKey: 'quizzes',
        imageUrl: AppAssets.quizMasterQuickActions,
        category: GameCategory.brain,
        themeColor: const Color(0xFF8B5CF6),
        softBgColor: const Color(0xFFF5F3FF),
        badgeText: '⭐ TRIVIA',
        badgeColor: const Color(0xFF8B5CF6),
        difficulty: 'Easy',
        avgTime: '1 min',
        description:
            'Answer multiple-choice Roblox trivia questions and prove how much you know about the platform.',
        rules: const [
          'Answer 10 questions across various difficulty levels.',
          'Get at least 7 correct answers to pass the challenge.',
          'Optionally double your final reward with a bonus video.',
        ],
        getPersonalBest: () => GamePrefs.getBestScore('quizzes'),
        personalBestUnit: 'correct',
        screenBuilder: (ctx, onNav) => const QuizzesScreen(),
      ),
      GameItemData(
        id: 'flip_card',
        title: 'Flip Cards',
        subtitle: 'Memory matching card puzzle',
        capKey: 'flip_card',
        imageUrl: AppAssets.memoryMatchGame,
        category: GameCategory.brain,
        themeColor: const Color(0xFFEC4899),
        softBgColor: const Color(0xFFFFE8F0),
        badgeText: '🎯 MEMORY',
        badgeColor: const Color(0xFFEC4899),
        difficulty: 'Medium',
        avgTime: '1 min',
        description:
            'Memorize card locations and flip matching pairs in the fewest attempts possible.',
        rules: const [
          'Flip two cards at a time to find identical pairs.',
          'Memorize revealed cards to minimize total moves.',
          'Win coins based on completion speed and accuracy.',
        ],
        getPersonalBest: () => GamePrefs.getBestScore('flip_card'),
        personalBestUnit: 'pairs',
        screenBuilder: (ctx, onNav) => const FlipCardGameScreen(),
      ),
      GameItemData(
        id: 'scratch',
        title: 'Scratch Card',
        subtitle: 'Instant win lucky prize card',
        capKey: 'scratch',
        imageUrl: AppAssets.dailyRewardImage,
        category: GameCategory.instant,
        themeColor: AppColors.purple,
        softBgColor: const Color(0xFFF1EDFF),
        badgeText: '🎁 INSTANT',
        badgeColor: AppColors.purple,
        difficulty: 'Easy',
        avgTime: '10s',
        description:
            'Scratch away the golden ticket surface to instantly reveal coins and surprise multipliers.',
        rules: const [
          'Rub your finger over the card to reveal the hidden reward.',
          'Get 3 free tickets every single day.',
          'Unlock additional bonus scratch tickets by watching ads.',
        ],
        getPersonalBest: () => GamePrefs.getScratchesRemaining(),
        personalBestUnit: 'free left',
        screenBuilder: (ctx, onNav) => ScratchCardScreen(
          onBack: () => Navigator.of(ctx).pop(),
        ),
      ),
    ];
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      ref.invalidate(userProfileStreamProvider);
      final capService = ref.read(dailyCapServiceProvider);
      await capService.load();
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      debugPrint('Error refreshing games: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _launchGame(GameItemData game) {
    final capService = ref.read(dailyCapServiceProvider);
    final remaining = capService.getRemainingCap(game.capKey);

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Daily limit reached for ${game.title}! Resets at midnight.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.purple,
        ),
      );
      return;
    }

    Navigator.of(context)
        .push<int>(
      MaterialPageRoute(
        builder: (ctx) => game.screenBuilder(ctx, widget.onNavTap),
      ),
    )
        .then((coinsEarned) {
      if (coinsEarned != null && coinsEarned > 0) {
        ref.invalidate(userProfileStreamProvider);
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showGamePreview(GameItemData game) {
    final capService = ref.read(dailyCapServiceProvider);
    final earned = capService.getEarnedToday(game.capKey);
    final total = capService.getCategoryCap(game.capKey);
    final remaining = capService.getRemainingCap(game.capKey);

    GamePreviewSheet.show(
      context: context,
      game: game,
      earnedToday: earned,
      totalCap: total,
      remainingCap: remaining,
      onStartGame: () {
        Navigator.of(context).pop();
        _launchGame(game);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final capService = ref.watch(dailyCapServiceProvider);

    // Compute category counts
    final categoryCounts = <GameCategory, int>{
      GameCategory.all: _allGames.length,
      GameCategory.arcade:
          _allGames.where((g) => g.category == GameCategory.arcade).length,
      GameCategory.brain:
          _allGames.where((g) => g.category == GameCategory.brain).length,
      GameCategory.instant:
          _allGames.where((g) => g.category == GameCategory.instant).length,
    };

    // Filter games by selected category
    final filteredGames = _selectedCategory == GameCategory.all
        ? _allGames
        : _allGames.where((g) => g.category == _selectedCategory).toList();

    // Spotlight game is Flappy Jump (or first spotlight game)
    final spotlightGame = _allGames.firstWhere(
      (g) => g.isSpotlight,
      orElse: () => _allGames.first,
    );
    final spotlightEarned = capService.getEarnedToday(spotlightGame.capKey);
    final spotlightTotal = capService.getCategoryCap(spotlightGame.capKey);
    final spotlightRemaining = capService.getRemainingCap(spotlightGame.capKey);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshableScrollView(
                padding: const EdgeInsets.only(top: 2, bottom: 100),
                onRefresh: _handleRefresh,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: widget.onNavTap),

                    // Section Heading with Leaderboard Action
                    RbxScreenTitle(
                      title: 'Play & Earn',
                      subtitle: 'Complete mini games to collect RBX coins',
                      actionText: '🏆 Leaderboard',
                      onActionTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LeaderboardScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    // 1. Spotlight Hero Card
                    GamesSpotlightBanner(
                      game: spotlightGame,
                      earnedToday: spotlightEarned,
                      totalCap: spotlightTotal,
                      remainingCap: spotlightRemaining,
                      onPlayTap: () => _launchGame(spotlightGame),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // 2. Category Filter Chips
                    GamesCategoryChips(
                      selectedCategory: _selectedCategory,
                      categoryCounts: categoryCounts,
                      onCategorySelected: (category) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),

                    // 3. 2-Column Enhanced Games Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: filteredGames.length,
                        itemBuilder: (ctx, i) {
                          final game = filteredGames[i];
                          final earned = capService.getEarnedToday(game.capKey);
                          final total = capService.getCategoryCap(game.capKey);
                          final remaining = capService.getRemainingCap(game.capKey);

                          return GameCardEnhanced(
                            game: game,
                            earnedToday: earned,
                            totalCap: total,
                            remainingCap: remaining,
                            onTap: () => _showGamePreview(game),
                            onQuickPlay: () => _launchGame(game),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // 4. More Games Coming Soon Teaser Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primarySoft,
                              AppColors.primarySoft.withValues(alpha: 0.55),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.purple,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'More Games Coming Soon ✨',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'New arcade titles unlock with app updates',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.purple,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RbxBottomNav(
        currentIndex: 1,
        onTap: widget.onNavTap,
      ),
    );
  }
}
