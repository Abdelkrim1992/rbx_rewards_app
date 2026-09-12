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
    this.targetCoins = 20000,
    this.targetTitle = '\$3 Roblox Gift Card',
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _GoalIconBadge(targetTitle: targetTitle),
                const SizedBox(width: 10),
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
                _RedeemButton(isCompleted: remainingCoins == 0),
              ],
            ),
            const SizedBox(height: 8),
            _GoalProgressBar(progress: progress),
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
            : AppAssets.roblox5UsdCard);

    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.asset(
          cardAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFECFDF5),
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

  @override
  Widget build(BuildContext context) {
    final isCompleted = remainingCoins == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                targetTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF131326),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _PercentBadge(percent: percent, isCompleted: isCompleted),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isCompleted
              ? '$coins / $targetCoins RBX • Ready to Claim! 🎉'
              : (percent < 5
                  ? '$coins / $targetCoins RBX • First milestone: 500 RBX 🚀'
                  : '$coins / $targetCoins RBX • $remainingCoins left'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w600,
            color: isCompleted
                ? const Color(0xFF16A34A)
                : const Color(0xFF868A9F),
          ),
        ),
      ],
    );
  }
}

class _PercentBadge extends StatelessWidget {
  final int percent;
  final bool isCompleted;

  const _PercentBadge({
    required this.percent,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isCompleted
              ? const Color(0xFF15803D)
              : const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _RedeemButton extends StatelessWidget {
  final bool isCompleted;

  const _RedeemButton({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
            SizedBox(width: 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View Goal',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 2),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _GoalProgressBar extends StatelessWidget {
  final double progress;

  const _GoalProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 4.5,
        backgroundColor: const Color(0xFFF1F5F9),
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}
