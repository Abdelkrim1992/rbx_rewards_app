import 'package:flutter/material.dart';
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
      const _NavItem(icon: AppAssets.navHome, label: 'Home'),
      const _NavItem(icon: AppAssets.navGames, label: 'Games'),
      const _NavItem(icon: AppAssets.navOffers, label: 'Offers'),
      const _NavItem(icon: AppAssets.navRewards, label: 'Rewards'),
      const _NavItem(icon: AppAssets.navProfile, label: 'Profile'),
    ];

    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 22.5,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isActive = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
                decoration: isActive
                    ? BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      items[i].icon,
                      width: 22,
                      height: 22,
                      color: isActive ? AppColors.purple : AppColors.mutedText,
                      errorBuilder: (_, __, ___) => Icon(
                        _fallbackIcon(i),
                        size: 22,
                        color:
                            isActive ? AppColors.purple : AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isActive ? AppColors.purple : AppColors.mutedText,
                        letterSpacing: 0.275,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  IconData _fallbackIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.sports_esports_outlined;
      case 2:
        return Icons.local_offer_outlined;
      case 3:
        return Icons.card_giftcard_outlined;
      case 4:
        return Icons.person_outline;
      default:
        return Icons.circle;
    }
  }
}

class _NavItem {
  final String icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
