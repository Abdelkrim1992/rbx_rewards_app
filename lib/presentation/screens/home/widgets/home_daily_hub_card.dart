import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../../providers/quest_provider.dart';
import 'home_daily_quests_card.dart';
import 'home_daily_streak_card.dart';

/// Unified Daily Retention Hub.
///
/// Combines the 7-day Daily Streak and Daily Missions into a single tabbed card,
/// reducing vertical clutter while retaining gamification badges and quick switching.
class HomeDailyHubCard extends ConsumerStatefulWidget {
  final int consecutiveDays;
  final bool isDailyClaimed;
  final Duration dailyCooldown;
  final bool isStreakBroken;
  final bool isDailyBlocked;
  final VoidCallback? onClaim;
  final VoidCallback? onSaveStreak;
  final String Function(Duration) formatDuration;

  const HomeDailyHubCard({
    super.key,
    required this.consecutiveDays,
    required this.isDailyClaimed,
    required this.dailyCooldown,
    required this.isStreakBroken,
    required this.isDailyBlocked,
    required this.onClaim,
    required this.onSaveStreak,
    required this.formatDuration,
  });

  @override
  ConsumerState<HomeDailyHubCard> createState() => _HomeDailyHubCardState();
}

class _HomeDailyHubCardState extends ConsumerState<HomeDailyHubCard> {
  int _selectedTabIndex = 0;

  void _onTabSelected(int index) {
    if (_selectedTabIndex != index) {
      setState(() => _selectedTabIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questsAsync = ref.watch(questStateProvider);
    final questsState = questsAsync.valueOrNull;

    final missionsBadge = questsState != null
        ? '${questsState.completedCount}/${questsState.quests.length}'
        : null;

    final hasChestReady =
        questsState != null &&
        questsState.areAllCompleted &&
        !questsState.isMasterChestClaimed;

    final hasStreakReady = !widget.isDailyBlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isStreakBroken && _selectedTabIndex == 0
                ? const Color(0xFFFECACA)
                : AppColors.cardBorder,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DailyHubTabBar(
              selectedIndex: _selectedTabIndex,
              consecutiveDays: widget.consecutiveDays,
              missionsBadge: missionsBadge,
              hasStreakReady: hasStreakReady,
              hasChestReady: hasChestReady,
              onTabSelected: _onTabSelected,
            ),
            const SizedBox(height: 14),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _selectedTabIndex == 0
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: HomeDailyStreakCard(
                consecutiveDays: widget.consecutiveDays,
                isDailyClaimed: widget.isDailyClaimed,
                dailyCooldown: widget.dailyCooldown,
                isStreakBroken: widget.isStreakBroken,
                isDailyBlocked: widget.isDailyBlocked,
                onClaim: widget.onClaim,
                onSaveStreak: widget.onSaveStreak,
                formatDuration: widget.formatDuration,
                hasCardWrapper: false,
              ),
              secondChild: const HomeDailyQuestsCard(hasCardWrapper: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyHubTabBar extends StatelessWidget {
  final int selectedIndex;
  final int consecutiveDays;
  final String? missionsBadge;
  final bool hasStreakReady;
  final bool hasChestReady;
  final ValueChanged<int> onTabSelected;

  const _DailyHubTabBar({
    required this.selectedIndex,
    required this.consecutiveDays,
    required this.missionsBadge,
    required this.hasStreakReady,
    required this.hasChestReady,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Row(
        children: [
          _TabPillItem(
            title: 'Daily Streak',
            icon: '🔥',
            badgeText: consecutiveDays > 0 ? '${consecutiveDays}d' : null,
            hasActionAlert: hasStreakReady,
            isSelected: selectedIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(width: 4),
          _TabPillItem(
            title: 'Missions',
            icon: '🎯',
            badgeText: missionsBadge,
            hasActionAlert: hasChestReady,
            isSelected: selectedIndex == 1,
            onTap: () => onTabSelected(1),
          ),
        ],
      ),
    );
  }
}

class _TabPillItem extends StatelessWidget {
  final String title;
  final String icon;
  final String? badgeText;
  final bool hasActionAlert;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPillItem({
    required this.title,
    required this.icon,
    this.badgeText,
    this.hasActionAlert = false,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isSelected
                ? Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.7),
                    width: 1.0,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFF64748B),
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 5),
                _TabBadge(text: badgeText!, isSelected: isSelected),
              ],
              if (hasActionAlert) ...[
                const SizedBox(width: 4),
                const _AlertDot(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  final String text;
  final bool isSelected;

  const _TabBadge({required this.text, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primarySoft
            : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: isSelected
              ? AppColors.primary
              : const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _AlertDot extends StatelessWidget {
  const _AlertDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        shape: BoxShape.circle,
      ),
    );
  }
}
