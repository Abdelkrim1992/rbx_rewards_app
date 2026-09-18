import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_cached_image.dart';
import '../../../../widgets/interactive_button.dart';
import '../models/game_item_data.dart';

class GamePreviewSheet extends StatelessWidget {
  final GameItemData game;
  final int earnedToday;
  final int totalCap;
  final int remainingCap;
  final int? rewardAmount;
  final VoidCallback onStartGame;

  const GamePreviewSheet({
    super.key,
    required this.game,
    required this.earnedToday,
    required this.totalCap,
    required this.remainingCap,
    this.rewardAmount,
    required this.onStartGame,
  });

  static Future<void> show({
    required BuildContext context,
    required GameItemData game,
    required int earnedToday,
    required int totalCap,
    required int remainingCap,
    int? rewardAmount,
    required VoidCallback onStartGame,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GamePreviewSheet(
        game: game,
        earnedToday: earnedToday,
        totalCap: totalCap,
        remainingCap: remainingCap,
        rewardAmount: rewardAmount,
        onStartGame: onStartGame,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppLayout.screenPadding,
        12,
        AppLayout.screenPadding,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DragHandle(),
          const SizedBox(height: 16),
          _SheetHeader(game: game),
          const SizedBox(height: 18),
          _StatsRow(
            game: game,
            earnedToday: earnedToday,
            totalCap: totalCap,
          ),
          const SizedBox(height: 18),
          _RulesSection(rules: game.rules, themeColor: game.themeColor),
          const SizedBox(height: 20),
          _PlayCtaButton(
            game: game,
            remainingCap: remainingCap,
            rewardAmount: rewardAmount,
            onStartGame: onStartGame,
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final GameItemData game;

  const _SheetHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: game.softBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppCachedImage(
              imageUrl: game.imageUrl,
              fit: BoxFit.cover,
              errorWidget: Icon(
                Icons.sports_esports_rounded,
                size: 28,
                color: game.themeColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      game.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: game.badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: game.badgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      game.badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: game.badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                game.subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final GameItemData game;
  final int earnedToday;
  final int totalCap;

  const _StatsRow({
    required this.game,
    required this.earnedToday,
    required this.totalCap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCap > 0 ? (earnedToday / totalCap).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Expanded(
          child: _DailyQuotaCard(
            earnedToday: earnedToday,
            totalCap: totalCap,
            progress: progress,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: game.getPersonalBest != null
              ? _PersonalBestCard(game: game)
              : _SessionSpecsCard(game: game),
        ),
      ],
    );
  }
}

class _DailyQuotaCard extends StatelessWidget {
  final int earnedToday;
  final int totalCap;
  final double progress;

  const _DailyQuotaCard({
    required this.earnedToday,
    required this.totalCap,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY QUOTA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$earnedToday / $totalCap',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 3),
              const Text(
                'RBX',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalBestCard extends StatelessWidget {
  final GameItemData game;

  const _PersonalBestCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: game.getPersonalBest!(),
      builder: (context, snapshot) {
        final best = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PERSONAL BEST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('🏆 ', style: TextStyle(fontSize: 13)),
                  Text(
                    '$best ${game.personalBestUnit}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                best > 0 ? 'High record' : 'No games yet',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionSpecsCard extends StatelessWidget {
  final GameItemData game;

  const _SessionSpecsCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DURATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.purple),
              const SizedBox(width: 4),
              Text(
                game.avgTime,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Difficulty: ${game.difficulty}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesSection extends StatelessWidget {
  final List<String> rules;
  final Color themeColor;

  const _RulesSection({
    required this.rules,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How to Play & Earn',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        ...rules.map(
          (rule) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 11,
                    color: themeColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayCtaButton extends StatelessWidget {
  final GameItemData game;
  final int remainingCap;
  final int? rewardAmount;
  final VoidCallback onStartGame;

  const _PlayCtaButton({
    required this.game,
    required this.remainingCap,
    this.rewardAmount,
    required this.onStartGame,
  });

  @override
  Widget build(BuildContext context) {
    final isCapped = remainingCap <= 0;
    final rewardText = game.category != GameCategory.instant
        ? 'Play Now • Up to +${rewardAmount ?? 31} RBX'
        : 'Play Now • +${rewardAmount ?? 48} RBX';

    return InteractiveButton(
      height: 52,
      borderRadius: 16,
      icon: isCapped ? Icons.lock_clock_rounded : Icons.play_arrow_rounded,
      iconSize: 22,
      iconSpacing: 8,
      gradient: isCapped ? null : AppColors.primaryGradient,
      color: isCapped ? const Color(0xFF94A3B8) : null,
      text: isCapped ? 'Daily Limit Reached' : rewardText,
      fontSize: 14.5,
      fontWeight: FontWeight.w800,
      onTap: () {
        HapticFeedback.mediumImpact();
        onStartGame();
      },
    );
  }
}
