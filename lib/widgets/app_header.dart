import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/coin_provider.dart';
import '../presentation/providers/user_provider.dart';
import '../theme/app_theme.dart';

class RbxAppHeader extends ConsumerWidget {
  final ValueChanged<int>? onNavTap;

  const RbxAppHeader({super.key, this.onNavTap});

  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 100000) {
      return '${(coins / 1000).toStringAsFixed(0)}K';
    }
    return coins.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final coins = ref.watch(coinProvider);
    final profilePhotoUrl = userProfile.profilePhotoUrl;

    return Padding(
      padding: const EdgeInsets.only(
        left: 13,
        right: AppLayout.screenPadding,
        top: 15,
        bottom: 15,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            AppAssets.rbxLogo,
            width: 120,
            height: 46,
            fit: BoxFit.contain,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live Coin Balance Badge (Tap to View Rewards)
              GestureDetector(
                onTap: () => onNavTap?.call(2), // Index 2 is Rewards
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.only(left: 8, right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AppAssets.goldCoin,
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.monetization_on,
                          color: Color(0xFFFFB000),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatCoins(coins),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Profile avatar
              GestureDetector(
                onTap: () => onNavTap?.call(3), // Index 3 is Profile
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: profilePhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF1EDFF),
                              child: const Icon(Icons.person,
                                  color: AppColors.primary, size: 20),
                            ),
                            errorWidget: (_, __, ___) => Image.asset(
                              AppAssets.profileAvatar,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, color: AppColors.primary),
                            ),
                          )
                        : Image.asset(
                            AppAssets.profileAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, color: AppColors.primary),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
