import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/interactive_button.dart';
import '../../../providers/coin_provider.dart';
import '../../../providers/mega_chest_provider.dart';

class HomeMegaChestCard extends ConsumerStatefulWidget {
  final VoidCallback onClaimTriggered;

  const HomeMegaChestCard({super.key, required this.onClaimTriggered});

  @override
  ConsumerState<HomeMegaChestCard> createState() => _HomeMegaChestCardState();
}

class _HomeMegaChestCardState extends ConsumerState<HomeMegaChestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _showChestInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppAssets.megaChest,
                width: 90,
                height: 90,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.card_giftcard,
                  size: 80,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mega Chest',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF131326),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Earn 10,000 Coins from mini-games, quizzes, scratch cards, and chests to unlock the Mega Chest and claim an extra 1,000 RBX Coins!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF868A9F),
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              InteractiveButton(
                text: 'Got It',
                height: 48,
                borderRadius: 16,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinBalance = ref.watch(coinProvider);
    var lastClaimedMilestone = ref.watch(megaChestMilestoneProvider);

    if (coinBalance < lastClaimedMilestone * 10000) {
      final newMilestone = (coinBalance / 10000).floor();
      lastClaimedMilestone = newMilestone;
      Future.microtask(() {
        ref
            .read(megaChestMilestoneProvider.notifier)
            .setMilestone(newMilestone);
      });
    }

    final nextMilestoneLimit = (lastClaimedMilestone + 1) * 10000;
    final isReadyToClaim = coinBalance >= nextMilestoneLimit;

    if (isReadyToClaim) {
      if (!_shakeController.isAnimating) {
        _shakeController.repeat();
      }
    } else {
      if (_shakeController.isAnimating) {
        _shakeController.stop();
        _shakeController.reset();
      }
    }

    final progressCoins = isReadyToClaim
        ? 10000
        : (coinBalance - (lastClaimedMilestone * 10000)).clamp(0, 10000);
    final progressPercent = progressCoins / 10000.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.98),
        onTapUp: (_) {
          setState(() => _scale = 1.0);
          if (isReadyToClaim) {
            widget.onClaimTriggered();
          } else {
            _showChestInfoDialog(context);
          }
        },
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.cardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isReadyToClaim
                      ? AppColors.purple.withValues(alpha: 0.1)
                      : const Color(0x0A000000),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isReadyToClaim
                                ? 'Mega Chest Ready! 🎁'
                                : 'Mega Chest Progress',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isReadyToClaim
                                  ? AppColors.purple
                                  : const Color(0xFF131326),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progressPercent,
                                color: AppColors.purple,
                                backgroundColor: const Color(0xFFE9EAF5),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$progressCoins/10k',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF131326),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Right side shaking chest
                Container(
                  width: 50,
                  height: 50,
                  decoration: isReadyToClaim
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.purple.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: isReadyToClaim ? _shakeAnimation.value : 0.0,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      AppAssets.megaChest,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.card_giftcard,
                        size: 40,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
