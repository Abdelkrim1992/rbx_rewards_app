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
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    width: 1.2,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                icon,
                style: TextStyle(
                  fontSize: isSelected ? 14 : 13,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.1,
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFF94A3B8),
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 20,
      constraints: BoxConstraints(minWidth: isSelected ? 24 : 20),
      padding: EdgeInsets.symmetric(
        horizontal: isSelected ? 6.5 : 5.5,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : const Color(0xFFE8EDF2),
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.30),
                width: 1.0,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isSelected ? 10.5 : 9.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          height: 1.15,
          color: isSelected
              ? AppColors.primary
              : const Color(0xFF94A3B8),
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
