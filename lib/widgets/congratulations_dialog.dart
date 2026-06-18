import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'interactive_button.dart';

/// A shared congratulations popup used across all reward flows.
/// Matches the style of the spin screen congratulations dialog.
class CongratulationsDialog extends StatelessWidget {
  final int earnedCoins;

  const CongratulationsDialog({super.key, required this.earnedCoins});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF131326),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have earned',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF868A9F),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.goldRbxCoin,
                    width: 28,
                    height: 28,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on,
                      color: Color(0xFFFFCC44),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '+$earnedCoins RBX',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            InteractiveButton(
              text: 'Done',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
