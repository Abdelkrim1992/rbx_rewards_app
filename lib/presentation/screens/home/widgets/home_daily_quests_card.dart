import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/ad_models.dart';
import '../../../../models/quest_model.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/reward_claim_dialog.dart';
import '../../../../widgets/interactive_button.dart';
import '../../../providers/quest_provider.dart';

class HomeDailyQuestsCard extends ConsumerWidget {
  final bool hasCardWrapper;

  const HomeDailyQuestsCard({
    super.key,
    this.hasCardWrapper = true,
  });

  void _openMasterChest(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RewardClaimDialog(
        title: 'Daily Master Chest',
        subtitle: 'You completed all daily missions! 🎉',
        baseReward: DailyQuestsState.masterChestRewardCoins,
        adPlacement: AdPlacement.doubleReward,
        heroAsset: AppAssets.megaChest,
        onClaimCompleted: (coins) async {
          final isDouble = coins > DailyQuestsState.masterChestRewardCoins;
          await ref.read(questStateProvider.notifier).claimMasterChest(
                multiplier: isDouble ? 2 : 1,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(questStateProvider);

    final content = questsAsync.when(
      data: (state) => _buildBody(context, ref, state),
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );

    if (!hasCardWrapper) {
      return content;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: content,
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DailyQuestsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestsHeader(state: state),
        const SizedBox(height: 14),
        ...state.quests.map((q) => _QuestRow(quest: q)),
        const SizedBox(height: 14),
        _MasterChestBanner(
          state: state,
          onOpenChest: () => _openMasterChest(context, ref),
        ),
      ],
    );
  }
}

class _QuestsHeader extends StatelessWidget {
  final DailyQuestsState state;

  const _QuestsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Daily Missions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: state.areAllCompleted
                ? const Color(0xFFF3F0FF)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${state.completedCount}/${state.quests.length} Done',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: state.areAllCompleted
                  ? AppColors.primary
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}

class _MasterChestBanner extends StatelessWidget {
  final DailyQuestsState state;
  final VoidCallback onOpenChest;

  const _MasterChestBanner({
    required this.state,
    required this.onOpenChest,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isMasterChestClaimed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 6),
            Text(
              'Master Chest Claimed! Resets at midnight UTC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (state.areAllCompleted) {
      return InteractiveButton(
        height: 48,
        borderRadius: 14,
        onTap: onOpenChest,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎁', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'CLAIM MASTER CHEST (+150 RBX)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Text('🎁', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Complete all 3 missions to unlock Daily Master Chest (+150 RBX)!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final DailyQuest quest;
  const _QuestRow({required this.quest});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(quest.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      quest.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: quest.isCompleted
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                        decoration: quest.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      '${quest.currentProgress}/${quest.targetCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: quest.isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: quest.progressRatio,
                    minHeight: 4.5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          quest.isCompleted
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 18,
                )
              : const Icon(
                  Icons.radio_button_unchecked,
                  color: Color(0xFFCBD5E1),
                  size: 18,
                ),
        ],
      ),
    );
  }
}
