import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'interactive_button.dart';

/// Modal bottom sheet presented when a user's consecutive day streak is broken.
/// Gives them the option to save their streak by watching a rewarded ad
/// or let it reset to Day 1.
class StreakSaverSheet extends StatelessWidget {
  final int currentStreak;
  final int nextDay;
  final int rewardAmount;
  final VoidCallback onSaveWithAd;
  final VoidCallback onResetStreak;
  final bool isLoading;

  const StreakSaverSheet({
    super.key,
    required this.currentStreak,
    required this.nextDay,
    required this.rewardAmount,
    required this.onSaveWithAd,
    required this.onResetStreak,
    this.isLoading = false,
  });

  static Future<void> show({
    required BuildContext context,
    required int currentStreak,
    required int nextDay,
    required int rewardAmount,
    required VoidCallback onSaveWithAd,
    required VoidCallback onResetStreak,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => StreakSaverSheet(
        currentStreak: currentStreak,
        nextDay: nextDay,
        rewardAmount: rewardAmount,
        onSaveWithAd: onSaveWithAd,
        onResetStreak: onResetStreak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Hero Fire Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF8A00),
                    Color(0xFFE52E71),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE52E71).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Streak at Risk!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF131326),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle explanation
            Text(
              'You missed yesterday! Don\'t lose your $currentStreak-Day Streak and your progress toward the 100 RBX Day 7 Jackpot.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Comparison Cards
            Row(
              children: [
                // Save streak card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF86EFAC),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.shield_rounded,
                              size: 16,
                              color: Color(0xFF16A34A),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SAVE STREAK',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Keep Day $currentStreak',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF14532D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Unlock Day $nextDay (+$rewardAmount)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Reset card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'RESET',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start Over',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Day 1 (+15 RBX)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Save Streak CTA (Rewarded Ad)
            InteractiveButton(
              height: 52,
              borderRadius: 14,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A00), Color(0xFFE52E71)],
              ),
              onTap: isLoading ? null : onSaveWithAd,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Save Streak (Watch Video)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Dismiss / Reset button
            TextButton(
              onPressed: isLoading ? null : onResetStreak,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
              child: const Text(
                'No thanks, start over at Day 1',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
