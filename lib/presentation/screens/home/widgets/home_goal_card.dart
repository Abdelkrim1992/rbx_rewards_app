import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Compact, high-contrast goal progress strip.
///
/// Anchors the user's primary redemption goal directly below the winners ticker
/// with minimal vertical footprint (~54px) to preserve above-the-fold real estate.
class HomeGoalCard extends StatefulWidget {
  final int coins;
  final VoidCallback onRedeemTap;
  final int targetCoins;
  final String targetTitle;

  const HomeGoalCard({
    super.key,
    required this.coins,
    required this.onRedeemTap,
    this.targetCoins = 4500,
    this.targetTitle = r'$0.50 Starter Robux (40 R$)',
  });

  @override
  State<HomeGoalCard> createState() => _HomeGoalCardState();
}

class _HomeGoalCardState extends State<HomeGoalCard> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.98);

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onRedeemTap();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    final progress = (widget.coins / widget.targetCoins).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();
    final remainingCoins =
        (widget.targetCoins - widget.coins).clamp(0, widget.targetCoins);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          child: _GoalCardContent(
            targetTitle: widget.targetTitle,
            coins: widget.coins,
            targetCoins: widget.targetCoins,
            remainingCoins: remainingCoins,
            percent: percent,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _GoalCardContent extends StatelessWidget {
  final String targetTitle;
  final int coins;
  final int targetCoins;
  final int remainingCoins;
  final int percent;
  final double progress;

  const _GoalCardContent({
    required this.targetTitle,
    required this.coins,
    required this.targetCoins,
    required this.remainingCoins,
    required this.percent,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = remainingCoins == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _GoalIconBadge(targetTitle: targetTitle),
                const SizedBox(width: 12),
                Expanded(
                  child: _GoalProgressInfo(
                    targetTitle: targetTitle,
                    coins: coins,
                    targetCoins: targetCoins,
                    remainingCoins: remainingCoins,
                    percent: percent,
                  ),
                ),
                const SizedBox(width: 8),
                _GoalActionBadge(
                  percent: percent,
                  isCompleted: isCompleted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _GoalProgressBar(
              progress: progress,
              isCompleted: isCompleted,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalIconBadge extends StatelessWidget {
  final String targetTitle;

  const _GoalIconBadge({required this.targetTitle});

  @override
  Widget build(BuildContext context) {
    final cardAsset = targetTitle.contains('10')
        ? AppAssets.roblox10UsdCard
        : (targetTitle.contains('3')
            ? AppAssets.roblox3UsdCard
            : (targetTitle.contains('Starter') || targetTitle.contains('40')
                ? AppAssets.roblox3UsdCard
                : AppAssets.roblox5UsdCard));

    return Container(
      width: 42,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          cardAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFEEF2FF),
            child: const Center(
              child: Icon(
                Icons.card_giftcard_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalProgressInfo extends StatelessWidget {
  final String targetTitle;
  final int coins;
  final int targetCoins;
  final int remainingCoins;
  final int percent;

  const _GoalProgressInfo({
    required this.targetTitle,
    required this.coins,
    required this.targetCoins,
    required this.remainingCoins,
    required this.percent,
  });

  String _formatCoins(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _cleanTitle(String raw) {
    if (raw.startsWith(r'$0.50 Starter Robux')) {
      return 'Starter Robux (40 R\$)';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = remainingCoins == 0;
    final formattedRemaining = _formatCoins(remainingCoins);
    final displayTitle = _cleanTitle(targetTitle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isCompleted
              ? 'Ready to claim! 🎉'
              : '$formattedRemaining coins left',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w600,
            color: isCompleted
                ? const Color(0xFF16A34A)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _GoalActionBadge extends StatelessWidget {
  final int percent;
  final bool isCompleted;

  const _GoalActionBadge({
    required this.percent,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3310B981),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Claim',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 3),
            Icon(
              Icons.celebration_rounded,
              size: 13,
              color: Colors.white,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}

class _GoalProgressBar extends StatelessWidget {
  final double progress;
  final bool isCompleted;

  const _GoalProgressBar({
    required this.progress,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        return Container(
          height: 5.5,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: animatedProgress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? const [Color(0xFF34D399), Color(0xFF10B981)]
                      : const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      },
    );
  }
}
