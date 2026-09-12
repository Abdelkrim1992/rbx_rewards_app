import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Smart-collapsing Daily Streak Card.
///
/// Automatically collapses into a sleek 44px status pill when claimed for the day,
/// saving vertical screen space while remaining expandable with a single tap.
class HomeDailyStreakCard extends StatefulWidget {
  final int consecutiveDays;
  final bool isDailyClaimed;
  final Duration dailyCooldown;
  final bool isStreakBroken;
  final bool isDailyBlocked;
  final VoidCallback? onClaim;
  final VoidCallback? onSaveStreak;
  final String Function(Duration) formatDuration;
  final bool hasCardWrapper;

  const HomeDailyStreakCard({
    super.key,
    required this.consecutiveDays,
    required this.isDailyClaimed,
    required this.dailyCooldown,
    required this.isStreakBroken,
    required this.isDailyBlocked,
    required this.onClaim,
    required this.onSaveStreak,
    required this.formatDuration,
    this.hasCardWrapper = true,
  });

  @override
  State<HomeDailyStreakCard> createState() => _HomeDailyStreakCardState();
}

class _HomeDailyStreakCardState extends State<HomeDailyStreakCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final cycleStreak = widget.consecutiveDays % 7;
    final int claimedInCycle;
    final int? activeDayToClaim;

    if (widget.isDailyClaimed) {
      claimedInCycle =
          (widget.consecutiveDays > 0 && cycleStreak == 0) ? 7 : cycleStreak;
      activeDayToClaim = null;
    } else {
      claimedInCycle = cycleStreak;
      activeDayToClaim = cycleStreak + 1;
    }

    final activeDayReward = activeDayToClaim == 7
        ? 100
        : (activeDayToClaim != null ? 10 + (activeDayToClaim * 5) : 15);

    // When claimed and not expanded, show the compact status pill
    final isCompact = widget.isDailyClaimed &&
        !widget.isStreakBroken &&
        !_isExpanded;

    final content = AnimatedCrossFade(
      duration: const Duration(milliseconds: 250),
      crossFadeState: isCompact
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: _buildCollapsedPill(claimedInCycle: claimedInCycle),
      secondChild: _buildExpandedBody(
        claimedInCycle: claimedInCycle,
        activeDayToClaim: activeDayToClaim,
        activeDayReward: activeDayReward,
      ),
    );

    if (!widget.hasCardWrapper) {
      return content;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isStreakBroken
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
        child: content,
      ),
    );
  }

  Widget _buildCollapsedPill({required int claimedInCycle}) {
    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9FE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.consecutiveDays}d Active',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Next claim in ${widget.formatDuration(widget.dailyCooldown)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 7-Day Gamified Visual Roadmap Track
            Row(
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                final isDone = dayNum <= claimedInCycle;
                final isJackpot = dayNum == 7;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index == 6 ? 0 : 4),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFFDCFCE7)
                          : (isJackpot ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF86EFAC)
                            : (isJackpot ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Color(0xFF16A34A),
                            )
                          : Text(
                              isJackpot ? '🎁 D7' : 'D$dayNum',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isJackpot
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedBody({
    required int claimedInCycle,
    required int? activeDayToClaim,
    required int activeDayReward,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final dayNum = index + 1;
            final isClaimed = dayNum <= claimedInCycle;
            final isActive = dayNum == activeDayToClaim;

            return _StreakDayItem(
              dayNum: dayNum,
              isClaimed: isClaimed,
              isActive: isActive,
              isStreakBroken: isActive && widget.isStreakBroken,
              onTap: isActive
                  ? (widget.isStreakBroken
                      ? widget.onSaveStreak
                      : widget.onClaim)
                  : null,
            );
          }),
        ),
        const SizedBox(height: 14),
        _buildActionArea(activeDayToClaim, activeDayReward),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Daily Streak Bonus',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF131326),
                letterSpacing: -0.3,
              ),
            ),
            if (widget.consecutiveDays > 0) ...[
              const SizedBox(width: 8),
              _StreakBadge(
                consecutiveDays: widget.consecutiveDays,
                isStreakBroken: widget.isStreakBroken,
              ),
            ],
          ],
        ),
        if (widget.isDailyClaimed && !widget.isStreakBroken)
          GestureDetector(
            onTap: _toggleExpanded,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Collapse',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: Text(
              widget.isStreakBroken
                  ? 'Tap to save streak! 🔥'
                  : 'Keep streak for big rewards!',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    widget.isStreakBroken ? FontWeight.w700 : FontWeight.w500,
                color: widget.isStreakBroken
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF7C8BA0),
                letterSpacing: -0.2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionArea(int? activeDay, int reward) {
    if (widget.isStreakBroken) {
      return _StreakBrokenCTA(onTap: widget.onSaveStreak);
    }

    if (!widget.isDailyBlocked && activeDay != null) {
      return _ClaimActiveCTA(
        activeDay: activeDay,
        reward: reward,
        onTap: widget.onClaim,
      );
    }

    return _ClaimedStatusBanner(
      isDailyClaimed: widget.isDailyClaimed,
      dailyCooldown: widget.dailyCooldown,
      formatDuration: widget.formatDuration,
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int consecutiveDays;
  final bool isStreakBroken;

  const _StreakBadge({
    required this.consecutiveDays,
    required this.isStreakBroken,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isStreakBroken
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isStreakBroken
              ? const Color(0xFFFECACA)
              : const Color(0xFFFFEDD5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isStreakBroken ? '⚠️' : '🔥',
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 3),
          Text(
            isStreakBroken ? 'Broken' : '${consecutiveDays}d',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isStreakBroken
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFC2410C),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBrokenCTA extends StatelessWidget {
  final VoidCallback? onTap;

  const _StreakBrokenCTA({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8A00), Color(0xFFE52E71)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE52E71).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Streak at Risk! Tap to Save with Ad',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimActiveCTA extends StatelessWidget {
  final int activeDay;
  final int reward;
  final VoidCallback? onTap;

  const _ClaimActiveCTA({
    required this.activeDay,
    required this.reward,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Claim Day $activeDay (+$reward RBX)',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimedStatusBanner extends StatelessWidget {
  final bool isDailyClaimed;
  final Duration dailyCooldown;
  final String Function(Duration) formatDuration;

  const _ClaimedStatusBanner({
    required this.isDailyClaimed,
    required this.dailyCooldown,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDailyClaimed
                ? Icons.check_circle_rounded
                : Icons.lock_clock_rounded,
            size: 16,
            color: isDailyClaimed
                ? const Color(0xFF10B981)
                : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            isDailyClaimed
                ? 'Claimed Today • Next in ${formatDuration(dailyCooldown)}'
                : 'Daily Limit Reached Today',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakDayItem extends StatelessWidget {
  final int dayNum;
  final bool isClaimed;
  final bool isActive;
  final bool isStreakBroken;
  final VoidCallback? onTap;

  const _StreakDayItem({
    required this.dayNum,
    required this.isClaimed,
    required this.isActive,
    this.isStreakBroken = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coinReward = dayNum == 7 ? 100 : 10 + (dayNum * 5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItemCircle(),
          const SizedBox(height: 5),
          _buildDayLabel(),
          const SizedBox(height: 2),
          _buildRewardLabel(coinReward),
        ],
      ),
    );
  }

  Widget _buildItemCircle() {
    if (dayNum == 7) {
      if (isActive) {
        return _ActiveJackpotChest(isStreakBroken: isStreakBroken);
      }
      if (isClaimed) {
        return const _ClaimedJackpotChest();
      }
      return const _LockedJackpotChest();
    }

    if (isActive) {
      return _ActiveStreakCoin(isStreakBroken: isStreakBroken);
    }
    if (isClaimed) {
      return const _ClaimedStreakCoin();
    }
    return const _LockedStreakCoin();
  }

  Widget _buildDayLabel() {
    final Color textColor;
    final FontWeight fontWeight;

    if (isStreakBroken && isActive) {
      textColor = const Color(0xFFDC2626);
      fontWeight = FontWeight.w700;
    } else if (isActive) {
      textColor =
          dayNum == 7 ? const Color(0xFFD97706) : const Color(0xFF6D28D9);
      fontWeight = FontWeight.w700;
    } else if (isClaimed) {
      textColor = const Color(0xFF10B981);
      fontWeight = FontWeight.w600;
    } else {
      textColor = const Color(0xFF8C95A6);
      fontWeight = FontWeight.w500;
    }

    return Text(
      'Day $dayNum',
      style: TextStyle(
        fontSize: 10,
        fontWeight: fontWeight,
        color: textColor,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildRewardLabel(int coins) {
    if (dayNum == 7) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFEF3C7)
              : (isClaimed
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '+$coins',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isActive
                ? const Color(0xFFB45309)
                : (isClaimed
                    ? const Color(0xFF059669)
                    : const Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    final Color color;
    if (isActive) {
      color = const Color(0xFF6D28D9);
    } else if (isClaimed) {
      color = const Color(0xFF10B981);
    } else {
      color = const Color(0xFF94A3B8);
    }

    return Text(
      '+$coins',
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _ActiveJackpotChest extends StatelessWidget {
  final bool isStreakBroken;
  const _ActiveJackpotChest({this.isStreakBroken = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isStreakBroken
              ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
              : const [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        boxShadow: [
          BoxShadow(
            color: (isStreakBroken
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFF59E0B))
                .withValues(alpha: 0.55),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isStreakBroken
            ? const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              )
            : Image.asset(
                AppAssets.dailyRewardGift,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.goldRbxCoin,
                  width: 24,
                  height: 24,
                ),
              ),
      ),
    );
  }
}

class _ClaimedJackpotChest extends StatelessWidget {
  const _ClaimedJackpotChest();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFEF3C7),
        border: Border.all(
          color: const Color(0xFFFBBF24),
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AppAssets.dailyRewardGift,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              AppAssets.goldRbxCoin,
              width: 22,
              height: 22,
            ),
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedJackpotChest extends StatelessWidget {
  const _LockedJackpotChest();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF4F5F8),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Center(
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      0.40, 0,
          ]),
          child: Image.asset(
            AppAssets.dailyRewardGift,
            width: 21,
            height: 21,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              AppAssets.goldRbxCoin,
              width: 21,
              height: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveStreakCoin extends StatelessWidget {
  final bool isStreakBroken;
  const _ActiveStreakCoin({this.isStreakBroken = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isStreakBroken
              ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
              : const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        ),
        boxShadow: [
          BoxShadow(
            color: (isStreakBroken
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF7C3AED))
                .withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isStreakBroken
            ? const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              )
            : Image.asset(
                AppAssets.goldRbxCoin,
                width: 25,
                height: 25,
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}

class _ClaimedStreakCoin extends StatelessWidget {
  const _ClaimedStreakCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFFBEB),
        border: Border.all(
          color: const Color(0xFFFCD34D),
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AppAssets.goldRbxCoin,
            width: 23,
            height: 23,
            fit: BoxFit.contain,
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedStreakCoin extends StatelessWidget {
  const _LockedStreakCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF4F5F8),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Center(
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      0.40, 0,
          ]),
          child: Image.asset(
            AppAssets.goldRbxCoin,
            width: 21,
            height: 21,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
