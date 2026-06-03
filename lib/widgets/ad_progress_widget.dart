import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/ad_state.dart';
import '../theme/app_theme.dart';

/// Displays daily ad progress with a gradient bar and milestone badges.
class AdProgressWidget extends StatelessWidget {
  const AdProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdState>(
      builder: (context, adState, child) {
        final watched = adState.dailyAdsWatched;
        final total = 25;
        final progress = (watched / total).clamp(0.0, 1.0);
        final isComplete = watched >= total;

        return GestureDetector(
          onTap: () => _showDetailedProgress(context, adState),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6B46C1).withOpacity(0.15),
                  const Color(0xFFD4AF37).withOpacity(0.15),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6B46C1).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isComplete
                          ? '🎉 $watched/$total ads watched!'
                          : '$watched/$total ads watched today',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (isComplete)
                      const Text('🎉', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete
                            ? const Color(0xFFD4AF37)
                            : const Color(0xFF6B46C1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MilestoneBadge(at: 5, watched: watched),
                    _MilestoneBadge(at: 10, watched: watched),
                    _MilestoneBadge(at: 15, watched: watched),
                    _MilestoneBadge(at: 20, watched: watched),
                    _MilestoneBadge(at: 25, watched: watched),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailedProgress(BuildContext context, AdState adState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ad Progress',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(
              label: 'Forced ads',
              value: '${adState.trackingData.dailyForcedAds}/15',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Optional ads',
              value: '${adState.trackingData.dailyOptionalAds}/10',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Total today',
              value: '${adState.dailyAdsWatched}/25',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  final int at;
  final int watched;

  const _MilestoneBadge({required this.at, required this.watched});

  @override
  Widget build(BuildContext context) {
    final achieved = watched >= at;
    return Text(
      achieved ? '🎖️' : '○',
      style: TextStyle(
        fontSize: achieved ? 16 : 12,
        color: achieved ? const Color(0xFFD4AF37) : Colors.white38,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
