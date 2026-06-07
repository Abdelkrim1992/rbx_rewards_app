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
        left: AppLayout.screenPadding,
        right: AppLayout.screenPadding,
        top: 10,
        bottom: 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // RBX Logo cube
              Image.asset(
                AppAssets.rbxLogo,
                width: 120,
                height: 50,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.gamepad, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          GestureDetector(
            onTap: () {
              // Use the navigation callback to switch to profile tab (index 4)
              if (onNavTap != null) {
                onNavTap!(4);
              }
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.purple, width: 1.5),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  )
                ],
              ),
              child: ClipOval(
                child: profilePhotoUrl != null
                  ? Image.network(
                      profilePhotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
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
