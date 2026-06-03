import 'dart:math';
import 'package:flutter/material.dart';

/// Lucky bonus popup offering a random reward for watching an optional ad.
class LuckyBonusDialog extends StatelessWidget {
  final int rewardAmount;
  final VoidCallback onClaim;
  final VoidCallback onLater;

  const LuckyBonusDialog({
    super.key,
    required this.rewardAmount,
    required this.onClaim,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🍀',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lucky Bonus!',
              style: TextStyle(
                color: Color(0xFF4A3B00),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watch a video for $rewardAmount coins! ✨',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5C4A00), fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onClaim();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3B00),
                  foregroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Claim Reward — Watch Ad',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onLater();
                },
                child: const Text(
                  'Maybe later',
                  style: TextStyle(color: Color(0xFF5C4A00)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onClaim,
    required VoidCallback onLater,
  }) {
    final reward = 100 + Random().nextInt(401); // 100-500
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LuckyBonusDialog(
        rewardAmount: reward,
        onClaim: onClaim,
        onLater: onLater,
      ),
    );
  }
}
