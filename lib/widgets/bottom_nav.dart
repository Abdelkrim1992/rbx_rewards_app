import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class RbxBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const RbxBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      const _NavItem(
        icon: AppAssets.navHome,
        label: 'Home',
        fallbackIcon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      const _NavItem(
        icon: AppAssets.navGames,
        label: 'Games',
        fallbackIcon: Icons.sports_esports_outlined,
        activeIcon: Icons.sports_esports_rounded,
      ),
      const _NavItem(
        icon: AppAssets.navRewards,
        label: 'Rewards',
        fallbackIcon: Icons.card_giftcard_outlined,
        activeIcon: Icons.card_giftcard_rounded,
      ),
      const _NavItem(
        icon: AppAssets.navProfile,
        label: 'Profile',
        fallbackIcon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.navBorder,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(i),
                    splashColor: AppColors.primarySoft.withValues(alpha: 0.4),
                    highlightColor: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // WhatsApp-style active capsule indicator pill
                        Container(
                          width: 58,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: _buildIcon(item, isActive),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppColors.darkText
                                : AppColors.mutedText,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(_NavItem item, bool isActive) {
    final color = isActive ? AppColors.purple : AppColors.mutedText;

    // if (item.icon.endsWith('.svg')) {
    //   return SvgPicture.asset(
    //     item.icon,
    //     width: 22,
    //     height: 22,
    //     colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    //   );
    // }

    return Icon(
      isActive ? item.activeIcon : item.fallbackIcon,
      size: 22,
      color: color,
    );
  }
}

class _NavItem {
  final String icon;
  final String label;
  final IconData fallbackIcon;
  final IconData activeIcon;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.fallbackIcon,
    required this.activeIcon,
  });
}
