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
        left: 14,
        right: AppLayout.screenPadding,
        top: 10,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                AppAssets.rbxLogo,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RBX REWARDS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PLAY & EARN ROBUX',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                      color: Color(0xFF7C8BA0),
                    ),
                  ),
                ],
              ),
            ],
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
                  color: AppColors.purple.withOpacity(0.2),
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
