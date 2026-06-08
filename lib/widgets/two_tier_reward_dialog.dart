import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Two-tier reward dialog that offers users a choice:
/// - Quick Claim (lower reward + rewarded interstitial ad)
/// - Premium Claim (higher reward + rewarded ad)
///
/// Design emphasizes the premium option to maximize user selection (70-80% target).
class TwoTierRewardDialog extends StatefulWidget {
  final String title;
  final String description;
  final int quickReward;
  final int premiumReward;
  final Future<void> Function() onQuickClaim;
  final Future<void> Function() onPremiumClaim;
  final String quickLabel;
  final String premiumLabel;

  const TwoTierRewardDialog({
    super.key,
    required this.title,
    required this.description,
    required this.quickReward,
    required this.premiumReward,
    required this.onQuickClaim,
    required this.onPremiumClaim,
    this.quickLabel = 'Quick Claim',
    this.premiumLabel = 'Watch a video for more reward',
  });

  @override
  State<TwoTierRewardDialog> createState() => _TwoTierRewardDialogState();
}

class _TwoTierRewardDialogState extends State<TwoTierRewardDialog> {
  bool _isLoading = false;
  String _loadingMessage = '';

  Future<void> _handleClaim(bool isPremium) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = '';
    });

    try {
      if (isPremium) {
        await widget.onPremiumClaim();
      } else {
        await widget.onQuickClaim();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_giftcard,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF131326),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              _isLoading ? _loadingMessage : widget.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF868A9F),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 40),
            ] else ...[
              // Premium Option (emphasized with visual hierarchy)
              _buildPremiumOption(context),
              const SizedBox(height: 12),

              // Quick Option (smaller, less emphasized)
              _buildQuickOption(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOption(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleClaim(true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.premiumLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.goldRbxCoin,
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${widget.premiumReward} RBX',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleClaim(false),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.goldRbxCoin,
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.monetization_on,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '+${widget.quickReward} RBX',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // const SizedBox(width: 8),
            // Flexible(
            //   child: Text(
            //     '• $quickLabel',
            //     style: const TextStyle(
            //       fontSize: 14,
            //       fontWeight: FontWeight.w600,
            //       color: Color(0xFF6B7280),
            //     ),
            //     overflow: TextOverflow.ellipsis,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
