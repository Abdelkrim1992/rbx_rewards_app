import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/user_provider.dart';
import '../theme/app_theme.dart';

class RbxAppHeader extends ConsumerWidget {
  final ValueChanged<int>? onNavTap;

  const RbxAppHeader({super.key, this.onNavTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
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
            width: 128,
            height: 50,
            fit: BoxFit.contain,
          ),
          // Profile avatar
          GestureDetector(
            onTap: () => onNavTap?.call(3), // Index 3 is Profile
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.2),
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
                              color: AppColors.purple, size: 20),
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          AppAssets.profileAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: AppColors.purple),
                        ),
                      )
                    : Image.asset(
                        AppAssets.profileAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person, color: AppColors.purple),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
