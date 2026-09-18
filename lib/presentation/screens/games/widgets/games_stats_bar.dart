import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../../providers/providers.dart';

class GamesStatsBar extends ConsumerWidget {
  const GamesStatsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capService = ref.watch(dailyCapServiceProvider);
    
    // Sum total coins earned in mini games today
    final gamesCoins = capService.getEarnedToday('flappy_jump') +
        capService.getEarnedToday('tap_tap') +
        capService.getEarnedToday('flip_card') +
        capService.getEarnedToday('math_quiz') +
        capService.getEarnedToday('quizzes');

    // Count how many different games were played today
    int gamesPlayedCount = 0;
    for (final key in ['flappy_jump', 'tap_tap', 'flip_card', 'math_quiz', 'quizzes']) {
      if (capService.getEarnedToday(key) > 0) gamesPlayedCount++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primarySoft.withValues(alpha: 0.95),
              const Color(0xFFF3E8FF).withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            _buildStatItem(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFF6B00),
              title: 'ARCADE',
              subtitle: 'Daily Fun',
            ),
            _buildDivider(),
            _buildStatItem(
              icon: Icons.sports_esports_rounded,
              iconColor: AppColors.purple,
              title: '$gamesPlayedCount / 5 PLAYED',
              subtitle: 'Active Today',
            ),
            _buildDivider(),
            _buildStatItem(
              icon: Icons.monetization_on_rounded,
              iconColor: const Color(0xFFFFB000),
              title: '+$gamesCoins RBX',
              subtitle: 'Won Today',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 28,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.cardBorder.withValues(alpha: 0.7),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
